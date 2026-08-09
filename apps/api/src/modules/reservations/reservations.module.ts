import { Module } from "@nestjs/common";
import { BullModule } from "@nestjs/bullmq";
import { ReservationsService } from "./reservations.service";
import { ReservationsController } from "./reservations.controller";
import { MyReservationsController } from "./my-reservations.controller";
import { MyReservationsService } from "./my-reservations.service";
import { HoldExpiryService } from "./expiry/hold-expiry.service";
import { HoldExpiryQueue } from "./expiry/hold-expiry.queue";
import { HoldExpiryProcessor } from "./expiry/hold-expiry.processor";
import { HoldExpiryScheduler } from "./expiry/hold-expiry.scheduler";
import { HOLD_EXPIRY_QUEUE } from "./expiry/hold-expiry.constants";
import { ReservationReminderService } from "./reminders/reservation-reminder.service";
import { ReservationReminderScheduler } from "./reminders/reservation-reminder.scheduler";
import { AvailabilityModule } from "../availability/availability.module";
import { FavoritesModule } from "../favorites/favorites.module";

/**
 * The BullMQ queue is registered only when REDIS_URL is set. Without it the
 * precise delayed job is absent and the 60s sweeper carries expiry alone —
 * degraded but correct, which is exactly what doc 05 section 4's backstop is
 * for. The sweeper is registered unconditionally.
 */
const queueImports = process.env.REDIS_URL
  ? [BullModule.registerQueue({ name: HOLD_EXPIRY_QUEUE })]
  : [];

/**
 * `AvailabilityModule` for `GET /reservations/:id/available-slots` — the same
 * grid the booking screen reads, with the reservation being moved excluded.
 * Imported rather than reimplemented: two pieces of code that both decide what
 * "free" means are two pieces of code that will eventually disagree, and one
 * of them will be the one the diner sees.
 */

const queueProviders = process.env.REDIS_URL ? [HoldExpiryProcessor] : [];

/**
 * `FavoritesModule` for `WaitlistOfferService` (C-3.6). Three code paths in
 * here free a table — a diner cancelling, the expiry sweeper, and the delayed
 * expiry job — and doc 05 §3's flowchart ends every one of them with "check
 * waitlist". Imported rather than duplicated: a second copy of "who is next in
 * the queue" would eventually disagree with the first, and only one of them
 * would be the one that sent the notification.
 */
@Module({
  imports: [...queueImports, AvailabilityModule, FavoritesModule],
  providers: [MyReservationsService,
    ReservationsService,
    HoldExpiryService,
    HoldExpiryQueue,
    HoldExpiryScheduler,
    ReservationReminderService,
    ReservationReminderScheduler,
    ...queueProviders,
  ],
  controllers: [ReservationsController, MyReservationsController],
  exports: [ReservationsService, HoldExpiryService, ReservationReminderService],
})
export class ReservationsModule {}