/**
 * OTP issue/verify + abuse limits (doc 09 §1.1, doc 06 §1, doc 02 C-1.2).
 *
 * doc 09 §1.1: "phone OTP hashed in Redis, 5-min TTL, 5 attempts, per-phone
 * and per-IP rate limits (blocks SMS-pumping fraud — a real cost attack in
 * Egypt)". The rate limits are part of the feature, not hardening to add
 * later: every send costs money, and an unmetered send endpoint is a way to
 * bill SAHRA for someone else's traffic.
 *
 * REWRITTEN FOR CHALLENGE IDS (step 2a, AUTH-3). `issue` no longer takes a
 * user id and no longer looks anything up; it returns an opaque handle, and
 * `verify` answers that handle. Every property the previous version pinned is
 * still pinned here — two of them only because this file said so, and the
 * refactor would otherwise have dropped them silently. Those two are marked.
 *
 * Unit-level on purpose: the store, the limiter and delivery are all ports, so
 * the logic is testable without Redis or a carrier.
 */
import {
  OtpService, OTP_TTL_SECONDS, MAX_ATTEMPTS, LOCK_SECONDS, VERIFIED_TTL_SECONDS,
  GLOBAL_SEND_KEY, GLOBAL_SEND_WINDOW_SECONDS, globalSendLimitFrom,
} from './otp.service';
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
    await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });

    expect(delivery.sent).toHaveLength(1);
    expect(delivery.sent[0].phone).toBe(PHONE);
    expect(delivery.sent[0].code).toMatch(/^\d{6}$/);
  });

  it('NEVER stores the code in plaintext', async () => {
    const { service, store, delivery } = build();
    await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });

    const code = delivery.sent[0].code;
    // The code must not be recoverable from anything the store holds — a Redis
    // dump should not be a list of working OTPs.
    expect(JSON.stringify(store.dump())).not.toContain(code);
  });

  it('returns an OPAQUE handle that leaks nothing about the phone', async () => {
    const { service } = build();
    const challengeId = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });

    expect(typeof challengeId).toBe('string');
    // 32 random bytes, base64url. Long enough not to be guessable, and NOT
    // derived from the phone, the purpose or the clock — an id with structure
    // is an id somebody can reverse.
    expect(challengeId.length).toBeGreaterThanOrEqual(40);
    expect(challengeId).not.toContain('20100');
    expect(challengeId).not.toContain('login');
  });

  it('issues for a phone with NO ACCOUNT exactly as for one with an account', async () => {
    // The whole of AUTH-3's closure: `issue` performs no lookup, so there is
    // no branch to distinguish and nothing to equalise. Two unrelated numbers
    // produce the same shape of result and the same number of deliveries.
    const { service, delivery } = build();
    const a = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const b = await service.issue({ phone: '+201999999999', purpose: 'login', ip: IP });

    expect(typeof a).toBe('string');
    expect(typeof b).toBe('string');
    expect(a).not.toBe(b);
    expect(delivery.sent).toHaveLength(2);
  });
});

// ────────────────────────────── one live code per number, per purpose ──
//
// PINNED BY THIS FILE AND BY NOTHING ELSE.
//
// The previous design keyed a challenge by (user, purpose), so a second send
// overwrote the first and only the newest code worked. Challenge ids are
// per-send, so that property does NOT come for free — without the live-pointer
// in `issue`, asking for a new code would leave the old one working until its
// own expiry, and requesting a fresh code would WIDEN the window instead of
// replacing it. That is the class of weakening that ships quietly.
describe('OtpService — only the newest code works', () => {
  it('issuing again REPLACES the previous code', async () => {
    const { service, delivery } = build();
    await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });
    const second = await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });

    const [firstSent, secondSent] = delivery.sent;
    expect(firstSent.code).not.toBe(secondSent.code);

    // The newest one works.
    await expect(
      service.verify({ challengeId: second, code: secondSent.code }),
    ).resolves.toMatchObject({ phone: PHONE, purpose: 'phone_verify' });
  });

  it('the FIRST code is dead immediately, and refused IDENTICALLY to a wrong code', async () => {
    // "Dead immediately" rather than "unreachable": the old challenge is
    // consumed when the new one is issued, not merely orphaned by a client
    // that has forgotten its id.
    //
    // And the refusal must be indistinguishable from any other bad answer. A
    // distinct "superseded" response would tell a caller that a particular
    // challenge id was once real — and, worse, invite a client to treat it as
    // a recoverable state and retry.
    const { service, delivery } = build();
    const first = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const firstCode = delivery.sent[0].code;

    const supersededError = await service
      .verify({ challengeId: first, code: firstCode })
      .then(() => null)
      .catch((e) => e as { response: unknown; status?: number });

    const wrongCodeError = await service
      .verify({ challengeId: first, code: '000000' })
      .then(() => null)
      .catch((e) => e as { response: unknown; status?: number });

    expect(supersededError).not.toBeNull();
    expect(wrongCodeError).not.toBeNull();

    // Byte-identical bodies, not merely the same error code.
    expect(supersededError!.response).toEqual(wrongCodeError!.response);
    expect(supersededError!.response).toMatchObject({ code: 'invalid_otp' });
  });
});

