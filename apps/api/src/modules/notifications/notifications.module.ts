import { Global, Logger, Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { DevicesService } from './devices.service';
import { DevicesController } from './devices.controller';
import { PUSH_DELIVERY } from './notification.ports';
import { LoggingPushDelivery } from './delivery/logging-push.delivery';
import { FcmPushDelivery } from './delivery/fcm-push.delivery';
import { FirebaseAdminSender } from './delivery/firebase-admin.sender';
import { loadFirebaseConfig } from '../../shared/config/firebase.config';
import { PUSH_READINESS, pushReadiness, pushReadinessBanner } from './push-readiness';

/**
 * NOTIFY-1. Stage 1 built the record; **Stage 2 (2026-08-10) bound the carrier.**
 *
 * GLOBAL, because a notification is emitted by whichever module the EVENT
 * happens in — a venue cancellation lives in `restaurants`, a reminder lives in
 * `reservations` — and threading an import through every one of them is how a
 * module ends up not emitting anything because the wiring was awkward.
 */
@Global()
@Module({
  providers: [
    NotificationsService,
    DevicesService,
    {
      // ═══════════════════════════════════════════════════════════════════
      //  THE ENTIRE FIREBASE INTEGRATION SURFACE IS THIS ONE BINDING.
      //
      //  It held. Stage 2 replaced the value and changed nothing above
      //  `PushDelivery` — no service, no controller, no test of the read half.
      //  That was the claim the seam was built on, and it is now checked rather
      //  than asserted.
      //
      //  Credentials, and what must never be committed:
      //  `docs/decisions/2026-08-09-firebase-handover.md`.
      // ═══════════════════════════════════════════════════════════════════
      provide: PUSH_DELIVERY,
      inject: [DevicesService],
      useFactory: (devices: DevicesService) => {
        const logger = new Logger('PushDelivery');

        // THROWS when configured wrongly, returns null when not configured at
        // all. The difference is the point: a missing credential is routine in
        // development and CI, a broken one is somebody who believes push is on.
        const config = loadFirebaseConfig();

        if (!config) {
          for (const line of pushReadinessBanner(pushReadiness(null))) logger.warn(line);
          // Still refuses to construct under NODE_ENV=production, so "we forgot
          // to configure Firebase" cannot ship as silence.
          return new LoggingPushDelivery();
        }

        for (const line of pushReadinessBanner(pushReadiness(config.projectId))) {
          logger.warn(line);
        }

        return new FcmPushDelivery(
          config,
          new FirebaseAdminSender(config),
          // A dead token is revoked rather than retried forever. Bound here so
          // the adapter depends on a function, not on a Nest service.
          (token) => devices.revokeDeadToken(token),
        );
      },
    },
    {
      // Read by `/health`, so the deployment's own answer to "can we reach an
      // iPhone?" comes from the same function the send path uses. Two sources
      // for that would eventually disagree, and the health check would be the
      // one that said yes.
      provide: PUSH_READINESS,
      useFactory: () => {
        // Never throws: `/health` has to answer even when the credential is
        // broken, and it is the endpoint most likely to be asked at that moment.
        try {
          return pushReadiness(loadFirebaseConfig()?.projectId ?? null);
        } catch {
          return pushReadiness(null);
        }
      },
    },
  ],
  controllers: [DevicesController, NotificationsController],
  exports: [NotificationsService, DevicesService, PUSH_READINESS],
})
export class NotificationsModule {}
