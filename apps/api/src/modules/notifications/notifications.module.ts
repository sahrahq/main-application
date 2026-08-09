import { Global, Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { DevicesService } from './devices.service';
import { DevicesController } from './devices.controller';
import { PUSH_DELIVERY } from './notification.ports';
import { LoggingPushDelivery } from './delivery/logging-push.delivery';

/**
 * NOTIFY-1 Stage 1.
 *
 * GLOBAL, because a notification is emitted by whichever module the EVENT
 * happens in — a venue cancellation lives in `restaurants`, a reminder will
 * live in `reservations` — and threading an import through every one of them
 * is how a module ends up not emitting anything because the wiring was
 * awkward.
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
      //  Swap `LoggingPushDelivery` for an FCM adapter and every notification
      //  in the system starts being delivered; nothing above `PushDelivery`
      //  changes. That is the test of whether the seam was in the right place,
      //  and it is why the read half could be built ahead of the channel.
      //
      //  What that swap needs from the product owner — which credential, which
      //  file, which env var, what must never be committed — is written out in
      //  `docs/decisions/2026-08-09-firebase-handover.md`.
      // ═══════════════════════════════════════════════════════════════════
      provide: PUSH_DELIVERY,
      useFactory: () => new LoggingPushDelivery(),
    },
  ],
  controllers: [DevicesController, NotificationsController],
  exports: [NotificationsService, DevicesService],
})
export class NotificationsModule {}