describe('OtpService — verifying', () => {
  it('accepts the right code once, then refuses to reuse it', async () => {
    const { service, delivery } = build();
    const id = await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    await expect(service.verify({ challengeId: id, code })).resolves.toMatchObject({
      phone: PHONE,
    });

    // Answering twice is a replay, and looks exactly like an unknown id.
    await expect(
      service.verify({ challengeId: id, code }),
    ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
  });

  it('verifying MARKS but does not spend — the pair is what is single-use', async () => {
    // A diner with no account yet has to supply a name against a number they
    // have already proved. So verification keeps the challenge alive for the
    // completion window, and `consumeVerified` is what finally spends it.
    const { service, delivery } = build();
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const { code } = delivery.sent[0];

    await service.verify({ challengeId: id, code });

    await expect(service.consumeVerified(id)).resolves.toMatchObject({ phone: PHONE });
    // …and only once.
    await expect(service.consumeVerified(id)).rejects.toMatchObject({
      response: { code: 'invalid_otp' },
    });
  });

  it('an UNVERIFIED challenge cannot be completed', async () => {
    const { service } = build();
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });

    await expect(service.consumeVerified(id)).rejects.toMatchObject({
      response: { code: 'invalid_otp' },
    });
  });

  it(`the verified window expires after ${VERIFIED_TTL_SECONDS}s`, async () => {
    // An abandoned verified challenge must expire rather than linger as a
    // standing half-credential.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    await service.verify({ challengeId: id, code: delivery.sent[0].code });

    clock += VERIFIED_TTL_SECONDS * 1000 + 1;

    await expect(service.consumeVerified(id)).rejects.toMatchObject({
      response: { code: 'invalid_otp' },
    });
  });

  it('an unknown challenge id answers like a wrong code', async () => {
    const { service } = build();
    await expect(
      service.verify({ challengeId: 'not-a-real-handle', code: '123456' }),
    ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
  });

  it(`locks after ${MAX_ATTEMPTS} wrong codes, and SAYS SO on the fifth`, async () => {
    const { service, delivery } = build();
    const id = await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    for (let i = 0; i < MAX_ATTEMPTS - 1; i++) {
      await expect(
        service.verify({ challengeId: id, code: '000000' }),
      ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
    }

    // THE FIFTH IS DIFFERENT, deliberately. It used to answer `invalid_otp`
    // while arming the lock, and only admitted to the lock on a sixth attempt.
    // A diner reading "wrong code" requests a new one, which cannot help, and
    // burns their three sends against a shut door before calling support.
    await expect(
      service.verify({ challengeId: id, code: '000000' }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });

    // Six digits is a million combinations; without this cap an attacker walks
    // the space. The CORRECT code must fail too.
    await expect(
      service.verify({ challengeId: id, code }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it(`expires after ${OTP_TTL_SECONDS}s`, async () => {
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    const id = await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });
    const { code } = delivery.sent[0];

    clock += (OTP_TTL_SECONDS + 1) * 1000;
    await expect(
      service.verify({ challengeId: id, code }),
    ).rejects.toMatchObject({ response: { code: 'otp_expired' } });
  });

  it('the PURPOSE comes from the challenge, not from the caller', async () => {
    // Replaces "a login code cannot verify a phone". That separation used to
    // be enforced by the caller passing a purpose, which meant the caller
    // could get it wrong or lie. The purpose now lives on the stored challenge
    // and is read back from it — the same property, made unfakeable.
    const { service, delivery } = build();
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });

    await expect(
      service.verify({ challengeId: id, code: delivery.sent[0].code }),
    ).resolves.toMatchObject({ purpose: 'login' });
  });
});

describe('OtpService — abuse limits (doc 09 §1.1)', () => {
  it('caps sends PER PHONE at 3 per 10 minutes (doc 06 §1)', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);

    for (let i = 0; i < 3; i++) {
      await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: `10.0.0.${i}` });
    }

    // Fourth send inside the window is refused even from a fresh IP — the
    // victim's phone is what is being billed and harassed.
    await expect(
      service.issue({ phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.99' }),
    ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });

    // The window rolls.
    clock += 10 * 60 * 1000 + 1;
    await expect(
      service.issue({ phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.99' }),
    ).resolves.toEqual(expect.any(String));
  });

  it('an over-limit request costs ZERO deliveries', async () => {
    // The limiter is now the only thing between us and paying for SMS to
    // arbitrary numbers, because `issue` no longer requires an account to
    // exist. So it has to fire BEFORE the carrier is touched, not after.
    const { service, delivery } = build();

    for (let i = 0; i < 3; i++) {
      await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    }
    expect(delivery.sent).toHaveLength(3);

    await expect(
      service.issue({ phone: PHONE, purpose: 'login', ip: IP }),
    ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });

    expect(delivery.sent).toHaveLength(3);
  });

  it('caps sends PER IP across different phones — the SMS-pumping shape', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);

    let blocked = false;
    for (let i = 0; i < 20; i++) {
      try {
        await service.issue({
          phone: `+2010000000${String(i).padStart(2, '0')}`,
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
      await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.1' });
    }
    await expect(
      service.issue({ phone: PHONE, purpose: 'phone_verify', ip: '10.0.0.1' }),
    ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });

    // A different victim, different source — unaffected.
    await expect(
      service.issue({ phone: '+201555555555', purpose: 'phone_verify', ip: '10.0.0.2' }),
    ).resolves.toEqual(expect.any(String));
  });
});

