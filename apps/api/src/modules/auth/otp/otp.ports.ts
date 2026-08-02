/**
 * Ports for the OTP feature. The service depends on these, never on Redis or
 * a carrier SDK, so the storage backend and the delivery channel can each be
 * swapped without touching the logic that decides whether a code is valid.
 */

export type OtpPurpose = "phone_verify" | "login" | "password_reset";

/** A code in flight. `codeHash` only — the plaintext leaves in the message. */
export interface OtpChallenge {
  codeHash: string;
  purpose: OtpPurpose;
  attempts: number;
  expiresAtMs: number;
}

export interface OtpStore {
  put(key: string, challenge: OtpChallenge): Promise<void>;
  get(key: string): Promise<OtpChallenge | null>;
  /** Returns the attempt count AFTER incrementing. */
  incrementAttempts(key: string): Promise<number>;
  /** Spend the challenge. A consumed OTP must never verify twice. */
  consume(key: string): Promise<void>;

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