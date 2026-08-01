import type Redis from "ioredis";
import type { RateLimiter } from "../otp.ports";

/**
 * Production sliding-window limiter, per doc 09 section 1.1.
 *
 * Implemented on a sorted set: drop entries older than the window, count what
 * remains, add this hit. Wrapped in MULTI so the read and the write cannot
 * interleave with another request — otherwise two simultaneous callers both
 * see "limit - 1" and both proceed, which is exactly the burst the limit is
 * meant to stop.
 */
export class RedisRateLimiter implements RateLimiter {
  constructor(private readonly redis: Redis) {}

  async hit(key: string, limit: number, windowSeconds: number): Promise<boolean> {
    const now = Date.now();
    const cutoff = now - windowSeconds * 1000;
    const member = `${now}-${Math.random().toString(36).slice(2, 8)}`;

    const res = await this.redis
      .multi()
      .zremrangebyscore(key, 0, cutoff)
      .zadd(key, now, member)
      .zcard(key)
      .expire(key, windowSeconds)
      .exec();

    const count = Number(res?.[2]?.[1] ?? 0);
    if (count > limit) {
      // Over the line: take this hit back out so a blocked caller does not
      // extend their own lockout by retrying.
      await this.redis.zrem(key, member);
      return false;
    }
    return true;
  }
}