// ─────────────────────────────────────────────────────── the wallet fuse ──

describe('the global daily send ceiling', () => {
  /**
   * Build with the ceiling forced, since it is read from the environment at
   * construction.
   *
   * `delete` on restore, not assignment. `process.env.X = undefined` stores the
   * STRING "undefined", which is not unset — it made the ceiling parser reject
   * `"undefined"` as a non-integer and failed six unrelated tests in this file.
   */
  function buildCapped(limit: number) {
    const previous = process.env.OTP_GLOBAL_DAILY_SEND_LIMIT;
    process.env.OTP_GLOBAL_DAILY_SEND_LIMIT = String(limit);
    const built = build();
    if (previous === undefined) delete process.env.OTP_GLOBAL_DAILY_SEND_LIMIT;
    else process.env.OTP_GLOBAL_DAILY_SEND_LIMIT = previous;
    return built;
  }

  it('costs ZERO deliveries past the ceiling', async () => {
    // The per-phone and per-IP limits cap harassment and spraying; neither
    // caps the BILL. This does, and it is the only thing that does.
    const { service, delivery } = buildCapped(2);

    // Different phones and different IPs, so only the global counter can stop
    // this — otherwise the test would pass on the wrong limiter.
    await service.issue({ phone: '+201000000001', purpose: 'login', ip: '10.1.0.1' });
    await service.issue({ phone: '+201000000002', purpose: 'login', ip: '10.1.0.2' });
    expect(delivery.sent).toHaveLength(2);

    await expect(
      service.issue({ phone: '+201000000003', purpose: 'login', ip: '10.1.0.3' }),
    ).rejects.toMatchObject({ response: { code: 'otp_sending_unavailable' } });

    expect(delivery.sent).toHaveLength(2);
  });

  it('FAILS CLOSED — it does not serve an undelivered challenge', async () => {
    // The alternative was to hand back a challenge and quietly not send. That
    // is the decoy pattern wearing a different hat: the diner is told a code
    // was sent, waits, retries, and contacts support about a phone they think
    // is broken, while only the logs know why.
    const { service } = buildCapped(0);

    await expect(
      service.issue({ phone: PHONE, purpose: 'login', ip: IP }),
    ).rejects.toMatchObject({ response: { code: 'otp_sending_unavailable' } });
  });

  it('is a 24-hour window, counted on one global key', () => {
    expect(GLOBAL_SEND_WINDOW_SECONDS).toBe(24 * 60 * 60);
    expect(GLOBAL_SEND_KEY).toBe('otp:send:global');
  });

  describe('the ceiling is required in production', () => {
    it('throws at construction when unset in production', () => {
      // A fuse with no rating is not a fuse. Failing at BOOT rather than at
      // the first sign-in is the same discipline TRUST_PROXY_HOPS uses.
      expect(() => globalSendLimitFrom({ NODE_ENV: 'production' })).toThrow(
        /OTP_GLOBAL_DAILY_SEND_LIMIT is required in production/,
      );
    });

    it('defaults generously in development, and says so', () => {
      const warnings: string[] = [];
      const limit = globalSendLimitFrom(
        { NODE_ENV: 'development' },
        { warn: (m) => warnings.push(m) },
      );
      // Sized ABOVE expected peak, not as a capacity plan: because it fails
      // closed, a tripped ceiling is a full signup outage.
      expect(limit).toBeGreaterThanOrEqual(10_000);
      expect(warnings.join(' ')).toMatch(/must be set explicitly in production/);
    });

    it('rejects a value that is not a non-negative integer', () => {
      for (const raw of ['-1', 'lots', '1.5']) {
        expect(() =>
          globalSendLimitFrom({ NODE_ENV: 'development', OTP_GLOBAL_DAILY_SEND_LIMIT: raw }),
        ).toThrow(/non-negative integer/);
      }
    });
  });
});

