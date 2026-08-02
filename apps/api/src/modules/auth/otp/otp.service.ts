import {
  Injectable, Inject, Optional, BadRequestException, HttpException, HttpStatus,
} from '@nestjs/common';
import { createHash, randomInt, timingSafeEqual } from 'crypto';
import {
  OtpStore, RateLimiter, OtpDelivery, OtpPurpose,
  OTP_STORE, RATE_LIMITER, OTP_DELIVERY, OTP_CLOCK,
} from './otp.ports';

/** doc 09 §1.1 — 5-minute TTL, 5 attempts. */
export const OTP_TTL_SECONDS = 5 * 60;
export const MAX_ATTEMPTS = 5;

/**
 * doc 11 flow 1 — "5 fails → Locked 15 min + resend option".
 *
 * WITHOUT THIS THE ATTEMPT CAP IS DECORATIVE. Five wrong guesses locked the
 * CHALLENGE, and the attacker simply requested a new code and bought five
 * more: the real budget was 3 codes × 5 attempts = 15 guesses per 10 minutes,
 * forever. The lock is keyed on the USER, lives in its own key, and `issue`
 * does not touch it.
 *
 * IF THIS NUMBER CHANGES, CHANGE THE COPY. `errTooManyAttempts` states the
 * wait in words, in both locales, because a diner told only "too many
 * attempts" will keep requesting codes that cannot help them — which is a
 * support call. Asserted by otp.service.spec.ts.
 */
export const LOCK_SECONDS = 15 * 60;

/** doc 06 §1 — "OTP send 3/10min". Applied per phone AND per IP. */
export const SEND_LIMIT_PER_PHONE = 3;
export const SEND_LIMIT_PER_IP = 10;
export const SEND_WINDOW_SECONDS = 10 * 60;

export interface IssueInput {
  userId: string;
  phone: string;
  purpose: OtpPurpose;
  ip?: string | null;
}

export interface VerifyInput {
  userId: string;
  purpose: OtpPurpose;
  code: string;
}

/**
 * Phone OTP (doc 02 C-1.2, doc 09 §1.1).
 *
 * Depends only on ports: the store may be Redis or in-memory, delivery may be
 * WhatsApp, SMS or a log. Nothing here knows which.
 *
 * The rate limits are part of the feature, not hardening bolted on later.
 * Every send costs money, and an unmetered send endpoint is a way to bill
 * SAHRA for someone else's traffic — doc 09 §1.1 calls SMS-pumping "a real
 * cost attack in Egypt".
 */
@Injectable()
export class OtpService {
  constructor(
    @Inject(OTP_STORE) private readonly store: OtpStore,
    @Inject(RATE_LIMITER) private readonly limiter: RateLimiter,
    @Inject(OTP_DELIVERY) private readonly delivery: OtpDelivery,
    /**
     * Injectable clock. Expiry is a security property, so it has to be
     * testable without sleeping for five real minutes — and a service that
     * reads the wall clock directly cannot be tested at all.
     */
    @Optional() @Inject(OTP_CLOCK) private readonly now: () => number = () => Date.now(),
  ) {}

  async issue(input: IssueInput): Promise<void> {
    // Per-phone first: this protects the human being messaged, and it holds
    // even when the attacker rotates IPs.
    const phoneOk = await this.limiter.hit(
      `otp:send:phone:${input.phone}`,
      SEND_LIMIT_PER_PHONE,
      SEND_WINDOW_SECONDS,
    );
    if (!phoneOk) throw this.rateLimited();

    // Per-IP catches the other shape: one source spraying many numbers.
    if (input.ip) {
      const ipOk = await this.limiter.hit(
        `otp:send:ip:${input.ip}`,
        SEND_LIMIT_PER_IP,
        SEND_WINDOW_SECONDS,
      );
      if (!ipOk) throw this.rateLimited();
    }

    // randomInt is CSPRNG-backed. Math.random() here would make codes
    // predictable from a couple of observed samples.
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');

    await this.store.put(this.key(input.userId, input.purpose), {
      codeHash: hash(code),
      purpose: input.purpose,
      attempts: 0,
      expiresAtMs: this.now() + OTP_TTL_SECONDS * 1000,
    });

    await this.delivery.send({ phone: input.phone, code, purpose: input.purpose });
  }

