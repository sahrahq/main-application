import type { RateLimiter } from "../otp.ports";

/**
 * DEV/TEST ONLY sliding-window limiter. Same caveat as InMemoryOtpStore: it is
 * per-process, so with more than one instance an attacker gets N times the
 * allowance. RedisRateLimiter is the production adapter.
 */
export class InMemoryRateLimiter implements RateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(private readonly now: () => number = () => Date.now()) {}

  async hit(key: string, limit: number, windowSeconds: number): Promise<boolean> {
    const now = this.now();
    const cutoff = now - windowSeconds * 1000;

    // Sliding, not fixed: a fixed window lets 2x the limit through across a
    // boundary, which for paid SMS is real money.
    const recent = (this.hits.get(key) ?? []).filter((t) => t > cutoff);
    if (recent.length >= limit) {
      this.hits.set(key, recent);
      return false;
    }

    recent.push(now);
    this.hits.set(key, recent);
    return true;
  }
}