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

  /**
   * How long after a rotation a replay can still be a retry rather than theft.
   *
   * 60 seconds: longer than any client retry this app performs (Dio's connect
   * and receive timeouts are both well under it) and far shorter than anything
   * an attacker could rely on. The number bounds a NETWORK retry, not a
   * session — pushing it to minutes would start covering genuine theft.
   */
  static readonly REPLAY_GRACE_MS = 60_000;

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
      // A DROPPED RESPONSE IS NOT A STOLEN TOKEN (IDEM-1).
      //
      // Every replay used to be treated as theft: revoke the family, 401. But
      // the commonest replay by far is not an attacker — it is a diner on a
      // Cairo 3G connection whose rotation response never arrived, retrying
      // with the only token they still hold. The punishment for a bad network
      // was being signed out mid-booking with no explanation.
      //
      // The distinguishing fact is whether ANYBODY HOLDS THE REPLACEMENT. If
      // the response was lost, the replacement token was issued and never
      // reached anyone, so it is still live and has never itself been rotated.
      // If a thief is replaying an old token, the legitimate client did get
      // the response and has since used it — which revokes the replacement and
      // sends us down the theft path below, correctly.
      //
      // Bounded by a grace window as well, because "never used" stops being
      // evidence of a lost response after a minute: a token that has sat
      // unused for an hour and then gets replayed is not a retry.
      const replacement =
        existing.replacedBy === null
          ? null
          : await this.prisma.refreshToken.findUnique({
              where: { id: existing.replacedBy },
              include: { user: { include: { roles: { include: { role: true } } } } },
            });

      const withinGrace =
        Date.now() - existing.revokedAt.getTime() <= TokenService.REPLAY_GRACE_MS;

      // AND IT HAS TO BE THE SAME CLIENT.
      //
      // Grace on time alone is too generous, and the existing theft test says
      // so: a thief replaying inside the window, before the victim has used
      // their new token, is indistinguishable from a lost response. That test
      // going red was the finding — the first cut of this grace window would
      // have quietly disarmed reuse detection for 60 seconds.
      //
      // So grace requires POSITIVE EVIDENCE that the caller is the client the
      // token was issued to: same IP, same user agent. Absence of evidence
      // does not qualify — a null IP on either side means no grace, because a
      // rule that treats "we know nothing" as "we know it is fine" is not a
      // check.
      //
      // A thief on the same NAT with a spoofed user agent still gets through.
      // That is a narrower hole than the one it replaces, and closing it fully
      // would need device binding (doc 09 §1.1, not built).
      const sameClient =
        existing.ip !== null &&
        ctx.ip !== undefined &&
        existing.ip === ctx.ip &&
        existing.userAgent === (ctx.userAgent ?? null);

      if (withinGrace && sameClient && replacement && replacement.revokedAt === null) {
        this.logger.log(
          `Refresh replay within grace for user ${existing.userId} ` +
            `(family ${existing.familyId}) — treating as a retried rotation, ` +
            `not reuse.`,
        );

        // Retire the replacement nobody received, and issue in its place. The
        // family survives; the diner stays signed in.
        const claimedReplacement = await this.prisma.refreshToken.updateMany({
          where: { id: replacement.id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        // Lost the race to a concurrent retry: somebody else is completing the
        // same rotation. Fall through to the theft path rather than issue a
        // second live token — two winners is the one outcome worse than a 401.
        if (claimedReplacement.count === 1) {
          return this.issueAndLink(existing, replacement.id, ctx);
        }
      }

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

    return this.issueAndLink(existing, existing.id, ctx);
  }

  /**
   * Issue a pair in [previous]'s family and record what replaced what.
   *
   * [linkFrom] is the row whose `replaced_by` gets the new token's id. On an
   * ordinary rotation that is the presented token itself; on a grace-window
   * replay it is the replacement being retired, so the audit chain stays a
   * chain rather than forking — two rows pointing at different successors is
   * how a reuse investigation later becomes unreadable.
   */
  private async issueAndLink(
    previous: {
      id: string;
      familyId: string;
      user: TokenSubject & { roles: { role: { name: string } }[] };
    },
    linkFrom: string,
    ctx: { userAgent?: string; ip?: string },
  ): Promise<TokenPair> {
    const roles = previous.user.roles.map((r) => r.role.name);
    const pair = await this.issuePair(
      subjectOf(previous.user),
      roles,
      ctx,
      previous.familyId, // stay in the same family
    );

    const issued = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: TokenService.hash(pair.refreshToken) },
      select: { id: true },
    });
    if (issued) {
      await this.prisma.refreshToken.update({
        where: { id: linkFrom },
        data: { replacedBy: issued.id },
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
