import type { PrismaService } from '../../src/shared/prisma/prisma.service';
import { NotificationsService } from '../../src/modules/notifications/notifications.service';
import { LoggingPushDelivery } from '../../src/modules/notifications/delivery/logging-push.delivery';
import { pushReadiness } from '../../src/modules/notifications/push-readiness';
import { WaitlistOfferService } from '../../src/modules/favorites/waitlist-offer.service';

/**
 * A REAL offer service for the suites that construct the engine by hand.
 *
 * ── WHY NOT A STUB ──────────────────────────────────────────────────────
 *
 * `HoldExpiryService` gained a `WaitlistOfferService` in Group G, because
 * doc 05 §3's expiry branch ends with "check waitlist". Three e2e suites build
 * that service directly rather than through the Nest container, and the
 * cheapest way to make them compile again would have been `{} as never` or a
 * jest mock.
 *
 * Both would have made the new hook untestable in exactly the suites that
 * exercise expiry — the only place the hold-expiry → offer path can be observed
 * end to end. A stub here is how the offer engine ends up with a caller that
 * nothing proves calls it, which is the failure mode this codebase keeps
 * finding.
 *
 * So it is the real service, with the real notification service behind it,
 * writing real rows. `LoggingPushDelivery` is what the app binds outside
 * production anyway, so nothing here is a test-only path.
 */
export function realWaitlistOffers(prisma: PrismaService): WaitlistOfferService {
  return new WaitlistOfferService(
    prisma,
    // Readiness is passed EXPLICITLY, with no credential — the same answer the
    // app computes outside production. It is a constructor argument rather
    // than an ambient default precisely because platform support stopped being
    // the adapter's business on 2026-08-10: the send path now refuses an
    // undeliverable platform itself, so a helper that omitted this would be
    // testing a service that cannot refuse anything.
    new NotificationsService(prisma, new LoggingPushDelivery('test'), pushReadiness(null)),
  );
}
