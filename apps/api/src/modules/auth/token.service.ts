import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { randomBytes, createHash, randomUUID } from 'crypto';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * doc 06 §2 shows the login response carrying the user alongside the tokens:
 *
 *   { "access_token", "expires_in", "refresh_token",
 *     "user": { "id", "full_name", "locale", "roles" } }
 *
 * It did not, and `TokenPairResponse` declared `user` required — so the
 * generated Dart client would have thrown a null cast on every sign-in. Found
 * by annotating controller return types, which put `tsc` on the same contract
 * the OpenAPI decorators advertise. See the note in reservations.controller.ts.
 */
export interface TokenUser {
  id: string;
  phone: string;
  email: string | null;
  fullName: string;
  locale: string;
  status: string;
  roles: string[];
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: TokenUser;
}

/** Everything `issuePair` needs to build both the claims and the user block. */
export interface TokenSubject {
  id: string;
  phone: string;
  email: string | null;
  fullName: string;
  locale: string;
  status: string;
}

/**
 * Narrow a Prisma `User` row to what `issuePair` needs.
 *
 * A function rather than an inline literal at each call site, because the
 * three of them drifting is exactly how `user` went missing from the response
 * in the first place.
 */
export function subjectOf(u: {
  id: string;
  phone: string;
  email: string | null;
  fullName: string;
  locale: string;
  status: string;
}): TokenSubject {
  return {
    id: u.id,
    phone: u.phone,
    email: u.email,
    fullName: u.fullName,
    locale: u.locale,
    status: u.status,
  };
}

export interface AccessClaims {
  sub: string;
  roles: string[];
  locale: string;
}

/** doc 09 §1.1 — access 15 min, refresh 30 d. */
const ACCESS_TTL_SECONDS = 15 * 60;
const REFRESH_TTL_DAYS = 30;

/**
 * Refresh tokens are opaque random strings, NOT JWTs.
 *
 * A JWT refresh token would carry its own claims and be verifiable without a
 * database lookup — which sounds efficient until you need to revoke one. The
 * whole point here is server-side revocation, so the lookup is the feature,
 * not the cost.
 */
@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  /** SHA-256 hex. Only the digest is ever persisted. */
  static hash(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }

  private static newOpaqueToken(): string {
    // 48 bytes ≈ 384 bits of entropy — far beyond guessing range.
    return randomBytes(48).toString('base64url');
  }

  async issuePair(
    user: TokenSubject,
    roles: string[],
    ctx: { userAgent?: string; ip?: string } = {},
    familyId?: string,
  ): Promise<TokenPair> {
    const claims: AccessClaims = { sub: user.id, roles, locale: user.locale };
    const accessToken = await this.jwt.signAsync(claims, {
      secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      expiresIn: ACCESS_TTL_SECONDS,
    });

    const raw = TokenService.newOpaqueToken();
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        familyId: familyId ?? randomUUID(),
        tokenHash: TokenService.hash(raw),
        expiresAt: new Date(Date.now() + REFRESH_TTL_DAYS * 86_400_000),
        userAgent: ctx.userAgent ?? null,
        ip: ctx.ip ?? null,
      },
    });

    return {
      accessToken,
      refreshToken: raw,
      expiresIn: ACCESS_TTL_SECONDS,
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        fullName: user.fullName,
        locale: user.locale,
        status: user.status,
        roles,
      },
    };
  }

  /**
   * Rotate a refresh token (doc 06 §2, doc 09 §1.1).
   *
   * Presenting an already-revoked token means a copy is in circulation — the
   * legitimate client and a thief cannot both hold a live token after a
   * rotation. We cannot tell which one is asking, so we end the whole family:
   * the victim re-authenticates, the attacker gets nothing.
   *
   * Race safety: the revoke is an UPDATE guarded on `revokedAt IS NULL`, so of
   * two concurrent refreshes with the same token exactly one claims it. The
   * loser is indistinguishable from replay and is treated as such — that is
   * the safe direction to be wrong.
   */
  async rotate(rawToken: string, ctx: { userAgent?: string; ip?: string } = {}): Promise<TokenPair> {
    const tokenHash = TokenService.hash(rawToken);

    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: { include: { roles: { include: { role: true } } } } },
    });

    if (!existing) throw this.unauthorized('invalid_refresh_token');

    if (existing.revokedAt) {
      this.logger.warn(
        `Refresh token reuse detected for user ${existing.userId} ` +
          `(family ${existing.familyId}) — revoking family.`,
      );
      await this.revokeFamily(existing.familyId);
      throw this.unauthorized('token_reuse_detected');
    }

    if (existing.expiresAt.getTime() <= Date.now()) {
      throw this.unauthorized('refresh_token_expired');
    }

    // Atomically claim this token. Only one caller can win.
    const claimed = await this.prisma.refreshToken.updateMany({
      where: { id: existing.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (claimed.count === 0) {
      await this.revokeFamily(existing.familyId);
      throw this.unauthorized('token_reuse_detected');
    }

    const roles = existing.user.roles.map((r) => r.role.name);
    const pair = await this.issuePair(
      subjectOf(existing.user),
      roles,
      ctx,
      existing.familyId, // stay in the same family
    );

    // Audit trail: which token replaced which.
    const replacement = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: TokenService.hash(pair.refreshToken) },
      select: { id: true },
    });
    if (replacement) {
      await this.prisma.refreshToken.update({
        where: { id: existing.id },
        data: { replacedBy: replacement.id },
      });
    }

    return pair;
  }

  /** Revoke one token (logout). Idempotent. */
  async revoke(rawToken: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: TokenService.hash(rawToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** Revoke every live token for a family — the reuse-detection response. */
  async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** "Log out all devices" (doc 09 §1.1). */
  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private unauthorized(code: string): UnauthorizedException {
    // Deliberately uniform message: never reveal WHY a token failed, or an
    // attacker learns whether a token ever existed.
    return new UnauthorizedException({
      code,
      message: 'Your session has expired. Please sign in again.',
      message_ar: 'انتهت جلستك. سجّل الدخول من جديد.',
    });
  }
}
