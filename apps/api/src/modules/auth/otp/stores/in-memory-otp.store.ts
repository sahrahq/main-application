import type { OtpStore, OtpChallenge } from "../otp.ports";

/**
 * DEV/TEST ONLY. Process-local, so it is wrong the moment there is more than
 * one API instance: a code issued by instance A would not verify on B, and
 * rate limits would be per-process rather than global.
 *
 * doc 09 section 1.1 specifies Redis. RedisOtpStore is the production adapter;
 * this exists so the OTP logic is testable without a running Redis and so
 * local development is not blocked on Docker.
 */
export class InMemoryOtpStore implements OtpStore {
  private readonly map = new Map<string, OtpChallenge>();

  constructor(private readonly now: () => number = () => Date.now()) {}

  async put(key: string, challenge: OtpChallenge): Promise<void> {
    this.map.set(key, { ...challenge });
  }

  async get(key: string): Promise<OtpChallenge | null> {
    const c = this.map.get(key);
    if (!c) return null;
    // Mirror Redis TTL semantics: expiry removes the key.
    if (c.expiresAtMs <= this.now()) {
      this.map.delete(key);
      return { ...c };
    }
    return { ...c };
  }

  async incrementAttempts(key: string): Promise<number> {
    const c = this.map.get(key);
    if (!c) return 0;
    c.attempts += 1;
    return c.attempts;
  }

  async consume(key: string): Promise<void> {
    this.map.delete(key);
  }

  /** Test helper: prove the plaintext code is not held anywhere. */
  dump(): Record<string, OtpChallenge> {
    return Object.fromEntries(this.map.entries());
  }
}