import { Global, Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
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
      // Swap for the FCM adapter once the Firebase project exists (Stage 2).
      // This binding is the entire integration surface.
      provide: PUSH_DELIVERY,
      useFactory: () => new LoggingPushDelivery(),
    },
  ],
  controllers: [DevicesController],
  exports: [NotificationsService, DevicesService],
})
export class NotificationsModule {}
