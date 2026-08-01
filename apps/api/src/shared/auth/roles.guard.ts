import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { ROLES_KEY } from "./roles.decorator";
import type { AuthedUser } from "./jwt.strategy";

/**
 * Role gate for /admin (doc 06 section 5).
 *
 * Fails CLOSED: a route annotated with @Roles but reached without an
 * authenticated user is rejected, rather than treated as "no roles required".
 * A missing JwtAuthGuard should break the request, not open the door.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[] | undefined>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const user = ctx.switchToHttp().getRequest().user as AuthedUser | undefined;
    if (!user?.roles?.some((r) => required.includes(r))) {
      throw new ForbiddenException({
        code: "forbidden_role",
        message: "You do not have permission to do that.",
        message_ar: "ليس لديك صلاحية للقيام بذلك.",
      });
    }
    return true;
  }
}