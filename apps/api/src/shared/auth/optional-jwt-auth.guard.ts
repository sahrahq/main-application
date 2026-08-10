import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { AuthedUser } from './jwt.strategy';

/**
 * Populate `req.user` when a token is present; allow the request through when
 * it is not.
 *
 * FOR ENDPOINTS THAT SERVE BOTH A GUEST AND A SIGNED-IN DINER — which, for
 * now, is booking. doc 02 C-1.6 says browsing is open and an account is
 * required to book; the second half is a product decision that has not been
 * enforced yet, and enforcing it here would break guest booking in the shipped
 * customer app. This guard is the honest middle: it does not gate anything, it
 * just stops the API throwing away the identity of a caller who HAS one.
 *
 * THE BUG IT FIXES. `ReservationsService.createHold` has always accepted and
 * stored a `userId`, and `confirmHold` has always checked it. The CONTROLLER
 * never passed one — so every reservation ever created through the HTTP API
 * has `user_id = NULL`, and a diner's own booking would never appear in
 * `GET /reservations`. The service supported it; the layer above forgot to
 * ask. Found by an end-to-end journey test, because every unit around it
 * passed.
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  /**
   * Never throw. A missing, malformed or expired token means "no user", not
   * "reject" — the endpoint is legitimately open.
   */
  handleRequest<TUser = AuthedUser>(_err: unknown, user: TUser): TUser {
    return (user || undefined) as TUser;
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Always true. `super.canActivate` runs the strategy — which is what
    // populates `req.user` — and any failure inside it is swallowed, because
    // for this endpoint "no valid token" is an ordinary state rather than a
    // refusal.
    try {
      await super.canActivate(context);
    } catch {
      // Deliberately empty: see above.
    }
    return true;
  }
}
