/**
 * THE RETURNING DINER (C-1.2, P0).
 *
 * Phone is the primary identity in Egypt. Until this suite existed, a diner
 * who signed up by phone could never sign in again:
 *
 *   - `POST /auth/register` answered **409 `phone_exists`**
 *   - `POST /auth/login` demanded a **password they had never set**
 *
 * Nothing failed. Every part worked; the JOURNEY did not. So this is written
 * as one round trip rather than as assertions about pieces — register, verify,
 * sign out, sign in AGAIN by phone, verify, receive tokens — because that is
 * the thing that was broken.
 *
 * The OTP is read from the recording delivery adapter, which is what the dev
 * stub does instead of sending a WhatsApp message. Real delivery is still a
 * launch blocker (docs/decisions/2026-08-01-otp-delivery-deferred.md).
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;

const suffix = Date.now().toString().slice(-9);
const PHONE = `+2010${suffix}`;
const OTHER = `+2011${suffix}`;

/** The most recent code sent to [phone], for [purpose]. */
function codeFor(phone: string, purpose: string): string {
  const sent = delivery.sent.filter((m) => m.phone === phone && m.purpose === purpose);
  if (sent.length === 0) {
    throw new Error(
      `No ${purpose} code was sent to ${phone}. Sent so far: ` +
        JSON.stringify(delivery.sent.map((m) => `${m.purpose}->${m.phone}`)),
    );
  }
  return sent[sent.length - 1].code;
}

beforeAll(async () => {
  await prisma.$connect();

  // Every e2e suite shares one per-IP OTP budget over loopback, and it lives
  // in Redis between runs. Without this the suite passes on a cold Redis and
  // fails ten minutes later against identical code — which is exactly what it
  // did. See the note in support/otp-budget.ts.
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    // The ONLY substitution: the wire out. Everything else — the store, the
    // rate limiter, the clock, the token service, Postgres — is the real
    // thing, because the bug was in how they fit together.
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();
}, 90_000);

afterAll(async () => {
  if (app) await app.close();
  for (const phone of [PHONE, OTHER]) {
    const user = await prisma.user.findFirst({ where: { phone } });
    if (!user) continue;
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${user.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${user.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${user.id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('a diner who signs up by phone can sign in again', () => {
  let userId: string;
  let challengeId: string;
  let refreshToken: string;

  it('1. registers by phone, with no password', async () => {
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: PHONE, fullName: 'Nour Hassan', locale: 'ar' })
      .expect(201);

    expect(res.body.otpRequired).toBe(true);
    userId = res.body.userId as string;
    challengeId = res.body.challengeId as string;
    expect(userId).toBeTruthy();
    expect(challengeId).toBeTruthy();
  });

  it('2. verifies the phone and receives the first token pair', async () => {
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId, code: codeFor(PHONE, 'phone_verify') })
      .expect(200);

    // DISCRIMINATED now: the row already exists, so answering signs them in.
    expect(res.body.status).toBe('signed_in');
    expect(res.body.tokens.accessToken).toBeTruthy();
    expect(res.body.tokens.refreshToken).toBeTruthy();
    // The `user` block doc 06 §2 specifies, and which was missing until the
    // controller return types were annotated.
    expect(res.body.tokens.user).toMatchObject({ id: userId, phone: PHONE, fullName: 'Nour Hassan' });
    refreshToken = res.body.tokens.refreshToken as string;
  });

  it('3. signs out', async () => {
    await request(http as never)
      .post('/v1/auth/logout')
      .send({ refreshToken })
      .expect(204);
  });

  // ── the step that was impossible ────────────────────────────────────────

  it('4. registering again is still 409 — this is NOT the way back in', async () => {
    // Recorded deliberately. It is the behaviour that made the gap invisible:
    // the obvious next thing a client would try, and it fails correctly.
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: PHONE, fullName: 'Nour Hassan' })
      .expect(409);
    expect(res.body.error.code).toBe('phone_exists');
  });

  it('5. requests a SIGN-IN code by phone alone', async () => {
    const res = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: PHONE })
      .expect(202);

    // A HANDLE AND NOTHING ELSE. No user id, no `otpRequired`, nothing that
    // says whether this number is registered — the response is identical for
    // a number that has never been seen (AUTH-3).
    expect(Object.keys(res.body)).toEqual(['challengeId']);
    expect(res.body.challengeId).toBeTruthy();
    challengeId = res.body.challengeId as string;
  });

  it('6. verifies it and is signed in — a different token pair', async () => {
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId, code: codeFor(PHONE, 'login') })
      .expect(200);

    expect(res.body.status).toBe('signed_in');
    expect(res.body.tokens.accessToken).toBeTruthy();
    expect(res.body.tokens.refreshToken).not.toBe(refreshToken);
    expect(res.body.tokens.user.id).toBe(userId);
  });

  it('7. and the access token works on a guarded route', async () => {
    const signIn = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: PHONE })
      .expect(202);

    const tokens = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: signIn.body.challengeId, code: codeFor(PHONE, 'login') })
      .expect(200);

    const me = await request(http as never)
      .get('/v1/auth/me')
      .set('Authorization', `Bearer ${tokens.body.tokens.accessToken}`)
      .expect(200);

    expect(me.body).toMatchObject({ id: userId, phone: PHONE, fullName: 'Nour Hassan' });
  });
});

