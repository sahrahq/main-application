/**
 * Adapter parity: the Redis adapters must behave EXACTLY like the in-memory
 * ones the OTP logic was tested against.
 *
 * The unit suite proves OtpService is correct given a conforming store. This
 * proves the Redis implementations conform — the gap where a "tested" feature
 * still breaks in production because only the fake was ever exercised.
 *
 * The Redis half SKIPS ITSELF when REDIS_URL is unreachable, and says so
 * loudly rather than passing quietly. Run it once Redis is up:
 *   docker compose up -d && pnpm --filter @sahra/api test:e2e
 */
import Redis from 'ioredis';
import { OtpService, OTP_TTL_SECONDS, MAX_ATTEMPTS } from '../src/modules/auth/otp/otp.service';
import { InMemoryOtpStore } from '../src/modules/auth/otp/stores/in-memory-otp.store';
import { InMemoryRateLimiter } from '../src/modules/auth/otp/stores/in-memory-rate-limiter';
import { RedisOtpStore } from '../src/modules/auth/otp/stores/redis-otp.store';
import { RedisRateLimiter } from '../src/modules/auth/otp/stores/redis-rate-limiter';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import type { OtpStore, RateLimiter } from '../src/modules/auth/otp/otp.ports';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

/**
 * Decided in test/global-setup.ts, BEFORE describes are registered — so an
 * unavailable Redis produces a real `skipped`, never a green tick.
 */
const REDIS_UP = process.env.REDIS_AVAILABLE === '1';

let redis: Redis | null = null;

beforeAll(async () => {
  if (!REDIS_UP) return;
  redis = new Redis(REDIS_URL, { lazyConnect: true, maxRetriesPerRequest: 2 });
  await redis.connect();
  await redis.ping();
}, 30_000);

afterAll(async () => {
  if (redis) {
    const keys = await redis.keys('otp:*parity*');
    if (keys.length) await redis.del(...keys);
    await redis.quit();
  }
});

/**
 * One contract, run against whichever adapter pair is given. Anything asserted
 * here must hold for BOTH, or the production swap is not safe.
 */
function contract(
  name: string,
  enabled: boolean,
  make: () => { store: OtpStore; limiter: RateLimiter },
) {
  // describe.skip, not a runtime early-return: a skipped adapter must show as
  // SKIPPED in the report, never as a pass.
  const block = enabled ? describe : describe.skip;

  block(`${name} — OTP store contract`, () => {
    const build = () => {
      const parts = make();
      const delivery = new RecordingOtpDelivery();
      return { service: new OtpService(parts.store, parts.limiter, delivery), delivery };
    };

    it('issues, verifies once, and refuses the replay', async () => {
      const b = build();
      const user = `parity-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

      await b.service.issue({ userId: user, phone: '+201000000000', purpose: 'phone_verify' });
      const { code } = b.delivery.sent[0];

      await expect(b.service.verify({ userId: user, purpose: 'phone_verify', code })).resolves.toBe(true);
      await expect(
        b.service.verify({ userId: user, purpose: 'phone_verify', code }),
      ).rejects.toMatchObject({ response: { code: 'invalid_otp' } });
    }, 30_000);

    it(`locks after ${MAX_ATTEMPTS} wrong codes`, async () => {
      const b = build();
      const user = `parity-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

      await b.service.issue({ userId: user, phone: '+201000000000', purpose: 'phone_verify' });
      const { code } = b.delivery.sent[0];

      for (let i = 0; i < MAX_ATTEMPTS; i++) {
        await expect(
          b.service.verify({ userId: user, purpose: 'phone_verify', code: '000000' }),
        ).rejects.toBeDefined();
      }
      // Attempt counting must survive the round trip — if HINCRBY were wrong,
      // the correct code would still work here and brute force would be open.
      await expect(
        b.service.verify({ userId: user, purpose: 'phone_verify', code }),
      ).rejects.toMatchObject({ response: { code: 'too_many_attempts' } });
    }, 30_000);

    it('never persists the plaintext code', async () => {
      const b = build();
      const user = `parity-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

      await b.service.issue({ userId: user, phone: '+201000000000', purpose: 'phone_verify' });
      const { code } = b.delivery.sent[0];

      if (redis) {
        const stored = await redis.hgetall(`otp:phone_verify:${user}`);
        expect(JSON.stringify(stored)).not.toContain(code);
        expect(stored.codeHash).toBeDefined();
      }
    }, 30_000);

    it('enforces the per-phone send cap', async () => {
      const b = build();
      const phone = `+2010${Date.now().toString().slice(-8)}`;

      for (let i = 0; i < 3; i++) {
        await b.service.issue({ userId: `parity-u${i}`, phone, purpose: 'phone_verify' });
      }
      await expect(
        b.service.issue({ userId: 'parity-u9', phone, purpose: 'phone_verify' }),
      ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });
    }, 30_000);

    it('a blocked caller cannot extend their own lockout by retrying', async () => {
      const b = build();
      const phone = `+2011${Date.now().toString().slice(-8)}`;

      for (let i = 0; i < 3; i++) {
        await b.service.issue({ userId: 'parity-r', phone, purpose: 'phone_verify' });
      }
      // Hammering while blocked must not push the window forward — otherwise a
      // retry loop locks the real user out indefinitely.
      for (let i = 0; i < 5; i++) {
        await expect(
          b.service.issue({ userId: 'parity-r', phone, purpose: 'phone_verify' }),
        ).rejects.toMatchObject({ response: { code: 'otp_rate_limited' } });
      }

      if (redis) {
        const count = await redis.zcard(`otp:send:phone:${phone}`);
        expect(count).toBe(3); // still 3, not 8
      }
    }, 30_000);
  });
}

// Always runs — the reference implementation.
contract('InMemory', true, () => ({
  store: new InMemoryOtpStore(),
  limiter: new InMemoryRateLimiter(),
}));

// Runs ONLY when Redis is actually reachable; otherwise reported as skipped.
contract('Redis', REDIS_UP, () => ({
  store: new RedisOtpStore(redis!),
  limiter: new RedisRateLimiter(redis!),
}));

describe('Redis availability', () => {
  it('states plainly whether the Redis half ran', () => {
    // eslint-disable-next-line no-console
    console.log(
      REDIS_UP
        ? '  Redis adapters: EXERCISED against a live server'
        : '  Redis adapters: SKIPPED — a green suite does NOT mean they were verified',
    );
    expect(typeof REDIS_UP).toBe('boolean');
  });
});
