import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import { Job } from "bullmq";
import { HoldExpiryService } from "./hold-expiry.service";
import { HOLD_EXPIRY_QUEUE, EXPIRE_HOLD_JOB } from "./hold-expiry.constants";

/** The precise half: fires at the 5-minute mark for one specific hold. */
@Processor(HOLD_EXPIRY_QUEUE)
export class HoldExpiryProcessor extends WorkerHost {
  private readonly logger = new Logger(HoldExpiryProcessor.name);

  constructor(private readonly expiry: HoldExpiryService) {
    super();
  }

  async process(job: Job<{ reservationId: string }>): Promise<void> {
    if (job.name !== EXPIRE_HOLD_JOB) return;

    // expireOne is guarded on status='held' AND hold_expires_at < now(), so
    // BullMQ's at-least-once delivery is safe: a duplicate or late job simply
    // matches nothing rather than expiring a booking someone confirmed.
    const expired = await this.expiry.expireOne(job.data.reservationId);
    if (!expired) {
      this.logger.debug(
        `Hold ${job.data.reservationId} needed no action — confirmed, cancelled, ` +
          "or already swept.",
      );
    }
  }
}