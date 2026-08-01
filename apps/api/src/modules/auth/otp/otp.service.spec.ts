/**
 * OTP issue/verify + abuse limits (doc 09 §1.1, doc 06 §1, doc 02 C-1.2).
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — nothing under otp/ exists yet.
 *
 * doc 09 §1.1: "phone OTP hashed in Redis, 5-min TTL, 5 attempts, per-phone
 * and per-IP rate limits (blocks SMS-pumping fraud — a real cost attack in
 * Egypt)". The rate limits are therefore part of the feature, not hardening
 * to add later: every send costs money, and an unmetered send endpoint is a
 * way to bill SAHRA for someone else's traffic.
 *
 * Unit-level on purpose: the store, the limiter and delivery are all ports, so
 * the logic is testable without Redis or a carrier — which is also what lets
 * this land before Docker is up.
 */
import { OtpService, OTP_TTL_SECONDS, MAX_ATTEMPTS } from './otp.service';
import { InMemoryOtpStore } from './stores/in-memory-otp.store';
import { InMemoryRateLimiter } from './stores/in-memory-rate-limiter';
import { RecordingOtpDelivery } from './delivery/recording-otp.delivery';

const PHONE = '+201000000000';
const IP = '197.44.10.7';

function build(now: () => number = () => Date.now()) {
  const store = new InMemoryOtpStore(now);
  const limiter = new InMemoryRateLimiter(now);
  const delivery = new RecordingOtpDelivery();
  const service = new OtpService(store, limiter, delivery, now);
  return { service, store, limiter, delivery };
}

describe('OtpService — issuing', () => {
  it('sends a 6-digit numeric code through the delivery port', async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });

    expect(delivery.sent).toHaveLength(1);
    expect(delivery.sent[0].phone).toBe(PHONE);
    expect(delivery.sent[0].code).toMatch(/^\d{6}$/);
  });

  it('NEVER stores the code in plaintext', async () => {
    const { service, store, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });

    const code = delivery.sent[0].code;
    const raw = store.dump();
    // The code must not be recoverable from anything the store holds — a Redis
    // dump should not be a list of working OTPs.
    expect(JSON.stringify(raw)).not.toContain(code);
  });

  it('issuing again replaces the previous code, so only the newest works', async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });

    const [first, second] = delivery.sent;
    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code: first.code }),
    ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });

    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code: second.code }),
    ).resolves.toBe(true);
  });
});

describe('OtpService — verifying', () => {
  it('accepts the right code once, then refuses to reuse it', async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    await expect(service.verify({ userId: 'u1', purpose: 'phone_verify', code })).resolves.toBe(true);
    // Replay must fail — a consumed OTP is spent.
    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code }),
    ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
  });

  it(`locks the challenge after ${MAX_ATTEMPTS} wrong codes`, async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await expect(
        service.verify({ userId: 'u1', purpose: 'phone_verify', code: '000000' }),
      ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
    }

    // Six digits is a million combinations; without this cap an attacker just
    // walks the space. The CORRECT code must now fail too.
    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it(`expires after ${OTP_TTL_SECONDS}s`, async () => {
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    clock += (OTP_TTL_SECONDS + 1) * 1000;
    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code }),
    ).rejects.toMatchObject({ response: { code: 'otp_expired' } });
  });

  it('keeps purposes separate — a login code cannot verify a phone', async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    const { code } = delivery.sent[0];

    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code }),
    ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
  });
});

describe('OtpService — abuse limits (doc 09 §1.1)', () => {
  it('caps sends PER PHONE at 3 per 10 minutes (doc 06 §1)', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);

    for (let i = 0; i < 3; i++) {
      await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: `10.0.0.${i}` });
    }

    // Fourth send inside the window is refused even from a fresh IP — the
    // victim's phone is what is being billed and harassed.
    await expect(
      service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.99' }),
    ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });

    // The window rolls.
    clock += 10 * 60 * 1000 + 1;
    await expect(
      service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.99' }),
    ).resolves.toBeUndefined();
  });

  it('caps sends PER IP across different phones — the SMS-pumping shape', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);

    // One source spraying many numbers is the actual fraud: each send costs
    // SAHRA money and the attacker takes a cut from the carrier.
    let blocked = false;
    for (let i = 0; i < 20; i++) {
      try {
        await service.issue({
          userId: `u${i}`, phone: `+2010000000${String(i).padStart(2, '0')}`,
          purpose: 'phone_verify', ip: IP,
        });
      } catch (e) {
        expect((e as { response: { code: string } }).response.code).toBe('otp_rate_limited');
        blocked = true;
        break;
      }
    }
    expect(blocked).toBe(true);
  });

  it('one phone being limited does not block a different phone', async () => {
    const { service } = build();
    for (let i = 0; i < 3; i++) {
      await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.1' });
    }
    await expect(
      service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.1' }),
    ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });

    // A different victim, different source — unaffected.
    await expect(
      service.issue({ userId: 'u2', phone: '+201555555555', purpose: 'phone_verify', ip: '10.0.0.2' }),
    ).resolves.toBeUndefined();
  });
});

describe('delivery is a port, not a hard-wired carrier', () => {
  it('the OTP logic never touches a provider directly', async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });

    // Swapping the adapter is the whole integration surface: when the company
    // is registered, a WhatsApp adapter replaces this one and nothing in
    // OtpService changes.
    expect(delivery.sent[0]).toMatchObject({ phone: PHONE, purpose: 'phone_verify' });
    expect(typeof delivery.sent[0].code).toBe('string');
  });
});
