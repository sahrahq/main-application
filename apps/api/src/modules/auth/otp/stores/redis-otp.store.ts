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
        codeHash: challenge.codeHash,
        purpose: challenge.purpose,
        attempts: String(challenge.attempts),
        expiresAtMs: String(challenge.expiresAtMs),
      })
      .expire(key, ttl)
      .exec();
  }

  async get(key: string): Promise<OtpChallenge | null> {
    const h = await this.redis.hgetall(key);
    if (!h || !h.codeHash) return null;
    return {
      codeHash: h.codeHash,
      purpose: h.purpose as OtpChallenge["purpose"],
      attempts: Number(h.attempts ?? 0),
      expiresAtMs: Number(h.expiresAtMs ?? 0),
    };
  }

  async incrementAttempts(key: string): Promise<number> {
    return this.redis.hincrby(key, "attempts", 1);
  }

  async consume(key: string): Promise<void> {
    await this.redis.del(key);
  }
}