import { Injectable, ConflictException, UnauthorizedException, Logger } from '@nestjs/common';
import * as argon2 from 'argon2';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { TokenService, TokenPair, subjectOf } from './token.service';
import { OtpService } from './otp/otp.service';
import { DevicesService } from '../notifications/devices.service';
import type { OtpPurpose } from './otp/otp.ports';

/**
 * argon2id — doc 09 §1.1. Parameters follow OWASP's 2024 guidance
 * (19 MiB, t=2, p=1), which is the memory-hard configuration that makes
 * GPU cracking uneconomic.
 */
const ARGON2_OPTS: argon2.Options = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
};

export interface RegisterInput {
  phone: string;
  fullName: string;
  email?: string | null;
  password?: string | null;
  locale?: 'ar' | 'en';
}

/**
 * What answering a challenge produced.
 *
 * A DISCRIMINATED result, because "the code was right" and "you are signed in"
 * stopped being the same fact when name collection moved after verification.
 * `status` is required and non-nullable in the wire DTO so a missing field is
 * a parse error rather than a silent "not signed in".
 */
export type VerifyOutcome =
  | { status: 'signed_in'; tokens: TokenPair }
  | { status: 'profile_needed' };

export interface RequestCtx {
  userAgent?: string;
  ip?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly otp: OtpService,
    private readonly devices: DevicesService,
  ) {}

  /**
   * Register (doc 06 §2). Returns `otp_required: true` — the account is not
   * usable until the phone is verified, which is the Redis-backed OTP step
   * (doc 09 §1.1) landing once Redis is available.
   */
  async register(input: RegisterInput, ctx: RequestCtx = {}): Promise<{ userId: string; otpRequired: true; challengeId: string }> {
    const phone = normalizePhone(input.phone);

    const clash = await this.prisma.user.findFirst({
      where: { OR: [{ phone }, ...(input.email ? [{ email: input.email }] : [])] },
      select: { id: true, phone: true, phoneVerifiedAt: true, status: true },
    });

    // ── ACCOUNT SQUATTING ────────────────────────────────────────────────
    //
    // A registration that was never verified holds nothing. Anyone could type
    // a stranger's number, never answer the code, and leave a `pending` row
    // that made the real owner's signup answer 409 `phone_exists`.
    //
    // That is not primarily a security problem, it is a SILENT CUSTOMER LOSS:
    // a real diner is told their own phone number is taken, and leaves. They
    // do not contact support, so it never appears anywhere we look — which
    // makes it worse than an attack we could at least observe.
    //
    // Whoever is holding the phone is overwhelmingly likely to be its owner,
    // and they still have to answer a code sent to it. So an unverified
    // registration is REPLACED rather than refused.
    //
    // WHAT THIS MUST NOT DO:
    //   - take over a VERIFIED account. `phoneVerifiedAt` is the line, and it
    //     is checked in addition to status, because either alone is one bug
    //     away from being the wrong question.
    //   - reveal whether a number is registered. The response below is
    //     byte-identical in shape and status to a first-time registration
    //     (201 `{userId, otpRequired: true}`), so a caller cannot tell the two
    //     apart — otherwise this becomes the enumeration oracle avoided
    //     everywhere else.
    const reclaimable =
      clash !== null &&
      clash.phone === phone &&
      clash.phoneVerifiedAt === null &&
      clash.status === 'pending';

    if (clash && !reclaimable) {
      throw new ConflictException({
        code: clash.phone === phone ? 'phone_exists' : 'email_exists',
        message: 'An account with those details already exists.',
        message_ar: 'يوجد حساب بهذه البيانات بالفعل.',
      });
    }

    if (reclaimable) {
      // The new registrant's details win: the row being replaced was never
      // proven to belong to anyone, and a squatter must not get to fix a
      // stranger's name in our database.
      const reclaimed = await this.prisma.user.update({
        where: { id: clash!.id },
        data: {
          fullName: input.fullName,
          email: input.email ?? null,
          locale: input.locale ?? 'ar',
          passwordHash: input.password ? await argon2.hash(input.password, ARGON2_OPTS) : null,
        },
        select: { id: true },
      });

      // The HANDLE comes back with the id. An endpoint that issues a challenge
      // and does not return its handle cannot be answered — which is what
      // `register` became when challenges stopped being addressable by user.
      const reclaimedChallenge = await this.otp
        .issue({ phone, purpose: 'phone_verify', ip: ctx.ip })
        .catch((e) => {
          this.logger.error(`OTP send failed for ${reclaimed.id}: ${String(e)}`);
          throw e;
        });

      return { userId: reclaimed.id, otpRequired: true, challengeId: reclaimedChallenge };
    }

    const user = await this.prisma.user.create({
      data: {
        phone,
        email: input.email ?? null,
        fullName: input.fullName,
        locale: input.locale ?? 'ar',
        // status stays `pending` until the phone is verified.
        passwordHash: input.password ? await argon2.hash(input.password, ARGON2_OPTS) : null,
        roles: {
          create: {
            role: {
              connectOrCreate: { where: { name: 'customer' }, create: { name: 'customer' } },
            },
          },
        },
      },
      select: { id: true },
    });

    // Fire the verification code.
    //
    // A SEND FAILURE IS NOW FATAL TO THE REQUEST, and that reversed
    // deliberately. The old comment here said "a send failure must not orphan
    // the account: the user exists and can request a new code, so this is
    // logged, not fatal" — which was reasonable when the response carried only
    // a user id. It is not reasonable now: the response carries the HANDLE to
    // the challenge, and a handle with no code behind it can never be
    // answered. Returning 201 with one would be a success that does nothing.
    //
    // Same trade as the wallet fuse failing closed. The orphaned pending row is
    // swept after 24h (`pending-registration.sweeper.ts`) and is reclaimable in
    // the meantime, so the cost of being honest here is bounded.
    const challengeId = await this.otp
      .issue({ phone, purpose: 'phone_verify', ip: ctx.ip })
      .catch((e) => {
        this.logger.error(`OTP send failed for ${user.id}: ${String(e)}`);
        throw e;
      });

    return { userId: user.id, otpRequired: true, challengeId };
  }

  /**
   * Password login (doc 06 §2). Phone-only login goes through OTP instead and
   * lands with Redis.
   *
   * ───────────────────────────────────────────────────────────────────────
   * **`users.email` IS A CONTACT FIELD, NOT A CREDENTIAL.** It identifies
   * nobody and grants access to nothing.
   * ───────────────────────────────────────────────────────────────────────
   *
   * This lookup used to be `OR: [{ phone }, { email: identifier }]`, so an
   * address on a record that also carried a `passwordHash` was a second way
   * in. Diners were safe only because the customer app happens to send no
   * password at registration — a property of one client, not a boundary. The
   * moment an optional contact email is collected (see
   * `docs/decisions/2026-08-02-optional-email-at-signup.md`) that accident
   * stops holding.
   *
   * Removed rather than narrowed. The alternative was to keep the branch for
   * "accounts where email authentication is intended", but no such concept
   * exists in this system and inventing one to guard a hole is a second thing
   * to get wrong. Owners and staff log in by phone, which is what they already
   * do — nothing in this repository has ever logged in by email.
   *
   * When Google or Apple sign-in arrives, it must key off `emailVerifiedAt`
   * and never off this column.
   *
   * Runs a dummy verify when the account is missing or has no password, so the
   * response time does not reveal which phone numbers are registered.
   */
  async login(identifier: string, password: string, ctx: RequestCtx = {}): Promise<TokenPair> {
    const asPhone = normalizePhone(identifier);
    const user = await this.prisma.user.findFirst({
      where: { phone: asPhone, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });

    if (!user?.passwordHash) {
      await argon2.hash(password, ARGON2_OPTS).catch(() => undefined);
      throw this.invalidCredentials();
    }

    if (!(await argon2.verify(user.passwordHash, password))) {
      throw this.invalidCredentials();
    }

    if (user.status === 'suspended' || user.status === 'deleted') {
      throw new UnauthorizedException({
        code: 'account_unavailable',
        message: 'This account is not available.',
        message_ar: 'هذا الحساب غير متاح.',
      });
    }

    return this.tokens.issuePair(
      subjectOf(user),
      user.roles.map((r) => r.role.name),
      ctx,
    );
  }

  /**
   * doc 06 §2 — send a sign-in code to a phone that already has an account.
   *
   * THE FLOW THAT WAS MISSING (C-1.2, P0). Phone is the primary identity in
   * Egypt, and until now a diner who registered by phone could never sign in
   * again: `register` answered 409 `phone_exists`, and `login` demanded a
   * password they had never set. Not an edge case — the main path.
   *
   * `purpose: 'login'`, so the challenge is keyed `otp:login:{userId}` and is
   * a DIFFERENT challenge from registration's. A code issued to activate an
   * account cannot sign one in, and vice versa.
   *
   * Returns the same `{userId, otpRequired}` shape `register` returns, because
   * it feeds the same next call. An unknown phone is 401 `invalid_credentials`
   * per doc 06 §2's error column — which does reveal whether a number has an
   * account, and is not a leak this endpoint introduces: `register` already
   * answers 409 `phone_exists` for the same question. Recorded as an open
   * finding rather than fixed unilaterally at one of the two doors.
   */
  async requestOtp(phone: string, ctx: RequestCtx = {}): Promise<{ challengeId: string }> {
    // NO LOOKUP. Not of the account, not of its status, not of anything.
    //
    // This is the whole of AUTH-3's closure. The previous version answered 200
    // for a registered number and 401 for an unknown one, on an input space
    // (Egyptian mobile numbers) that is trivially enumerable — and it was the
    // endpoint the client used as "resend" for a returning diner, so the
    // commonest path was the leaky one.
    //
    // The fix is not to make two answers indistinguishable — that is a decoy,
    // and a decoy is a lie somebody has to maintain perfectly through every
    // future branch. The fix is to have one path. Whether an account exists
    // is decided at VERIFY time, after the caller has proved they can read a
    // message sent to the number.
    //
    // The cost, accepted deliberately: anyone can cause an SMS to any number.
    // Three limiters stand in the way — per phone, per IP, and the global
    // daily ceiling that exists because the first two cap harassment and
    // spraying but not the bill.
    return { challengeId: await this.otp.issue({ phone: normalizePhone(phone), purpose: 'login', ip: ctx.ip }) };
  }

  /**
   * doc 06 §2 — answer a challenge and return a token pair.
   *
   * Activation happens here: a `pending` account has an unproven phone, and
   * phone is the primary identity in Egypt (doc 02 C-1.2). It happens for
   * EITHER purpose, because answering a code sent to a number proves control
   * of that number whichever door it came through.
   */
  async verifyOtp(
    challengeId: string,
    code: string,
    ctx: RequestCtx = {},
  ): Promise<VerifyOutcome> {
    // The code first. Only after it is right does anything about an account
    // get looked up — which is why request time can afford to know nothing.
    const { phone } = await this.otp.verify({ challengeId, code });

    const user = await this.prisma.user.findFirst({
      where: { phone, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });

    // NO ACCOUNT: verified, but there is nobody to sign in yet. The challenge
    // stays verified-and-unspent so a name can be supplied against it.
    if (!user) return { status: 'profile_needed' };

    await this.otp.consumeVerified(challengeId);

    // AFTER the code, not before. Answering with the right code and then being
    // told the account is unavailable reveals suspension only to somebody who
    // can read messages sent to that number — which is the person entitled to
    // know. The previous order told anyone who could type the number.
    this.assertUsable(user.status);

    const activated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        phoneVerifiedAt: new Date(),
        // pending → active. Never upgrade anything else.
        status: user.status === 'pending' ? 'active' : user.status,
      },
      select: { id: true, phone: true, email: true, fullName: true, locale: true, status: true },
    });

    return {
      status: 'signed_in',
      tokens: await this.tokens.issuePair(
        subjectOf(activated),
        user.roles.map((r) => r.role.name),
        ctx,
      ),
    };
  }

  /**
   * Create the account for a challenge that has already been verified.
   *
   * ONLY REACHABLE WITH A VERIFIED CHALLENGE. There is no phone parameter —
   * the number comes from the challenge, so this cannot be called against an
   * arbitrary number, and it cannot be called at all without having answered a
   * code sent to that number.
   *
   * ACCOUNT SQUATTING IS STRUCTURALLY IMPOSSIBLE HERE, rather than defended
   * against: you cannot create a row for a number you have not proved you can
   * read. `register`'s reclaim path still guards the old door — see the note
   * on it — but nothing the app does can reach the situation it fixes.
   */
  async completeRegistration(
    input: { challengeId: string; fullName: string; email?: string | null; locale?: 'ar' | 'en' },
    ctx: RequestCtx = {},
  ): Promise<TokenPair> {
    const { phone } = await this.otp.consumeVerified(input.challengeId);

    // Between verifying and completing, someone could have registered this
    // number by the other door. Adopt the row rather than colliding: they
    // proved control of the number, which is the only thing that row is
    // evidence of.
    const existing = await this.prisma.user.findFirst({
      where: { phone, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });

    if (existing) {
      this.assertUsable(existing.status);
      const activated = await this.prisma.user.update({
        where: { id: existing.id },
        data: {
          phoneVerifiedAt: new Date(),
          status: existing.status === 'pending' ? 'active' : existing.status,
        },
        select: { id: true, phone: true, email: true, fullName: true, locale: true, status: true },
      });
      return this.tokens.issuePair(
        subjectOf(activated),
        existing.roles.map((r) => r.role.name),
        ctx,
      );
    }

    const user = await this.prisma.user.create({
      data: {
        phone,
        fullName: input.fullName,
        email: input.email ?? null,
        locale: input.locale ?? 'ar',
        // Verified at creation: the code proved the number before this row
        // existed, which is the inversion that makes squatting impossible.
        phoneVerifiedAt: new Date(),
        status: 'active',
        roles: {
          create: {
            role: {
              connectOrCreate: { where: { name: 'customer' }, create: { name: 'customer' } },
            },
          },
        },
      },
      select: { id: true, phone: true, email: true, fullName: true, locale: true, status: true },
    });

    return this.tokens.issuePair(subjectOf(user), ['customer'], ctx);
  }

  /** Suspended and deleted accounts get tokens from no door. */
  private assertUsable(status: string): void {
    if (status === 'suspended' || status === 'deleted') {
      throw new UnauthorizedException({
        code: 'account_unavailable',
        message: 'This account is not available. Please contact support.',
        message_ar: 'الحساب ده مش متاح. كلّم الدعم.',
      });
    }
  }

  /**
   * The caller's own profile — `GET /auth/me` (doc 06 §3 `/me`).
   *
   * Read from the database rather than from the access token. The JWT carries
   * only what AUTHORISATION needs (`sub`, `roles`, `locale`, doc 09 §1.1);
   * widening it to hold a display name would put stale profile data in a
   * credential that lives for fifteen minutes and cannot be revoked early.
   */
  async profile(userId: string): Promise<{
    id: string;
    phone: string;
    email: string | null;
    fullName: string;
    locale: string;
    status: string;
    roles: string[];
  }> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });
    if (!user) {
      throw new UnauthorizedException({
        code: 'unauthenticated',
        message: 'Your session has expired. Please sign in again.',
        message_ar: 'انتهت جلستك. سجّل الدخول من جديد.',
      });
    }
    return {
      id: user.id,
      phone: user.phone,
      email: user.email,
      fullName: user.fullName,
      locale: user.locale,
      status: user.status,
      roles: user.roles.map((r) => r.role.name),
    };
  }

  /**
   * `PATCH /auth/me` — the diner corrects their own name, or switches language.
   *
   * THE SUBJECT IS THE TOKEN. There is no id in the route and none in the
   * body, so there is no parameter for anyone to tamper with and no ownership
   * check to forget — the strongest available shape for a self-service write,
   * and the reason this is not `PATCH /users/:id`.
   *
   * `deletedAt: null` in the WHERE, so a soft-deleted account cannot be edited
   * back into use by a token issued before the deletion.
   *
   * Email is NOT settable here. See `UpdateProfileDto` for why, and for what
   * step 3 has to land before it can be.
   */
  async updateProfile(
    userId: string,
    patch: { fullName?: string; locale?: 'ar' | 'en' },
  ): Promise<{
    id: string;
    phone: string;
    email: string | null;
    fullName: string;
    locale: string;
    status: string;
    roles: string[];
  }> {
    const changed = await this.prisma.user.updateMany({
      where: { id: userId, deletedAt: null },
      data: {
        // Only what was named. `undefined` is Prisma's "leave it alone";
        // spreading a `null` here would blank a name on a locale change.
        ...(patch.fullName === undefined ? {} : { fullName: patch.fullName.trim() }),
        ...(patch.locale === undefined ? {} : { locale: patch.locale }),
      },
    });

    if (changed.count === 0) {
      throw new UnauthorizedException({
        code: 'unauthenticated',
        message: 'Your session has expired. Please sign in again.',
        message_ar: 'انتهت جلستك. سجّل الدخول من جديد.',
      });
    }

    // Re-read rather than compose a response from the patch: the row is the
    // truth, and returning what we were sent would hide a write that silently
    // did not happen.
    return this.profile(userId);
  }

  /** Re-send a phone-verification code. Rate limits live in OtpService. */
  async resendOtp(challengeId: string, ctx: RequestCtx = {}): Promise<{ challengeId: string }> {
    // Re-issues against the number the ORIGINAL challenge was sent to, so a
    // resend needs no phone from the caller and cannot be pointed at a
    // different number. An unknown or spent id gets a fresh challenge for
    // nothing, which is indistinguishable from a real resend and costs the
    // caller a send from their own budget.
    const previous = await this.otp.peek(challengeId);
    const phone = previous?.phone ?? null;
    if (phone === null) throw this.invalidCredentials();

    return {
      challengeId: await this.otp.issue({
        phone,
        purpose: previous!.purpose,
        ip: ctx.ip,
      }),
    };
  }

  async refresh(refreshToken: string, ctx: RequestCtx = {}): Promise<TokenPair> {
    return this.tokens.rotate(refreshToken, ctx);
  }

  async logout(
    refreshToken: string,
    allDevices: boolean,
    deviceToken?: string,
  ): Promise<void> {
    // Resolve the user FIRST, whichever branch runs. Revoking a push token
    // needs an owner: without one, anybody who guessed a token could silence
    // a diner's cancellation notices.
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: TokenService.hash(refreshToken) },
      select: { userId: true },
    });

    if (!allDevices) {
      await this.tokens.revoke(refreshToken);
      // The push half of signing out. A token left live sends this person's
      // reservations to whoever holds the handset next.
      if (record && deviceToken) await this.devices.revoke(record.userId, deviceToken);
      return;
    }

    // Unknown token on an all-devices logout is a no-op, not an error: the
    // caller wanted to be logged out and they are.
    if (record) {
      await this.tokens.revokeAllForUser(record.userId);
      // "Log out all devices" has to mean all devices, not just all sessions.
      // Leaving the push tokens live would keep notifying handsets the diner
      // has explicitly disowned — which is the exact case somebody uses this
      // button for.
      await this.devices.revokeAllForUser(record.userId);
    }
  }

  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException({
      code: 'invalid_credentials',
      message: 'Those details are incorrect.',
      message_ar: 'البيانات دي مش صحيحة.',
    });
  }
}

/**
 * Egypt-first E.164 normalization. Phone is the primary identity here
 * (doc 02 C-1.2), so `01000000000`, `+201000000000` and `00201000000000`
 * must all resolve to one account rather than three.
 */
export function normalizePhone(raw: string): string {
  const digits = raw.replace(/[^\d+]/g, '');
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('00')) return `+${digits.slice(2)}`;
  if (digits.startsWith('0')) return `+20${digits.slice(1)}`; // local Egyptian
  if (digits.startsWith('20')) return `+${digits}`;
  return `+${digits}`;
}
