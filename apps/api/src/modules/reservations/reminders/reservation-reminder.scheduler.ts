import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import {
  REMINDER_SWEEP_INTERVAL_MS,
  ReservationReminderService,
} from './reservation-reminder.service';

/**
 * The heartbeat for C-3.9's reminders.
 *
 * Same shape as `HoldExpiryScheduler`, deliberately: skip rather than queue,
 * never let a failed sweep kill the interval. The one difference is what a
 * missed tick costs — a lapsed hold locks a table until the next sweep, while
 * a missed reminder is a diner who was not nudged. Both recover on the next
 * tick; only one of them was holding inventory.
 */
@Injectable()
export class ReservationReminderScheduler {
  private readonly logger = new Logger(ReservationReminderScheduler.name);
  private running = false;

  constructor(private readonly reminders: ReservationReminderService) {}

  @Interval('reservation-reminder-sweep', REMINDER_SWEEP_INTERVAL_MS)
  async sweep(): Promise<void> {
    // Overlapping sweeps would re-select the same reservations and contend for
    // nothing — the dedupe index makes them harmless, not useful.
    if (this.running) {
      this.logger.warn('Previous reminder sweep still running — skipping this tick.');
      return;
    }
    this.running = true;
    try {
      await this.reminders.sweep();
    } catch (err) {
      this.logger.error(`Reminder sweep failed: ${String(err)}`);
    } finally {
      this.running = false;
    }
  }
}