describe('delivery is a port, not a hard-wired carrier', () => {
  it('the OTP logic never touches a provider directly', async () => {
    const { service, delivery } = build();
    await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });

    expect(delivery.sent[0]).toMatchObject({ phone: PHONE, purpose: 'phone_verify' });
    expect(typeof delivery.sent[0].code).toBe('string');
  });
});

// ─────────────────────────────────────────── doc 11 flow 1: the 15-min lock ──

describe('OtpService — the verify lock', () => {
  /** Wrong five times against one challenge, which is what arms the lock. */
  async function exhaust(service: OtpService, challengeId: string): Promise<void> {
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await service.verify({ challengeId, code: '000000' }).catch(() => undefined);
    }
  }

  it('the constant matches the copy — 15 minutes, stated in words to the diner', () => {
    // `errTooManyAttempts` says "wait 15 minutes" in both locales. If this
    // number moves, the copy has to move with it, and nothing else would
    // notice.
    expect(LOCK_SECONDS).toBe(15 * 60);
  });

  it('locks after five wrong codes, with the wait in retry_after', async () => {
    let clock = 1_000_000;
    const { service } = build(() => clock);
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });

    await exhaust(service, id);

    await expect(
      service.verify({ challengeId: id, code: '000000' }),
    ).rejects.toMatchObject({
      response: { code: 'too_many_attempts', retry_after: LOCK_SECONDS },
    });
  });

  it('A NEW SEND DOES NOT RESET OR BYPASS THE LOCK', async () => {
    // The whole reason the lock exists. Before it, five wrong guesses locked
    // the CHALLENGE, and a fresh code bought five more — a real budget of 15
    // guesses per 10 minutes, indefinitely.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    const first = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service, first);

    // A new code IS issued — the send path is not blocked, only verification.
    const second = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const freshCode = delivery.sent[delivery.sent.length - 1].code;
    expect(delivery.sent).toHaveLength(2);

    // …and the CORRECT code on the NEW challenge still does not get in. The
    // lock is scoped to the number, so it survives the challenge that armed it.
    await expect(
      service.verify({ challengeId: second, code: freshCode }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it('THE LOCK EXPIRES — it must not brick an account someone else attacked', async () => {
    // A legitimate diner whose number was guessed at by a stranger has to be
    // able to get in again. A permanent lock turns an attack on them into a
    // denial of service by us.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    const first = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service, first);

    clock += LOCK_SECONDS * 1000 + 1;

    const second = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const code = delivery.sent[delivery.sent.length - 1].code;

    await expect(
      service.verify({ challengeId: second, code }),
    ).resolves.toMatchObject({ phone: PHONE });
  });

  it('one second before expiry it is still locked', async () => {
    // The boundary, because "expires eventually" and "expires at 15 minutes"
    // are different claims and only one of them is the doc's.
    let clock = 1_000_000;
    const { service } = build(() => clock);
    const id = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    await exhaust(service, id);

    clock += LOCK_SECONDS * 1000 - 1000;

    await expect(
      service.verify({ challengeId: id, code: '000000' }),
    ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
  });

  it('locks one purpose without locking the other', async () => {
    // PINNED BY THIS FILE AND BY NOTHING ELSE. The old lock was keyed by
    // (user, purpose); dropping to a phone-only key would have made failing a
    // sign-in five times block a registration the same person holds a valid
    // code for. The purpose is in the key for exactly this.
    let clock = 1_000_000;
    const { service, delivery } = build(() => clock);
    const loginId = await service.issue({ phone: PHONE, purpose: 'login', ip: IP });
    const verifyId = await service.issue({ phone: PHONE, purpose: 'phone_verify', ip: IP });
    const verifyCode = delivery.sent[1].code;

    await exhaust(service, loginId);

    await expect(
      service.verify({ challengeId: verifyId, code: verifyCode }),
    ).resolves.toMatchObject({ purpose: 'phone_verify' });
  });
});
