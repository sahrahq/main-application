import { Module } from "@nestjs/common";
import { BullModule } from "@nestjs/bullmq";
import { ReservationsService } from "./reservations.service";
import { ReservationsController } from "./reservations.controller";
import { HoldExpiryService } from "./expiry/hold-expiry.service";
import { HoldExpiryQueue } from "./expiry/hold-expiry.queue";
import { HoldExpiryProcessor } from "./expiry/hold-expiry.processor";
import { HoldExpiryScheduler } from "./expiry/hold-expiry.scheduler";
import { HOLD_EXPIRY_QUEUE } from "./expiry/hold-expiry.constants";

/**
 * The BullMQ queue is registered only when REDIS_URL is set. Without it the
 * precise delayed job is absent and the 60s sweeper carries expiry alone —
 * degraded but correct, which is exactly what doc 05 section 4's backstop is
 * for. The sweeper is registered unconditionally.
 */
const queueImports = process.env.REDIS_URL
  ? [BullModule.registerQueue({ name: HOLD_EXPIRY_QUEUE })]
  : [];

const queueProviders = process.env.REDIS_URL ? [HoldExpiryProcessor] : [];

@Module({
  imports: queueImports,
  providers: [
    ReservationsService,
    HoldExpiryService,
    HoldExpiryQueue,
    HoldExpiryScheduler,
    ...queueProviders,
  ],
  controllers: [ReservationsController],
  exports: [ReservationsService, HoldExpiryService],
})
export class ReservationsModule {}