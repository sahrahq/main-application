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

  /// Locks live in their own map so `consume` — which deletes a challenge —
  /// cannot take a lock with it. Answering the fifth wrong code and then
  /// requesting a fresh one must leave the lock standing.
  private readonly locks = new Map<string, number>();

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

  async markVerified(key: string, verifiedAtMs: number, expiresAtMs: number): Promise<void> {
    const c = this.map.get(key);
    if (!c) return;
    c.verifiedAt = verifiedAtMs;
    c.expiresAtMs = expiresAtMs;
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

  private readonly live = new Map<string, { challengeId: string; expiresAtMs: number }>();

  async setLive(scope: string, challengeId: string, ttlSeconds: number): Promise<void> {
    this.live.set(scope, { challengeId, expiresAtMs: this.now() + ttlSeconds * 1000 });
  }

  async getLive(scope: string): Promise<string | null> {
    const entry = this.live.get(scope);
    if (!entry) return null;
    if (entry.expiresAtMs <= this.now()) {
      this.live.delete(scope);
      return null;
    }
    return entry.challengeId;
  }

  async lock(key: string, untilMs: number): Promise<void> {
    // Never shorten an existing lock: two concurrent failures must not let the
    // second one reset the clock the first one started.
    const current = this.locks.get(key) ?? 0;
    this.locks.set(key, Math.max(current, untilMs));
  }

  async lockedForMs(key: string): Promise<number> {
    const until = this.locks.get(key);
    if (until === undefined) return 0;
    const remaining = until - this.now();
    if (remaining <= 0) {
      this.locks.delete(key);
      return 0;
    }
    return remaining;
  }

  /** Test helper: prove the plaintext code is not held anywhere. */
  dump(): Record<string, OtpChallenge> {
    return Object.fromEntries(this.map.entries());
  }
}