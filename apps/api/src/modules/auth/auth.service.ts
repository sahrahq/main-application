import { Injectable, ConflictException, UnauthorizedException, Logger } from '@nestjs/common';
import * as argon2 from 'argon2';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { TokenService, TokenPair, subjectOf } from './token.service';
import { OtpService } from './otp/otp.service';

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
      select: { id: true, phone: true },
    });
    if (clash) {
      throw new ConflictException({
        code: clash.phone === phone ? 'phone_exists' : 'email_exists',
        message: 'An account with those details already exists.',
        message_ar: 'يوجد حساب بهذه البيانات بالفعل.',
      });
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
   * Runs a dummy verify when the account is missing or has no password, so the
   * response time does not reveal which phone numbers are registered.
   */
  async login(identifier: string, password: string, ctx: RequestCtx = {}): Promise<TokenPair> {
    const asPhone = normalizePhone(identifier);
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ phone: asPhone }, { email: identifier }], deletedAt: null },
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
   * doc 06 §2 — verify the phone and return the first token pair.
   *
   * Activation happens ONLY here: a `pending` account has an unproven phone,
   * and phone is the primary identity in Egypt (doc 02 C-1.2).
   */
  async verifyOtp(userId: string, code: string, ctx: RequestCtx = {}): Promise<TokenPair> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      include: { roles: { include: { role: true } } },
    });
    if (!user) throw this.invalidCredentials();

    await this.otp.verify({ userId, purpose: 'phone_verify', code });

    const activated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        phoneVerifiedAt: new Date(),
        // pending → active. Never downgrade a suspended account by verifying.
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

  async logout(refreshToken: string, allDevices: boolean): Promise<void> {
    if (!allDevices) {
      await this.tokens.revoke(refreshToken);
      return;
    }
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: TokenService.hash(refreshToken) },
      select: { userId: true },
    });
    // Unknown token on an all-devices logout is a no-op, not an error: the
    // caller wanted to be logged out and they are.
    if (record) await this.tokens.revokeAllForUser(record.userId);
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