  /** True on success. Throws with a machine-readable code otherwise. */
  async verify(input: VerifyInput): Promise<boolean> {
    const key = this.key(input.userId, input.purpose);

    // FIRST, before anything else is read. A locked user is locked whatever
    // challenge is in flight — including a brand-new one they just requested,
    // which is the whole point of the lock outliving the challenge.
    const lockedFor = await this.store.lockedForMs(key);
    if (lockedFor > 0) throw this.tooManyAttempts(Math.ceil(lockedFor / 1000));

    const challenge = await this.store.get(key);

    if (!challenge) throw this.invalid();

    if (challenge.expiresAtMs <= this.now()) {
      await this.store.consume(key);
      throw new BadRequestException({
        code: 'otp_expired',
        message: 'That code has expired. Request a new one.',
        message_ar: 'انتهت صلاحية الكود. اطلب كود جديد.',
      });
    }

    // Check the cap BEFORE comparing, so a spent challenge cannot be probed
    // further — otherwise the attacker still learns which guess was right.
    if (challenge.attempts >= MAX_ATTEMPTS) {
      await this.store.lock(key, this.now() + LOCK_SECONDS * 1000);
      throw this.tooManyAttempts(LOCK_SECONDS);
    }

    if (!matches(input.code, challenge.codeHash)) {
      const attempts = await this.store.incrementAttempts(key);
      if (attempts >= MAX_ATTEMPTS) {
        // The fifth failure locks the USER, not the challenge. Requesting a
        // new code from here changes nothing until the lock expires.
        await this.store.lock(key, this.now() + LOCK_SECONDS * 1000);
        throw this.tooManyAttempts(LOCK_SECONDS);
      }
      throw this.invalid();
    }

    await this.store.consume(key);
    return true;
  }

  /** One live challenge per (user, purpose) — a new send supersedes the old. */
  private key(userId: string, purpose: OtpPurpose): string {
    return `otp:${purpose}:${userId}`;
  }

  private invalid(): BadRequestException {
    return new BadRequestException({
      code: 'invalid_otp',
      message: 'That code is not correct.',
      message_ar: 'الكود ده مش صحيح.',
    });
  }

  /**
   * 429 per doc 06 §2 ("5 attempts → 429"), now carrying how long the wait is.
   *
   * TWO THINGS THIS COPY HAS TO DO, and the first draft got neither.
   *
   * 1. Say that WAITING is required. "Request a new code" is precisely what
   *    does not work during a lock, so a diner following it burns their three
   *    sends against a shut door and then contacts support.
   * 2. Put the fault on the ATTEMPT, not the person. A draft that opened with
   *    "wrong codes, too many of them" reads in Egyptian Arabic as being told
   *    off — at the moment the reader is already locked out and frustrated.
   *
   * These strings are the FALLBACK for a client that does not know the code;
   * the client owns its own copy in `errTooManyAttempts`. They are kept
   * word-for-word identical so the two cannot drift into saying different
   * things about the same lock.
   *
   * `retry_after` carries the seconds, which the error filter also promotes to
   * the `Retry-After` header.
   */
  private tooManyAttempts(retryAfterSeconds: number): HttpException {
    return new HttpException(
      {
        code: 'too_many_attempts',
        message: "Too many attempts. Please wait 15 minutes and try again — asking for a new code won't help until then.",
        message_ar: 'حاولت كتير والكود مظبطش. استنى ١٥ دقيقة وجرّب تاني — طلب كود جديد مش هيفيد دلوقتي.',
        retry_after: retryAfterSeconds,
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  private rateLimited(): HttpException {
    return new HttpException(
      {
        code: 'otp_rate_limited',
        message: 'Too many codes requested. Try again shortly.',
        message_ar: 'طلبت أكواد كتير. حاول بعد شوية.',
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}

function hash(code: string): string {
  return createHash('sha256').update(code).digest('hex');
}

/** Constant-time compare so response timing does not leak a partial match. */
function matches(code: string, expectedHash: string): boolean {
  const a = Buffer.from(hash(code), 'hex');
  const b = Buffer.from(expectedHash, 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}
