/**
 * ACCOUNT SQUATTING — and the takeover attempt the fix must not enable.
 *
 * The problem: anyone could type a stranger's phone number, never answer the
 * code, and leave a `pending` row. The real owner then tried to sign up and
 * was told **their own number was taken**. They do not contact support about
 * that; they leave. Which makes it worse than an attack we could observe —
 * it is a customer loss that appears in no metric we have.
 *
 * The fix replaces an unverified registration instead of refusing it. That
 * creates an obvious hazard, and most of this file is about the hazard rather
 * than the fix:
 *
 *   - it must NOT let anyone take over a VERIFIED account
 *   - it must NOT reveal whether a number is registered
 *
 * The second is subtle: an endpoint that answers 201 for an unknown number
 * and something else for a known one is an enumeration oracle, which is
 * exactly what was avoided at `/restaurants/:idOrSlug`.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import {
  PendingRegistrationSweeper,
  PENDING_TTL_HOURS,
} from '../src/modules/auth/pending-registration.sweeper';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;
let sweeper: PendingRegistrationSweeper;

const suffix = Date.now().toString().slice(-9);
const SQUATTED = `+2015${suffix}`;
const VERIFIED = `+2016${suffix}`;
const STALE = `+2017${suffix}`;

function lastCode(phone: string, purpose = 'phone_verify'): string {
  const sent = delivery.sent.filter((m) => m.phone === phone && m.purpose === purpose);
  if (sent.length === 0) throw new Error(`no ${purpose} code sent to ${phone}`);
  return sent[sent.length - 1].code;
}

beforeAll(async () => {
  await prisma.$connect();
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();
  sweeper = app.get(PendingRegistrationSweeper);
}, 90_000);

afterAll(async () => {
  if (app) await app.close();
  for (const phone of [SQUATTED, VERIFIED, STALE]) {
    const user = await prisma.user.findFirst({ where: { phone } });
    if (!user) continue;
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${user.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${user.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${user.id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('the real owner is not locked out by a squatter', () => {
  it('a squatter registers a number they do not own, and never verifies', async () => {
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: SQUATTED, fullName: 'Squatter', email: null })
      .expect(201);
    expect(res.body.otpRequired).toBe(true);
    // They never answer the code. That is the entire attack.
  });

  let reclaimChallengeId: string;

  it('the OWNER registers the same number and is NOT refused', async () => {
    // This used to be 409 phone_exists — a real diner told their own number
    // was taken.
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: SQUATTED, fullName: 'Nour Hassan', locale: 'ar' })
      .expect(201);

    expect(res.body.otpRequired).toBe(true);
    expect(res.body.userId).toBeTruthy();
    reclaimChallengeId = res.body.challengeId as string;
    expect(reclaimChallengeId).toBeTruthy();
  });

  it("and the squatter's details do not survive", async () => {
    // A squatter must not get to fix a stranger's name in our database.
    const user = await prisma.user.findFirst({ where: { phone: SQUATTED } });
    expect(user?.fullName).toBe('Nour Hassan');
    expect(user?.locale).toBe('ar');
  });

  it('the owner completes signup with the fresh code', async () => {
    // The handle from the RECLAIMING register call. A challenge is answered by
    // its own handle now, not by looking a user up — which is also why the
    // reclaim path had to start returning one.
    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: reclaimChallengeId, code: lastCode(SQUATTED) })
      .expect(200);

    expect(res.body.status).toBe('signed_in');
    expect(res.body.tokens.user.fullName).toBe('Nour Hassan');
  });
});

describe('THE TAKEOVER ATTEMPT — a verified account is not reclaimable', () => {
  let ownerId: string;

  it('an owner registers and verifies properly', async () => {
    const reg = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: VERIFIED, fullName: 'Verified Owner' })
      .expect(201);
    ownerId = reg.body.userId as string;

    await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: reg.body.challengeId, code: lastCode(VERIFIED) })
      .expect(200);
  });

  it('an attacker re-registering that number is REFUSED', async () => {
    // The line is `phoneVerifiedAt`, and status is checked alongside it, so a
    // future bug in either question alone cannot open this door.
    const res = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: VERIFIED, fullName: 'Attacker', password: 'hunter2hunter2' })
      .expect(409);

    expect(res.body.error.code).toBe('phone_exists');
  });

  it("and nothing about the owner's account changed", async () => {
    const user = await prisma.user.findFirst({ where: { phone: VERIFIED } });
    expect(user?.id).toBe(ownerId);
    expect(user?.fullName).toBe('Verified Owner');
    // The attacker's password must not have been written anywhere.
    expect(user?.passwordHash).toBeNull();
    expect(user?.status).toBe('active');
  });

  it('an attacker cannot verify with a code they never received', async () => {
    // Belt and braces: even if the row HAD been reclaimed, the attacker still
    // has to answer a code sent to a phone they do not hold.
    // A challenge for the owner's number that the ATTACKER requested. They can
    // ask for one — request time looks nothing up (AUTH-3) — but the code goes
    // to the owner's handset, so they cannot answer it.
    const attackerChallenge = await request(http as never)
      .post('/v1/auth/request-otp')
      .send({ phone: VERIFIED })
      .expect(202);

    const res = await request(http as never)
      .post('/v1/auth/verify-otp')
      .send({ challengeId: attackerChallenge.body.challengeId, code: '000000' })
      .expect(400);
    expect(res.body.error.code).toBe('invalid_otp');
  });
});

describe('and it is not an enumeration oracle', () => {
  it('a first-time registration and a reclaim are indistinguishable', async () => {
    // If the two answered differently, this endpoint would tell an attacker
    // which phone numbers have unverified accounts — exactly the oracle
    // avoided at /restaurants/:idOrSlug.
    const fresh = `+2018${suffix}`;

    const first = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: fresh, fullName: 'First Time' });

    const reclaim = await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: fresh, fullName: 'Second Time' });

    expect(reclaim.status).toBe(first.status);
    expect(Object.keys(reclaim.body).sort()).toEqual(Object.keys(first.body).sort());
    expect(typeof reclaim.body.userId).toBe(typeof first.body.userId);
    expect(reclaim.body.otpRequired).toBe(first.body.otpRequired);

    const user = await prisma.user.findFirst({ where: { phone: fresh } });
    if (user) {
      await prisma.$executeRaw`DELETE FROM user_roles WHERE user_id = ${user.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM users      WHERE id      = ${user.id}::uuid`;
    }
  });
});

describe(`unverified registrations expire after ${PENDING_TTL_HOURS}h`, () => {
  it('sweeps a stale pending row', async () => {
    await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: STALE, fullName: 'Abandoned' })
      .expect(201);

    // Age it past the window rather than waiting a day.
    //
    // The timestamp is computed in JS and passed as a parameter. `interval
    // '${n} hours'` does not work: $executeRaw parameterises the placeholder,
    // so the interval literal would contain `$1` as text.
    const aged = new Date(Date.now() - (PENDING_TTL_HOURS + 1) * 3_600_000);
    await prisma.$executeRaw`
      UPDATE users SET created_at = ${aged} WHERE phone = ${STALE}`;

    const removed = await sweeper.removeExpired();
    expect(removed).toBeGreaterThanOrEqual(1);
    expect(await prisma.user.findFirst({ where: { phone: STALE } })).toBeNull();
  });

  it('does NOT sweep a verified account, however old', async () => {
    // The reason the sweeper asks three questions instead of one.
    const ancient = new Date(Date.now() - 400 * 86_400_000);
    await prisma.$executeRaw`
      UPDATE users SET created_at = ${ancient} WHERE phone = ${VERIFIED}`;

    await sweeper.removeExpired();
    expect(await prisma.user.findFirst({ where: { phone: VERIFIED } })).not.toBeNull();
  });

  it('does NOT sweep a recent pending row — someone mid-signup', async () => {
    const midSignup = `+2019${suffix}`;
    await request(http as never)
      .post('/v1/auth/register')
      .send({ phone: midSignup, fullName: 'Mid Signup' })
      .expect(201);

    await sweeper.removeExpired();
    const survivor = await prisma.user.findFirst({ where: { phone: midSignup } });
    expect(survivor).not.toBeNull();

    if (survivor) {
      await prisma.$executeRaw`DELETE FROM user_roles WHERE user_id = ${survivor.id}::uuid`;
      await prisma.$executeRaw`DELETE FROM users      WHERE id      = ${survivor.id}::uuid`;
    }
  });
});
