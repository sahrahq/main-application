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
  let refreshToken: string;

  it('1. registers by phone, with no password', async () => {
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: PHONE, fullName: 'Nour Hassan', locale: 'ar' })
      .expect(201);

    expect(res.body.otpRequired).toBe(true);
    userId = res.body.userId as string;
    expect(userId).toBeTruthy();
  });

  it('2. verifies the phone and receives the first token pair', async () => {
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ userId, code: codeFor(PHONE, 'phone_verify') })
      .expect(200);

    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    // The `user` block doc 06 §2 specifies, and which was missing until the
    // controller return types were annotated.
    expect(res.body.user).toMatchObject({ id: userId, phone: PHONE, fullName: 'Nour Hassan' });
    refreshToken = res.body.refreshToken as string;
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

    expect(res.body).toMatchObject({ userId, otpRequired: true });
  });

  it('6. verifies it and is signed in — a different token pair', async () => {
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ userId, code: codeFor(PHONE, 'login'), purpose: 'login' })
      .expect(200);

    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).not.toBe(refreshToken);
    expect(res.body.user.id).toBe(userId);
  });

  it('7. and the access token works on a guarded route', async () => {
    const signIn = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: PHONE })
      .expect(202);

    const tokens = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ userId: signIn.body.userId, code: codeFor(PHONE, 'login'), purpose: 'login' })
      .expect(200);

    const me = await request(http as never)
      .get('/v1/auth/me')
      .set('Authorization', `Bearer ${tokens.body.accessToken}`)
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

    // Same code, wrong purpose. Challenges are keyed `otp:{purpose}:{userId}`,
    // so there is no `login` challenge to answer at all — and if there were,
    // this code would not be it. Without that separation a code sent for one
    // purpose is a credential for every purpose.
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ userId: reg.body.userId, code: registrationCode, purpose: 'login' })
      .expect(400);

    expect(res.body.error.code).toBe('invalid_otp');
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

    const res = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: suspended })
      .expect(401);
    expect(res.body.error.code).toBe('account_unavailable');
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
      .send({ userId: reg.body.userId, code })
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
  it('an unknown phone cannot request a code', async () => {
    const res = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: '+201099999999' })
      .expect(401);
    expect(res.body.error.code).toBe('invalid_credentials');
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
