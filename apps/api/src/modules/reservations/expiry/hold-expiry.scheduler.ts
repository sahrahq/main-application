import { Injectable, Logger } from "@nestjs/common";
import { Interval } from "@nestjs/schedule";
import { HoldExpiryService } from "./hold-expiry.service";
import { SWEEP_INTERVAL_MS } from "./hold-expiry.constants";

/**
 * The BACKSTOP half (doc 05 section 4): "a sweeper runs every 60 s ... catches
 * jobs lost to worker crashes".
 *
 * Depends on nothing but Postgres. If Redis is flushed, the worker dies, or a
 * delayed job is silently dropped, this still releases the table — which is
 * the only reason the design is safe to rely on.
 */
@Injectable()
export class HoldExpiryScheduler {
  private readonly logger = new Logger(HoldExpiryScheduler.name);
  private running = false;

  constructor(private readonly expiry: HoldExpiryService) {}

  @Interval("hold-expiry-sweep", SWEEP_INTERVAL_MS)
  async sweep(): Promise<void> {
    // Skip rather than queue: overlapping sweeps would contend on the same
    // rows for no benefit, and a slow sweep must not stack up behind itself.
    if (this.running) {
      this.logger.warn("Previous sweep still running — skipping this tick.");
      return;
    }
    this.running = true;
    try {
      const n = await this.expiry.sweep();
      if (n > 0) this.logger.log(`Sweeper released ${n} lapsed hold(s).`);
    } catch (err) {
      // Never let a failed sweep kill the interval; the next tick retries.
      this.logger.error(`Hold-expiry sweep failed: ${String(err)}`);
    } finally {
      this.running = false;
    }
  }
}