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
  async register(input: RegisterInput, ctx: RequestCtx = {}): Promise<{ userId: string; otpRequired: true }> {
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

      await this.otp
        .issue({ userId: reclaimed.id, phone, purpose: 'phone_verify', ip: ctx.ip })
        .catch((e) => this.logger.error(`OTP send failed for ${reclaimed.id}: ${String(e)}`));

      return { userId: reclaimed.id, otpRequired: true };
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

    // Fire the verification code. A send failure must not orphan the account:
    // the user exists and can request a new code, so this is logged, not fatal.
    await this.otp
      .issue({ userId: user.id, phone, purpose: 'phone_verify', ip: ctx.ip })
      .catch((e) => this.logger.error(`OTP send failed for ${user.id}: ${String(e)}`));

    return { userId: user.id, otpRequired: true };
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
  async requestLoginOtp(
    phone: string,
    ctx: RequestCtx = {},
  ): Promise<{ userId: string; otpRequired: boolean }> {
    const normalized = normalizePhone(phone);
    const user = await this.prisma.user.findFirst({
      where: { phone: normalized, deletedAt: null },
      select: { id: true, phone: true, status: true },
    });

    if (!user) throw this.invalidCredentials();
    this.assertUsable(user.status);

    await this.otp.issue({
      userId: user.id,
      phone: user.phone,
      purpose: 'login',
      ip: ctx.ip,
    });

    return { userId: user.id, otpRequired: true };
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
    userId: string,
    code: string,
    ctx: RequestCtx = {},
    purpose: OtpPurpose = 'phone_verify',
  ): Promise<TokenPair> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });
    if (!user) throw this.invalidCredentials();

    // BEFORE the code is checked, and this was missing.
    //
    // A suspended account with a live challenge could answer it and receive a
    // full token pair: the status was preserved by the update below but never
    // acted on. Password login has always refused a suspended account; this
    // door did not, which made suspension bypassable by anyone who could
    // request a code. Found while enumerating what protects the OTP flow.
    this.assertUsable(user.status);

    await this.otp.verify({ userId, purpose, code });

    const activated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        phoneVerifiedAt: new Date(),
        // pending → active. Never upgrade anything else.
        status: user.status === 'pending' ? 'active' : user.status,
      },
      select: { id: true, phone: true, email: true, fullName: true, locale: true, status: true },
    });

    return this.tokens.issuePair(
      subjectOf(activated),
      user.roles.map((r) => r.role.name),
      ctx,
    );
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

  /** Re-send a phone-verification code. Rate limits live in OtpService. */
  async resendOtp(userId: string, ctx: RequestCtx = {}): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { id: true, phone: true },
    });
    // Do not reveal whether the id exists.
    if (!user) return;
    await this.otp.issue({ userId: user.id, phone: user.phone, purpose: 'phone_verify', ip: ctx.ip });
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
