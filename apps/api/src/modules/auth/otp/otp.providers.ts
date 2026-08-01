import { Logger, Provider } from '@nestjs/common';
import Redis from 'ioredis';
import { OTP_STORE, RATE_LIMITER, OTP_DELIVERY, OTP_CLOCK } from './otp.ports';
import { RedisOtpStore } from './stores/redis-otp.store';
import { RedisRateLimiter } from './stores/redis-rate-limiter';
import { InMemoryOtpStore } from './stores/in-memory-otp.store';
import { InMemoryRateLimiter } from './stores/in-memory-rate-limiter';
import { LoggingOtpDelivery } from './delivery/logging-otp.delivery';

const logger = new Logger('OtpProviders');

/**
 * Resolve the OTP backend ONCE at boot, by actually talking to Redis.
 *
 * doc 09 §1.1 specifies Redis, and production requires it: the in-memory
 * adapters are per-process, so with more than one API instance a code issued
 * by A would not verify on B, and every rate limit would be divided by the
 * instance count — an attacker simply gets N times the allowance.
 *
 * The probe matters. `new Redis(url)` does NOT fail when the server is down;
 * it retries in the background while commands queue, so the API would look
 * healthy while OTP silently hung. Connecting and PINGing at boot forces a
 * verdict: use Redis, fall back loudly, or refuse to start.
 */
let cached: Promise<Redis | null> | null = null;

function resolveRedis(): Promise<Redis | null> {
  cached ??= (async (): Promise<Redis | null> => {
    const url = process.env.REDIS_URL;
    const isProd = process.env.NODE_ENV === 'production';

    if (!url) {
      if (isProd) {
        throw new Error(
          'REDIS_URL is required in production: OTP state and rate limits must ' +
            'be shared across instances (doc 09 §1.1). The in-memory adapters are ' +
            'per-process and would divide every rate limit by the instance count.',
        );
      }
      logger.warn('REDIS_URL not set — using in-memory OTP store and rate limiter (dev only).');
      return null;
    }

    const client = new Redis(url, {
      lazyConnect: true,
      maxRetriesPerRequest: 2,
      // Do not sit reconnecting forever at boot; we want an answer.
      retryStrategy: (times) => (times > 2 ? null : 200),
    });

    try {
      await client.connect();
      await client.ping();
      logger.log(`OTP backed by Redis at ${redact(url)}`);
      return client;
    } catch (err) {
      client.disconnect();
      if (isProd) {
        throw new Error(
          `REDIS_URL is set but unreachable (${redact(url)}): ${String(err)}. ` +
            'Refusing to start in production with per-process OTP state.',
        );
      }
      logger.warn(
        `Redis unreachable at ${redact(url)} — falling back to in-memory OTP store ` +
          'and rate limiter. Development only; these do not work across instances.',
      );
      return null;
    }
  })();

  return cached;
}

/** Never log credentials embedded in a connection string. */
function redact(url: string): string {
  return url.replace(/\/\/[^@]*@/, '//***@');
}

export const otpProviders: Provider[] = [
  {
    provide: OTP_STORE,
    useFactory: async () => {
      const r = await resolveRedis();
      return r ? new RedisOtpStore(r) : new InMemoryOtpStore();
    },
  },
  {
    provide: RATE_LIMITER,
    useFactory: async () => {
      const r = await resolveRedis();
      return r ? new RedisRateLimiter(r) : new InMemoryRateLimiter();
    },
  },
  {
    // Swap this binding for WhatsAppOtpDelivery once the company is registered.
    // See docs/decisions/2026-08-01-otp-delivery-deferred.md
    provide: OTP_DELIVERY,
    useFactory: () => new LoggingOtpDelivery(),
  },
  {
    provide: OTP_CLOCK,
    useValue: () => Date.now(),
  },
];
