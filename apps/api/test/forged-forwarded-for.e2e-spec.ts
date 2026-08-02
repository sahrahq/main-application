/**
 * A FORGED `X-Forwarded-For` MUST NOT BE BELIEVED.
 *
 * This tests the attack, not the feature. `req.ip` drives every per-IP rate
 * limit in the system (doc 06 §1: "OTP send 3/10min … per user/IP") and is
 * written into `refresh_tokens.ip`, which is the audit trail for a stolen
 * token. Both are derived from a header the client sends.
 *
 * With `trust proxy: true` — the setting a developer reaches for first — a
 * request carrying `X-Forwarded-For: 1.2.3.4` is credited to 1.2.3.4. Every
 * per-IP limit is then bypassable by rotating a string, for free, unlimited,
 * leaving an audit trail of whatever the attacker typed. That is worse than
 * the limit being too strict: too strict is visible, bypassable is invisible
 * AND reassuring.
 *
 * So the assertion is not "the header is parsed correctly". It is "the
 * attacker gains nothing", expressed as: 100 requests carrying 100 different
 * forged addresses must still exhaust ONE per-IP budget.
 */
import { INestApplication } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { resolveTrustProxy, DEFAULT_HOPS, TRUST_PROXY_ENV } from '../src/shared/config/trust-proxy';
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

beforeAll(async () => {
  await prisma.$connect();
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    .compile();

  const nest = mod.createNestApplication<NestExpressApplication>();
  // EXACTLY what bootstrap does. A test that configured this differently
  // would be testing a different application than the one that ships.
  nest.set('trust proxy', resolveTrustProxy(process.env).hops);
  nest.setGlobalPrefix('v1', { exclude: ['health'] });
  await nest.init();

  app = nest;
  http = nest.getHttpServer();
}, 90_000);

afterAll(async () => {
  if (app) await app.close();
  const users = await prisma.user.findMany({
    where: { phone: { startsWith: `+2019${suffix.slice(0, 5)}` } },
    select: { id: true },
  });
  for (const u of users) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${u.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${u.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${u.id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('the configuration itself', () => {
  it('defaults to trusting NO proxy', () => {
    expect(resolveTrustProxy({}).hops).toBe(DEFAULT_HOPS);
    expect(DEFAULT_HOPS).toBe(0);
  });

  it('REFUSES TO BOOT in production without an explicit value', () => {
    // The failure mode of forgetting is silent — the app runs, the limits look
    // like they work, and every one of them counts the load balancer. So it is
    // a startup crash, not a warning.
    expect(() => resolveTrustProxy({ NODE_ENV: 'production' })).toThrow(
      /required in production/i,
    );
  });

  it('rejects `true`, `*` and a subnet list — only a hop count is allowed', () => {
    for (const bad of ['true', '*', '10.0.0.0/8', 'loopback', '-1', '1.5']) {
      expect(() => resolveTrustProxy({ [TRUST_PROXY_ENV]: bad })).toThrow();
    }
  });

  it('accepts the doc 08 §5 topology: Cloudflare -> ALB -> app = 2', () => {
    expect(resolveTrustProxy({ [TRUST_PROXY_ENV]: '2' }).hops).toBe(2);
  });

  it('explains itself for the boot log — silent security config is unreviewable', () => {
    expect(resolveTrustProxy({ [TRUST_PROXY_ENV]: '2' }).reason).toMatch(/X-Forwarded-For/);
    expect(resolveTrustProxy({}).reason).toMatch(/trusting no proxy/i);
  });
});

describe('the attack: rotating a forged X-Forwarded-For', () => {
  it('does NOT buy a fresh per-IP OTP budget', async () => {
    // doc 06 §1 allows 10 sends per IP per 10 minutes. An attacker spraying
    // codes at strangers' numbers would like each request to look like a
    // different source. Here they try exactly that.
    //
    // Every request carries a DIFFERENT forged address. If any of them were
    // believed, the per-IP counter would spread across many keys and the
    // attacker would never be limited.
    const phones = Array.from({ length: 16 }, (_, i) => `+2019${suffix.slice(0, 5)}${String(i).padStart(2, '0')}`);

    let limited = false;
    for (let i = 0; i < phones.length; i++) {
      const res = await request(http as never)
        .post('/v1/auth/register')
        .set('X-Forwarded-For', `203.0.113.${i + 1}`)
        .send({ phone: phones[i], fullName: `Sprayer ${i}` });

      // `register` swallows a rate-limited send, so the 201 is not the signal.
      // The signal is whether a CODE actually went out.
      if (res.status === 201) {
        const sent = delivery.sent.filter((m) => m.phone === phones[i]);
        if (sent.length === 0) {
          limited = true;
          break;
        }
      }
    }

    expect(limited).toBe(true);
  }, 120_000);

  it('and the same forgery does not launder a per-PHONE budget either', async () => {
    const phone = `+2019${suffix.slice(0, 5)}99`;
    await request(http as never)
      .post('/v1/auth/register')
      .set('X-Forwarded-For', '198.51.100.1')
      .send({ phone, fullName: 'Per Phone' })
      .expect(201);

    // doc 06 §1: 3 sends per phone per 10 minutes, keyed on the PHONE, so it
    // was never IP-dependent — asserted anyway, because "the other limit
    // still holds" is the claim that makes the first test meaningful rather
    // than a coincidence of ordering.
    let limited = false;
    for (let i = 0; i < 6; i++) {
      const res = await request(http as never)
        .post('/v1/auth/request-otp')
        .set('X-Forwarded-For', `198.51.100.${i + 10}`)
        .send({ phone });
      if (res.status === 429) {
        expect(res.body.error.code).toBe('otp_rate_limited');
        limited = true;
        break;
      }
    }
    expect(limited).toBe(true);
  }, 120_000);
});
