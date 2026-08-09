import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { WaitlistOfferService } from './waitlist-offer.service';

/** One tick a minute, matching the other two sweepers in the system. */
export const OFFER_SWEEP_INTERVAL_MS = 60_000;

/**
 * Closes out lapsed waitlist offers (C-3.6, doc 05 §5).
 *
 * ── WHY THERE IS NO BULLMQ JOB BESIDE THIS ONE ──────────────────────────
 *
 * Hold expiry has both a delayed job and a sweeper, because a hold that never
 * expires locks a table forever — the sweeper exists so the design survives
 * Redis being flushed. A waitlist offer locks nothing (see
 * `WaitlistOfferService`), so the worst a late sweep costs is that a diner's
 * "still on the list" note arrives a minute late. Adding a second mechanism to
 * a job with no inventory at stake would be machinery for its own sake.
 */
@Injectable()
export class WaitlistOfferScheduler {
  private readonly logger = new Logger(WaitlistOfferScheduler.name);
  private running = false;

  constructor(private readonly offers: WaitlistOfferService) {}

  @Interval('waitlist-offer-expiry-sweep', OFFER_SWEEP_INTERVAL_MS)
  async sweep(): Promise<void> {
    if (this.running) {
      this.logger.warn('Previous offer sweep still running — skipping this tick.');
      return;
    }
    this.running = true;
    try {
      await this.offers.expireLapsedOffers();
    } catch (err) {
      this.logger.error(`Waitlist offer sweep failed: ${String(err)}`);
    } finally {
      this.running = false;
    }
  }
}
