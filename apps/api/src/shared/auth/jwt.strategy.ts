import { Injectable, UnauthorizedException } from "@nestjs/common";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { AccessClaims } from "../../modules/auth/token.service";

export interface AuthedUser {
  id: string;
  roles: string[];
  locale: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, "jwt") {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>("JWT_ACCESS_SECRET"),
    });
  }

  /**
   * Re-check the user on every request rather than trusting the token alone.
   * A 15-minute access token issued before a suspension would otherwise keep
   * working until it expired.
   */
  async validate(payload: AccessClaims): Promise<AuthedUser> {
    const user = await this.prisma.user.findFirst({
      where: { id: payload.sub, deletedAt: null },
      select: { id: true, locale: true, status: true },
    });

    if (!user || user.status === "suspended" || user.status === "deleted") {
      throw new UnauthorizedException({
        code: "account_unavailable",
        message: "This account is not available.",
        message_ar: "هذا الحساب غير متاح.",
      });
    }

    return { id: user.id, roles: payload.roles ?? [], locale: user.locale };
  }
}