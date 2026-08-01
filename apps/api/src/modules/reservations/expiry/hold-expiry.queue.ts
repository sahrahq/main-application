import { Injectable, Logger, Optional } from "@nestjs/common";
import { InjectQueue } from "@nestjs/bullmq";
import { Queue } from "bullmq";
import { HOLD_EXPIRY_QUEUE, EXPIRE_HOLD_JOB } from "./hold-expiry.constants";

/**
 * Schedules the PRECISE half of hold expiry (doc 05 section 4).
 *
 * Enqueueing is deliberately best-effort: if Redis is unavailable the hold is
 * still created and the 60s sweeper will release it. Failing the booking
 * because a queue was down would turn a degraded dependency into lost revenue,
 * and the backstop exists precisely so this call is not load-bearing.
 */
@Injectable()
export class HoldExpiryQueue {
  private readonly logger = new Logger(HoldExpiryQueue.name);

  constructor(
    @Optional() @InjectQueue(HOLD_EXPIRY_QUEUE) private readonly queue?: Queue,
  ) {}

  async scheduleExpiry(reservationId: string, delayMs: number): Promise<void> {
    if (!this.queue) return; // no Redis in this environment; sweeper covers it

    try {
      await this.queue.add(
        EXPIRE_HOLD_JOB,
        { reservationId },
        {
          delay: Math.max(0, delayMs),
          // jobId dedupes: a retried request must not queue two expiries.
          jobId: `expire:${reservationId}`,
          removeOnComplete: true,
          // Keep failures around briefly — a pile-up here means the worker is
          // broken and the sweeper is silently carrying the whole feature.
          removeOnFail: 100,
          attempts: 3,
          backoff: { type: "exponential", delay: 1000 },
        },
      );
    } catch (err) {
      this.logger.warn(
        `Could not enqueue expiry for ${reservationId} (${String(err)}). ` +
          "The 60s sweeper will release it.",
      );
    }
  }
}