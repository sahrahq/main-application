import {
  Injectable, Inject, Optional, BadRequestException, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'crypto';
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

/**
 * How long a VERIFIED challenge survives while its owner supplies a name.
 *
 * Ten minutes. The code's own life is five, which is the right length for
 * "read an SMS and type six digits"; this window covers "type your name on a
 * bad connection, having already proved the number is yours", which is a
 * different and more forgiving task. Long enough that nobody re-does the SMS;
 * short enough that an abandoned verified challenge is not a standing
 * half-credential — it expires with the key rather than lingering.
 */
export const VERIFIED_TTL_SECONDS = 10 * 60;

/**
 * THE WALLET FUSE. A global daily ceiling on deliveries, across every phone
 * and every IP.
 *
 * `request-otp` no longer looks anything up, which is what closes AUTH-3 — and
 * it means anyone can cause an SMS to any number. The per-phone limit caps
 * harassment of one person and the per-IP limit caps one source, but neither
 * caps the BILL: an attacker with a hundred addresses stays inside both while
 * spending real money.
 *
 * This is a spend control, not a security control. It is deliberately dumb:
 * no reputation, nothing adaptive, one number from the environment.
 *
 * Required in production, exactly like TRUST_PROXY_HOPS — a fuse with no
 * rating is not a fuse. Development gets a generous default and a log line, so
 * nobody is blocked from running the API locally.
 */
export const GLOBAL_SEND_WINDOW_SECONDS = 24 * 60 * 60;
export const GLOBAL_SEND_KEY = 'otp:send:global';

export interface IssueInput {
  phone: string;
  purpose: OtpPurpose;
  ip?: string | null;
}

export interface VerifyInput {
  challengeId: string;
  code: string;
}

/** What a verified challenge resolves to. No account is implied. */
export interface VerifiedChallenge {
  phone: string;
  purpose: OtpPurpose;
}

/**
 * Read the global daily ceiling.
 *
 * Exported and pure so `otp.service.spec.ts` can assert both branches without
 * booting the app — the production requirement is the half that cannot be
 * checked by running in development.
 */
export function globalSendLimitFrom(
  env: Record<string, string | undefined>,
  logger?: { warn(message: string): void },
): number {
  const raw = env.OTP_GLOBAL_DAILY_SEND_LIMIT;

  if (raw === undefined || raw.trim() === '') {
    if (env.NODE_ENV === 'production') {
      throw new Error(
        'OTP_GLOBAL_DAILY_SEND_LIMIT is required in production. Every request-otp ' +
          'call sends an SMS to a number the caller chooses, and this is the only ' +
          'ceiling on what that can cost. Set it deliberately.',
      );
    }
    logger?.warn(
      'OTP_GLOBAL_DAILY_SEND_LIMIT unset — defaulting to 10000/day for development. ' +
        'This must be set explicitly in production.',
    );
    return 10_000;
  }

  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(
      `OTP_GLOBAL_DAILY_SEND_LIMIT must be a non-negative integer, got "${raw}".`,
    );
  }
  return parsed;
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
  ) {
    // Read once, at construction. A ceiling re-read per request could change
    // mid-window and make the counter meaningless; and reading it here means a
    // production boot with the variable unset fails at STARTUP rather than at
    // the first sign-in, which is the same discipline TRUST_PROXY_HOPS uses.
    this.globalDailyLimit = globalSendLimitFrom(process.env, this.logger);
  }

  private readonly logger = new Logger(OtpService.name);
  private readonly globalDailyLimit: number;

  /**
   * Issue a code and return an OPAQUE CHALLENGE ID.
   *
   * 32 random bytes. NOT derived from the phone, the purpose or the clock —
   * an id with structure is an id somebody can reverse. It is a lookup handle
   * and carries no information.
   *
   * **NOTHING IS LOOKED UP HERE.** No account query, no branch, no difference
   * between a registered number and one that has never been seen. That is how
   * AUTH-3 closes: not by making two answers indistinguishable, but by never
   * asking the question. There is no decoy to maintain and no timing to
   * equalise, because there is only one path.
   *
   * Every limiter fires BEFORE the code is generated or delivered, so a
   * refused request costs zero messages.
   */
  async issue(input: IssueInput): Promise<string> {
    // The wallet fuse first. It is the cheapest check and the one whose
    // exhaustion means "stop spending", so nothing below it should run.
    const globalOk = await this.limiter.hit(
      GLOBAL_SEND_KEY,
      this.globalDailyLimit,
      GLOBAL_SEND_WINDOW_SECONDS,
    );
    if (!globalOk) {
      // LOUD AND DISTINCT. A fuse that trips quietly is an outage nobody
      // attributes: sign-in simply stops working and the logs look normal.
      this.logger.error(
        `[OTP GLOBAL SEND CEILING REACHED] ${this.globalDailyLimit} deliveries in ` +
          `${GLOBAL_SEND_WINDOW_SECONDS / 3600}h. No further codes will be sent until ` +
          `the window rolls. Raise OTP_GLOBAL_DAILY_SEND_LIMIT or investigate abuse.`,
      );
      throw this.sendingUnavailable();
    }

    // Per-phone: protects the human being messaged, and holds even when the
    // attacker rotates IPs.
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
    const challengeId = randomBytes(32).toString('base64url');

    // ONE LIVE CODE PER NUMBER. Retire whatever was outstanding, or a resend
    // would leave the old code working alongside the new one and asking for a
    // fresh code would widen the window rather than replace it.
    const liveScope = liveKeyForPhone(input.phone, input.purpose);
    const previous = await this.store.getLive(liveScope);
    if (previous !== null) await this.store.consume(previous);

    await this.store.put(challengeId, {
      phone: input.phone,
      codeHash: hash(code),
      purpose: input.purpose,
      attempts: 0,
      expiresAtMs: this.now() + OTP_TTL_SECONDS * 1000,
      verifiedAt: null,
    });

    await this.store.setLive(liveScope, challengeId, OTP_TTL_SECONDS);
    await this.delivery.send({ phone: input.phone, code, purpose: input.purpose });
    return challengeId;
  }

  /**
   * Answer a challenge. Resolves to the number it was sent to; throws with a
   * machine-readable code otherwise.
   *
   * Does NOT delete the challenge — it marks it verified and re-stamps the
   * TTL, so a diner with no account yet can supply a name against a number
   * they have already proved. Answering twice is refused, so the pair is
   * single-use even though verification alone does not spend it.
   *
   * An unknown id, a consumed one, an already-verified one and an expired one
   * whose key the store has dropped all answer identically.
   */
  async verify(input: VerifyInput): Promise<VerifiedChallenge> {
    const challenge = await this.store.get(input.challengeId);
    if (!challenge) throw this.invalid();

    // Answering a challenge that has already been answered is not a second
    // chance — it is a replay, and it looks exactly like an unknown id.
    if (challenge.verifiedAt !== null) throw this.invalid();

    const lockScope = lockKeyForPhone(challenge.phone, challenge.purpose);

    // Before anything else is judged. A locked number is locked whatever
    // challenge is in flight — including a brand-new one just requested,
    // which is the whole point of the lock outliving the challenge.
    const lockedFor = await this.store.lockedForMs(lockScope);
    if (lockedFor > 0) throw this.tooManyAttempts(Math.ceil(lockedFor / 1000));

    if (challenge.expiresAtMs <= this.now()) {
      await this.store.consume(input.challengeId);
      throw new BadRequestException({
        code: 'otp_expired',
        message: 'That code has expired. Request a new one.',
        message_ar: 'انتهت صلاحية الكود. اطلب كود جديد.',
      });
    }

    // Check the cap BEFORE comparing, so a spent challenge cannot be probed
    // further — otherwise the attacker still learns which guess was right.
    if (challenge.attempts >= MAX_ATTEMPTS) {
      await this.store.lock(lockScope, this.now() + LOCK_SECONDS * 1000);
      throw this.tooManyAttempts(LOCK_SECONDS);
    }

    if (!matches(input.code, challenge.codeHash)) {
      const attempts = await this.store.incrementAttempts(input.challengeId);
      if (attempts >= MAX_ATTEMPTS) {
        // The fifth failure locks the NUMBER, not the challenge. Requesting a
        // new code from here changes nothing until the lock expires.
        await this.store.lock(lockScope, this.now() + LOCK_SECONDS * 1000);
        throw this.tooManyAttempts(LOCK_SECONDS);
      }
      throw this.invalid();
    }

    await this.store.markVerified(
      input.challengeId,
      this.now(),
      this.now() + VERIFIED_TTL_SECONDS * 1000,
    );
    return { phone: challenge.phone, purpose: challenge.purpose };
  }

  /**
   * Read a challenge without judging or spending it.
   *
   * For `resend`, which needs the number the original challenge went to so a
   * caller cannot redirect a resend at a different number. Returns null for
   * anything unknown or spent; challenge ids are 32 random bytes, so a null
   * here tells an attacker nothing they could not have guessed.
   */
  async peek(challengeId: string): Promise<VerifiedChallenge | null> {
    const challenge = await this.store.get(challengeId);
    if (!challenge) return null;
    return { phone: challenge.phone, purpose: challenge.purpose };
  }

  /**
   * Spend a challenge that has already been verified.
   *
   * The second half of the pair. Refuses anything that was not verified, has
   * expired, or has already been spent — all with the same error, so a caller
   * cannot tell which.
   */
  async consumeVerified(challengeId: string): Promise<VerifiedChallenge> {
    const challenge = await this.store.get(challengeId);
    if (!challenge || challenge.verifiedAt === null) throw this.invalid();
    if (challenge.expiresAtMs <= this.now()) {
      await this.store.consume(challengeId);
      throw this.invalid();
    }

    await this.store.consume(challengeId);
    return { phone: challenge.phone, purpose: challenge.purpose };
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

  /**
   * The wallet fuse tripped. FAILS CLOSED, and the choice is deliberate.
   *
   * The alternative was to serve a challenge and quietly not deliver — which
   * is precisely the decoy pattern this design deleted. A diner would be told
   * a code was sent, would wait, would retry, and would eventually contact
   * support about a phone they think is broken. Nobody would learn that the
   * ceiling had been reached except by reading the logs.
   *
   * An honest 503 lets the client say something true, and it makes a tripped
   * fuse look like what it is: an outage with a cause, not an app that stopped
   * working.
   */
  private sendingUnavailable(): HttpException {
    return new HttpException(
      {
        code: 'otp_sending_unavailable',
        message: 'We cannot send codes right now. Please try again later.',
        message_ar: 'مش قادرين نبعت أكواد دلوقتي. حاول تاني بعدين.',
      },
      HttpStatus.SERVICE_UNAVAILABLE,
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

/**
 * What a lockout is scoped to.
 *
 * The PHONE and the PURPOSE, with the phone hashed. No account is resolved at
 * request time any more, so the phone is what identifies the target.
 *
 * Stable across challenges, because an attacker who burns six guesses, asks
 * for a fresh challenge and finds it unlocked has defeated the lock.
 *
 * Purpose is in the key so failing a sign-in five times does not stop the same
 * person completing a registration they hold a valid code for — a separation
 * the previous user-keyed design had, which `otp.service.spec.ts` pins.
 *
 * NOTE FOR STEP 6 (email as a second OTP channel): this scope will have to
 * move to the ACCOUNT at verify time, where the account is known and the
 * responses are already indistinguishable. Left phone-scoped here because
 * there is no second channel yet, and a scope that anticipated one would be
 * untested speculation. Recorded in the decision doc.
 */
function liveKeyForPhone(phone: string, purpose: string): string {
  return `otp:live:${purpose}:${hash(phone)}`;
}

function lockKeyForPhone(phone: string, purpose: string): string {
  return `otp:lock:${purpose}:${hash(phone)}`;
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