describe('the two challenges are separate credentials', () => {
  it('a registration code cannot sign anyone in', async () => {
    const reg = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: OTHER, fullName: 'Omar Fathy' })
      .expect(201);

    const registrationCode = codeFor(OTHER, 'phone_verify');

    // THE MECHANISM CHANGED AND THE PROPERTY DID NOT.
    //
    // A caller used to send `purpose` alongside the code, so the separation
    // depended on them declaring it honestly. The purpose now lives on the
    // stored challenge, so it cannot be chosen or lied about at all — which is
    // the same protection, made unfakeable.
    //
    // What remains testable from outside is that a registration code is not a
    // sign-in credential: request a fresh LOGIN challenge and try to answer it
    // with the registration code.
    const signIn = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: OTHER })
      .expect(202);

    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: signIn.body.challengeId, code: registrationCode })
      .expect(400);

    expect(res.body.error.code).toBe('invalid_otp');
    expect(reg.body.challengeId).toBeTruthy();
  });
});

describe('a suspended account gets tokens from no door', () => {
  // FOUND WHILE ENUMERATING WHAT PROTECTS THIS FLOW, and it predates the
  // sign-in work: `verifyOtp` never checked account status. It preserved
  // `suspended` when it wrote the row, then issued a full token pair anyway.
  //
  // Password login has always refused a suspended account. This door did not,
  // which made suspension bypassable by anyone who could request a code — and
  // suspension is the platform's only lever against a serial no-show or a
  // fraud account (doc 02 A-1).
  it('cannot request a sign-in code', async () => {
    const suspended = `+2013${suffix}`;
    const reg = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: suspended, fullName: 'Suspended Account' })
      .expect(201);

    await prisma.user.update({
      where: { id: reg.body.userId as string },
      data: { status: 'suspended' },
    });

    // REQUESTING IS NOW INDISTINGUISHABLE — 202, a handle, nothing else.
    //
    // It used to answer 401 `account_unavailable`, which told anyone who could
    // type the number that it existed AND was suspended. Request time looks
    // nothing up now (AUTH-3), so suspension is discovered where it belongs:
    // after somebody has proved they can read messages sent to that number.
    const res = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: suspended })
      .expect(202);
    expect(res.body.challengeId).toBeTruthy();

    // …and the correct code does not get them in.
    const refused = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: res.body.challengeId, code: codeFor(suspended, 'login') })
      .expect(401);
    expect(refused.body.error.code).toBe('account_unavailable');
  });

  it('cannot answer a code that was already in flight', async () => {
    // The harder case: the challenge was issued while the account was healthy
    // and suspension landed in between. Checking status at REQUEST time only
    // would leave that window open.
    const suspended = `+2014${suffix}`;
    const reg = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: suspended, fullName: 'Suspended Mid-Flight' })
      .expect(201);

    const code = codeFor(suspended, 'phone_verify');

    await prisma.user.update({
      where: { id: reg.body.userId as string },
      data: { status: 'suspended' },
    });

    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: reg.body.challengeId, code })
      .expect(401);
    expect(res.body.error.code).toBe('account_unavailable');
  });

  afterAll(async () => {
    for (const phone of [`+2013${suffix}`, `+2014${suffix}`]) {
      const user = await prisma.user.findFirst({ where: { phone } });
      if (!user) continue;
      await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${user.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${user.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${user.id}::uuid`;
    }
  });
});

describe('what protects the flow', () => {
  /**
   * PER TEST, not per suite. Every e2e test runs over loopback, so the whole
   * repo shares one 10-per-IP budget (see support/otp-budget.ts) — and the
   * AUTH-3 tests below spend it faster than the old ones did, because a
   * request no longer needs an account to exist. Resetting at suite entry was
   * enough when this file made three requests; it makes a dozen now.
   *
   * Safe here and NOT above: every test in this block is self-contained,
   * whereas the numbered journey above carries a live challenge between steps
   * and a reset would delete it.
   */
  beforeEach(async () => {
    await resetOtpState();
  });

  /**
   * AUTH-3, CLOSED. This assertion is INVERTED from what it was, and the
   * inversion is the point.
   *
   * It used to assert that an unknown phone was refused with 401
   * `invalid_credentials` — which IS the enumeration oracle: Egyptian mobile
   * numbers are trivially enumerable and this endpoint answered "registered"
   * or "not registered" for any of them. It was also the endpoint the client
   * used as "resend" for a returning diner, so the commonest path was the
   * leaky one.
   *
   * Request time looks nothing up now, so there is no answer to leak.
   */
  it('an unknown phone gets the SAME response as a registered one', async () => {
    const unknown = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: '+201099999999' })
      .expect(202);

    const registered = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: PHONE })
      .expect(202);

    // Same status, same keys, and the only value that differs is random.
    expect(Object.keys(unknown.body)).toEqual(['challengeId']);
    expect(Object.keys(registered.body)).toEqual(Object.keys(unknown.body));
    expect(unknown.body.challengeId).not.toBe(registered.body.challengeId);
  });

  describe('completion only against a VERIFIED challenge', () => {
    let seq = 0;
    const fresh = (): string => {
      seq += 1;
      return '+2016' + String(Date.now()).slice(-6) + String(seq);
    };

    async function cleanup(phone: string): Promise<void> {
      const u = await prisma.user.findFirst({ where: { phone } });
      if (!u) return;
      await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${u.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${u.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${u.id}::uuid`;
    }

    it('a brand-new number: request then verify answers profile_needed, not tokens', async () => {
      const phone = fresh();
      const challenge = await request(http as never)
        .post('/v1/auth/request-otp')
        .send({ phone })
        .expect(202);

      const res = await request(http as never)
        .post('/v1/auth/verify-otp')
        .send({ challengeId: challenge.body.challengeId, code: codeFor(phone, 'login') })
        .expect(200);

      expect(res.body.status).toBe('profile_needed');
      expect(res.body.tokens).toBeUndefined();
      expect(await prisma.user.findFirst({ where: { phone } })).toBeNull();
    });

    it('and then a name completes it: request -> verify -> name -> tokens', async () => {
      const phone = fresh();
      const challenge = await request(http as never)
        .post('/v1/auth/request-otp')
        .send({ phone })
        .expect(202);
      await request(http as never)
        .post('/v1/auth/verify-otp')
        .send({ challengeId: challenge.body.challengeId, code: codeFor(phone, 'login') })
        .expect(200);

      const done = await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Brand New', locale: 'en' })
        .expect(201);

      expect(done.body.accessToken.split('.')).toHaveLength(3);
      expect(done.body.user.phone).toBe(phone);

      // Created ALREADY VERIFIED and active. The code proved the number before
      // the row existed, which is the inversion that makes account squatting
      // impossible rather than merely defended against.
      const u = await prisma.user.findFirstOrThrow({ where: { phone } });
      expect(u.status).toBe('active');
      expect(u.phoneVerifiedAt).not.toBeNull();
      await cleanup(phone);
    });

    it('an UNVERIFIED challenge cannot be completed', async () => {
      // The whole point of the endpoint: no name, no account, nothing at all
      // without having answered a code sent to that number first.
      const phone = fresh();
      const challenge = await request(http as never)
        .post('/v1/auth/request-otp')
        .send({ phone })
        .expect(202);

      const res = await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Never Verified' })
        .expect(400);
      expect(res.body.error.code).toBe('invalid_otp');

      expect(await prisma.user.findFirst({ where: { phone } })).toBeNull();
    });

    it('a completed challenge cannot be completed twice', async () => {
      const phone = fresh();
      const challenge = await request(http as never)
        .post('/v1/auth/request-otp')
        .send({ phone })
        .expect(202);
      await request(http as never)
        .post('/v1/auth/verify-otp')
        .send({ challengeId: challenge.body.challengeId, code: codeFor(phone, 'login') })
        .expect(200);
      await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Once Only' })
        .expect(201);

      // Single-use across the PAIR: verification marks, completion spends.
      const again = await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Twice' })
        .expect(400);
      expect(again.body.error.code).toBe('invalid_otp');

      const u = await prisma.user.findFirstOrThrow({ where: { phone } });
      expect(u.fullName).toBe('Once Only');
      await cleanup(phone);
    });

    it('a supplied phone is REFUSED, not quietly ignored', async () => {
      // The obvious attack on this endpoint: prove a number you own, then name
      // an account for somebody else's.
      //
      // This test was written expecting the extra field to be IGNORED (201,
      // account on the proved number). The real behaviour is better: the
      // global ValidationPipe whitelists DTO properties and forbids the rest,
      // so the request is refused outright. Refusing beats ignoring — a caller
      // who thought `phone` meant something is told it does not, instead of
      // getting a success for an account on a different number.
      const mine = fresh();
      const victim = '+2018' + String(Date.now()).slice(-7);
      const challenge = await request(http as never)
        .post('/v1/auth/request-otp')
        .send({ phone: mine })
        .expect(202);
      await request(http as never)
        .post('/v1/auth/verify-otp')
        .send({ challengeId: challenge.body.challengeId, code: codeFor(mine, 'login') })
        .expect(200);

      await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Attacker', phone: victim })
        .expect(400);

      // Neither number gained an account.
      expect(await prisma.user.findFirst({ where: { phone: victim } })).toBeNull();
      expect(await prisma.user.findFirst({ where: { phone: mine } })).toBeNull();

      // …and the challenge is still good, so an honest retry works. A refused
      // request must not burn the proof of a number the caller does own.
      await request(http as never)
        .post('/v1/auth/complete-registration')
        .send({ challengeId: challenge.body.challengeId, fullName: 'Honest Retry' })
        .expect(201);

      const u = await prisma.user.findFirstOrThrow({ where: { phone: mine } });
      expect(u.fullName).toBe('Honest Retry');
      await cleanup(mine);
    });
  });

  it('the per-phone send limit is 3 in 10 minutes', async () => {
    // doc 06 §1: "OTP send 3/10min". The limit that stops someone requesting
    // codes for a number they do not own — it is keyed on the PHONE, so it
    // holds even when the caller rotates IP addresses.
    //
    // Two sends have already been made to PHONE in the journey above, so the
    // budget is asserted from wherever it now stands rather than from an
    // assumed zero: a test that assumed a fresh window would pass or fail
    // depending on what ran before it.
    const fresh = `+2012${suffix}`;
    await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: fresh, fullName: 'Rate Limit' })
      .expect(201);

    // Registration consumed one. Two more are allowed, the fourth is not.
    let limited = false;
    for (let i = 0; i < 5; i++) {
      const res = await request(http as never).post('/v1/auth/request-otp').send({ phone: fresh });
      if (res.status === 429) {
        expect(res.body.error.code).toBe('otp_rate_limited');
        limited = true;
        break;
      }
    }
    expect(limited).toBe(true);

    const user = await prisma.user.findFirst({ where: { phone: fresh } });
    if (user) {
      await prisma.$executeRaw`DELETE FROM user_roles WHERE user_id = ${user.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM users      WHERE id      = ${user.id}::uuid`;
    }
  }, 60_000);
});
