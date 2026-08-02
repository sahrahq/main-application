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
import { OtpService, OTP_TTL_SECONDS, MAX_ATTEMPTS, LOCK_SECONDS } from './otp.service';
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

  it(`locks after ${MAX_ATTEMPTS} wrong codes, and SAYS SO on the fifth`, async () => {
    const { service, delivery } = build();
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    // The first four are just wrong.
    for (let i = 0; i < MAX_ATTEMPTS - 1; i++) {
      await expect(
        service.verify({ userId: 'u1', purpose: 'phone_verify', code: '000000' }),
      ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
    }

    // THE FIFTH IS DIFFERENT, and this assertion changed deliberately.
    //
    // It used to answer `invalid_otp` — "wrong code" — while actually
    // arming the lock, and only admitted to the lock on a SIXTH attempt. A
    // diner reading "wrong code" does the sensible thing and requests a new
    // one, which cannot help them, and burns their three sends against a shut
    // door before calling support. Telling them at the moment it happens is
    // the whole difference between a wait and a support ticket.
    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code: '000000' }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });

    // Six digits is a million combinations; without this cap an attacker just
    // walks the space. The CORRECT code must fail too.
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

// ─────────────────────────────────────────── doc 11 flow 1: the 15-min lock ──

describe('OtpService — the verify lock', () => {
  /** Wrong five times, which is what arms the lock. */
  async function exhaust(service: OtpService): Promise<void> {
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await service.verify({ userId: 'u1', purpose: 'login', code: '000000' }).catch(() => undefined);
    }
  }

  it('the constant matches the copy — 15 minutes, stated in words to the diner', () => {
    // `errTooManyAttempts` says "wait 15 minutes" in both locales. A diner
    // told only "too many attempts" keeps requesting codes that cannot help
    // them, burns their three sends, and calls support. If this number moves,
    // the copy has to move with it, and nothing else would notice.
    expect(LOCK_SECONDS).toBe(15 * 60);
  });

  it('locks after five wrong codes, with the wait in retry_after', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });

    await exhaust(service);

    await expect(
      service.verify({ userId: 'u1', purpose: 'login', code: '000000' }),
    ).rejects.toMatchObject({
      response: { code: 'too_many_attempts', retry_after: LOCK_SECONDS },
    });
  });

  // ── the proof that matters ─────────────────────────────────────────────

  it('A NEW SEND DOES NOT RESET OR BYPASS THE LOCK', async () => {
    // This is the whole reason the lock exists. Before it, five wrong guesses
    // locked the CHALLENGE, and a fresh code bought five more — so the real
    // budget was 15 guesses per 10 minutes, indefinitely.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service);

    // A new code IS issued — the send path is not blocked, only verification.
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    const freshCode = delivery.sent[delivery.sent.length - 1].code;
    expect(delivery.sent).toHaveLength(2);

    // …and the CORRECT code still does not get in.
    await expect(
      service.verify({ userId: 'u1', purpose: 'login', code: freshCode }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it('THE LOCK EXPIRES — it must not brick an account someone else attacked', async () => {
    // A legitimate diner whose number was guessed at by a stranger has to be
    // able to get in again. A permanent lock turns an attack on them into a
    // denial of service by us.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service);

    clock += LOCK_SECONDS * 1000 + 1;

    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    const code = delivery.sent[delivery.sent.length - 1].code;

    await expect(
      service.verify({ userId: 'u1', purpose: 'login', code }),
    ).resolves.toBe(true);
  });

  it('one second before expiry it is still locked', async () => {
    // The boundary, because "expires eventually" and "expires at 15 minutes"
    // are different claims and only one of them is the doc's.
    let clock = 1_000_000;
    const { service } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service);

    clock += LOCK_SECONDS * 1000 - 1000;

    await expect(
      service.verify({ userId: 'u1', purpose: 'login', code: '000000' }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it('locks one purpose without locking the other', async () => {
    // Failing a sign-in five times must not stop the same person completing
    // a registration they have a valid code for. The lock is keyed by
    // (user, purpose), like the challenge.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'login', ip: IP });
    await service.issue({ userId: 'u1', phone: PHONE, purpose: 'phone_verify', ip: IP });
    const verifyCode = delivery.sent[1].code;

    await exhaust(service);

    await expect(
      service.verify({ userId: 'u1', purpose: 'phone_verify', code: verifyCode }),
    ).resolves.toBe(true);
  });
});
