import type Redis from "ioredis";
import type { OtpStore, OtpChallenge } from "../otp.ports";

/**
 * Production OTP store (doc 09 section 1.1: "phone OTP hashed in Redis,
 * 5-min TTL").
 *
 * Redis owns expiry: the key carries a TTL, so a lapsed challenge disappears
 * without a sweeper. Attempts are incremented server-side with HINCRBY so two
 * concurrent guesses cannot both read "4 attempts" and both be allowed.
 */
export class RedisOtpStore implements OtpStore {
  constructor(private readonly redis: Redis) {}

  async put(key: string, challenge: OtpChallenge): Promise<void> {
    const ttl = Math.max(1, Math.ceil((challenge.expiresAtMs - Date.now()) / 1000));
    await this.redis
      .multi()
      .hset(key, {
        phone: challenge.phone,
        codeHash: challenge.codeHash,
        purpose: challenge.purpose,
        attempts: String(challenge.attempts),
        expiresAtMs: String(challenge.expiresAtMs),
        // Redis hashes hold strings; empty string is the absent marker,
        // mirrored by the `|| null` on the way out.
        verifiedAt: challenge.verifiedAt === null ? '' : String(challenge.verifiedAt),
      })
      .expire(key, ttl)
      .exec();
  }

  async get(key: string): Promise<OtpChallenge | null> {
    const h = await this.redis.hgetall(key);
    if (!h || !h.codeHash) return null;
    return {
      phone: h.phone ?? '',
      codeHash: h.codeHash,
      purpose: h.purpose as OtpChallenge["purpose"],
      attempts: Number(h.attempts ?? 0),
      expiresAtMs: Number(h.expiresAtMs ?? 0),
      verifiedAt: h.verifiedAt ? Number(h.verifiedAt) : null,
    };
  }

  /**
   * Mark the challenge answered and re-stamp its TTL for the completion
   * window. A separate method rather than a `put`, because `put` would rewrite
   * `attempts` from a value the caller read earlier and lose a concurrent
   * HINCRBY.
   */
  async markVerified(key: string, verifiedAtMs: number, expiresAtMs: number): Promise<void> {
    const ttl = Math.max(1, Math.ceil((expiresAtMs - Date.now()) / 1000));
    await this.redis
      .multi()
      .hset(key, { verifiedAt: String(verifiedAtMs), expiresAtMs: String(expiresAtMs) })
      .expire(key, ttl)
      .exec();
  }

  async incrementAttempts(key: string): Promise<number> {
    return this.redis.hincrby(key, "attempts", 1);
  }

  async consume(key: string): Promise<void> {
    await this.redis.del(key);
  }

  async setLive(scope: string, challengeId: string, ttlSeconds: number): Promise<void> {
    await this.redis.set(scope, challengeId, 'EX', Math.max(1, ttlSeconds));
  }

  async getLive(scope: string): Promise<string | null> {
    return this.redis.get(scope);
  }

  /**
   * A separate key with its own TTL, so Redis expires the lock and `consume`
   * on the challenge cannot remove it.
   *
   * `SET … NX PX` — set only if absent. Two concurrent fifth-failures must not
   * let the second one restart the clock the first one began; NX makes the
   * first writer win and the second a no-op.
   */
  async lock(key: string, untilMs: number): Promise<void> {
    const ttl = Math.max(1, untilMs - Date.now());
    await this.redis.set(lockKey(key), String(untilMs), 'PX', ttl, 'NX');
  }

  async lockedForMs(key: string): Promise<number> {
    const ttl = await this.redis.pttl(lockKey(key));
    // -2 = no key, -1 = key with no expiry (which this never writes).
    return ttl > 0 ? ttl : 0;
  }
}

/** Namespaced away from the challenge so neither can clobber the other. */
function lockKey(key: string): string {
  return `${key}:lock`;
}