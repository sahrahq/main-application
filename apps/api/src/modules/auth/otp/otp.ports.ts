/**
 * Ports for the OTP feature. The service depends on these, never on Redis or
 * a carrier SDK, so the storage backend and the delivery channel can each be
 * swapped without touching the logic that decides whether a code is valid.
 */

export type OtpPurpose = "phone_verify" | "login" | "password_reset";

/**
 * A code in flight, stored under an OPAQUE CHALLENGE ID.
 *
 * NOT under a user id, and that is the whole of AUTH-3's closure: issuing a
 * challenge involves no account lookup, so the response cannot carry
 * information about whether the number is registered. There is nothing to
 * equalise because there are no branches.
 *
 * `codeHash` only — the plaintext leaves in the message and is never stored.
 */
export interface OtpChallenge {
  /**
   * The number the code was sent to, in E.164.
   *
   * Held here because the account is not resolved until verification. It is
   * the only copy for the life of the challenge (five minutes), and it is what
   * `verify` returns so the caller can look up — or create — the account
   * afterwards.
   */
  phone: string;

  codeHash: string;
  purpose: OtpPurpose;
  attempts: number;
  expiresAtMs: number;

  /**
   * When the correct code was entered, or null.
   *
   * SINGLE-USE ACROSS A PAIR, not per call. A diner with no account answers
   * their code and then has to supply a name; the challenge has to survive
   * between those two requests, and it must be impossible to answer twice.
   * So verification marks this instead of deleting, `verify` refuses a
   * challenge that already carries it, and completion is what finally spends
   * it.
   */
  verifiedAt: number | null;
}

export interface OtpStore {
  put(key: string, challenge: OtpChallenge): Promise<void>;
  get(key: string): Promise<OtpChallenge | null>;
  /** Returns the attempt count AFTER incrementing. */
  incrementAttempts(key: string): Promise<number>;

  /**
   * Record that the correct code was entered, and re-stamp expiry for the
   * completion window. Does not delete — see `OtpChallenge.verifiedAt`.
   */
  markVerified(key: string, verifiedAtMs: number, expiresAtMs: number): Promise<void>;
  /** Spend the challenge. A consumed OTP must never verify twice. */
  consume(key: string): Promise<void>;

  /**
   * Remember which challenge is the live one for a scope, and read it back.
   *
   * ONE LIVE CODE PER NUMBER, per purpose. Without this, every resend would
   * leave the previous code working until its own expiry, so asking for a new
   * code would WIDEN the window instead of replacing it — a property the
   * previous user-keyed design had and this one would otherwise have lost
   * silently.
   *
   * Scoped by a hash of the phone rather than a user id, because issuing looks
   * nothing up (AUTH-3).
   */
  setLive(scope: string, challengeId: string, ttlSeconds: number): Promise<void>;
  getLive(scope: string): Promise<string | null>;

  /**
   * Lock verification for a (user, purpose) until [untilMs].
   *
   * SEPARATE FROM THE CHALLENGE, deliberately. The attempt cap on a challenge
   * is decorative on its own: after five wrong guesses the attacker simply
   * requests a new code and buys five more. doc 11 flow 1 specifies
   * "5 fails → Locked 15 min", and a lock that a new send resets is not that.
   *
   * So this key outlives the challenge and is NOT touched by `issue`.
   */
  lock(key: string, untilMs: number): Promise<void>;

  /** Milliseconds remaining on a lock, or 0 if there is none. */
  lockedForMs(key: string): Promise<number>;
}

export interface RateLimiter {
  /**
   * Count one hit against `key`. Returns false when the caller is over
   * `limit` within `windowSeconds` — a sliding window, so a burst at the
   * boundary cannot double the allowance.
   */
  hit(key: string, limit: number, windowSeconds: number): Promise<boolean>;
}

/**
 * Where the code physically goes.
 *
 * doc 02 C-1.2 wants WhatsApp first with SMS fallback. Neither can be wired
 * until the company is registered and has a WhatsApp Business account, so the
 * shipped adapter logs instead. See
 * docs/decisions/2026-08-01-otp-delivery-deferred.md.
 */
export interface OtpDelivery {
  send(message: { phone: string; code: string; purpose: OtpPurpose }): Promise<void>;
  /** For logs and audit: "whatsapp", "sms", "log". */
  readonly channel: string;
}

export const OTP_STORE = Symbol("OTP_STORE");
export const RATE_LIMITER = Symbol("RATE_LIMITER");
export const OTP_DELIVERY = Symbol("OTP_DELIVERY");
/** Injectable clock, so expiry is testable without sleeping. */
export const OTP_CLOCK = Symbol("OTP_CLOCK");