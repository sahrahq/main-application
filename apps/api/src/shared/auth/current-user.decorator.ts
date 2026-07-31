import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import { AuthedUser } from "./jwt.strategy";

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthedUser =>
    ctx.switchToHttp().getRequest().user as AuthedUser,
);