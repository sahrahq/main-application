import { Logger, Provider } from "@nestjs/common";
import Redis from "ioredis";
import { OTP_STORE, RATE_LIMITER, OTP_DELIVERY, OTP_CLOCK } from "./otp.ports";
import { RedisOtpStore } from "./stores/redis-otp.store";
import { RedisRateLimiter } from "./stores/redis-rate-limiter";
import { InMemoryOtpStore } from "./stores/in-memory-otp.store";
import { InMemoryRateLimiter } from "./stores/in-memory-rate-limiter";
import { LoggingOtpDelivery } from "./delivery/logging-otp.delivery";

/**
 * Choose the OTP backend.
 *
 * doc 09 section 1.1 specifies Redis, and Redis is REQUIRED in production: the
 * in-memory adapters are per-process, so with more than one API instance a
 * code issued by one would not verify on another and rate limits would be
 * divided by the instance count — an attacker simply gets N times the
 * allowance. So production fails closed rather than silently degrading.
 */
let redis: Redis | null = null;

function redisOrNull(): Redis | null {
  const url = process.env.REDIS_URL;
  const isProd = process.env.NODE_ENV === "production";

  if (!url) {
    if (isProd) {
      throw new Error(
        "REDIS_URL is required in production: OTP state and rate limits must be " +
          "shared across instances (doc 09 section 1.1). In-memory adapters are " +
          "per-process and would divide every rate limit by the instance count.",
      );
    }
    new Logger("OtpProviders").warn(
      "REDIS_URL not set — using in-memory OTP store and rate limiter. " +
        "Development only; these do not work across multiple instances.",
    );
    return null;
  }

  redis ??= new Redis(url, { maxRetriesPerRequest: 2, lazyConnect: false });
  return redis;
}

export const otpProviders: Provider[] = [
  {
    provide: OTP_STORE,
    useFactory: () => {
      const r = redisOrNull();
      return r ? new RedisOtpStore(r) : new InMemoryOtpStore();
    },
  },
  {
    provide: RATE_LIMITER,
    useFactory: () => {
      const r = redisOrNull();
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