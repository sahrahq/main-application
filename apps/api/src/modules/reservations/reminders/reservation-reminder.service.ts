import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../../shared/prisma/prisma.service';
import { NotificationsService } from '../../notifications/notifications.service';
import type { NotificationType } from '../../notifications/notification.ports';

/**
 * The two lead times C-3.9 names. Each is a half-open window `[from, to)` in
 * hours before `starts_at`.
 */
export const REMINDERS: ReadonlyArray<{
  type: NotificationType;
  fromHours: number;
  toHours: number;
  key: string;
}> = [
  { type: 'reservation_reminder_24h', fromHours: 23, toHours: 24, key: 'reminder_24h' },
  { type: 'reservation_reminder_2h', fromHours: 1, toHours: 2, key: 'reminder_2h' },
];

/** Cadence. Matches the hold-expiry sweeper — one heartbeat in this service. */
export const REMINDER_SWEEP_INTERVAL_MS = 60_000;

interface DueRow {
  id: string;
  user_id: string;
  code: string;
  starts_at: Date;
  party_size: number;
  name_en: string;
  name_ar: string;
  timezone: string;
}

/**
 * C-3.9 — "Reminders: 24h and 2h before, via push + WhatsApp". **P0.**
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THIS IS THE RECORD HALF, AND ON ITS OWN IT REDUCES NO-SHOWS BY NOTHING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * C-3.9 calls reminders "the single biggest no-show reducer". That is true of a
 * reminder that reaches a lock screen. It is not true of one that reaches only
 * the in-app centre, because nobody opens a notification centre the day before
 * dinner — and the in-app centre is the only channel that exists, since push is
 * blocked on the Firebase project and WhatsApp on a Business API provider
 * (`docs/decisions/2026-08-09-firebase-handover.md`).
 *
 * So this is worth building now for one reason: on the day an adapter is bound,
 * the schedule is already correct and already tested, rather than being written
 * under the pressure of a channel that suddenly works. It is NOT worth
 * reporting as "reminders are done".
 *
 * ── A SWEEPER, NOT A DELAYED JOB PER RESERVATION ─────────────────────────
 *
 * Hold expiry schedules a BullMQ job at booking time because a hold's deadline
 * is fixed the moment it is created. A reminder's deadline is not: C-3.4 lets a
 * diner MOVE a booking, and a job scheduled for the old `starts_at` would fire
 * at the wrong hour — or fire for a booking that has since been cancelled. A
 * sweeper reads the current row every time, so a moved booking is reminded
 * about its new time with no cancel-and-reschedule dance, and a cancelled one
 * simply stops matching.
 *
 * ── THE WINDOW, AND WHY IT IS NOT "WITHIN 24 HOURS" ──────────────────────
 *
 * `starts_at BETWEEN now + 23h AND now + 24h`, not `<= now + 24h`. The second
 * form would fire a "your table is tomorrow" reminder the instant somebody
 * books a table for tonight, which is the most annoying possible version of a
 * helpful feature.
 *
 * The cost is real and is stated rather than hidden: **an outage longer than
 * the window silently skips that reminder.** More than an hour down and the 23
 * to 24 hour band passes unswept; the 2h band has the same one-hour tolerance.
 * The alternative — a persistent `reminded_at` column per lead time — is two
 * more columns on `reservations`, the hottest table in the system, to recover
 * a reminder for an outage during which nothing else worked either.
 *
 * ── AND DEDUPLICATION IS THE DATABASE'S JOB ──────────────────────────────
 *
 * Overlapping ticks, two API instances in a rolling deploy, a slow sweep
 * running into the next one: all of these re-select the same reservation, and
 * all of them are made harmless by `idx_notifications_dedupe`. Not by a
 * `NOT EXISTS` check before the insert, which is check-then-act across two
 * statements and lets two workers both find nothing and both write.
 */
@Injectable()
export class ReservationReminderService {
  private readonly logger = new Logger(ReservationReminderService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Both lead times. Returns how many reminders were newly recorded. */
  async sweep(): Promise<number> {
    let sent = 0;
    for (const reminder of REMINDERS) {
      sent += await this.sweepOne(reminder);
    }
    return sent;
  }

  /**
   * One lead time.
   *
   * `user_id IS NOT NULL` — a walk-in entered by staff has no account, so
   * there is nobody to remind. Without the predicate the notification insert
   * would fail its foreign key once per sweep, forever.
   */
  private async sweepOne(reminder: (typeof REMINDERS)[number]): Promise<number> {
    const due = await this.prisma.$queryRaw<DueRow[]>`
      SELECT res.id, res.user_id, res.code, res.starts_at, res.party_size,
             r.name_en, r.name_ar, r.timezone
        FROM reservations res
        JOIN restaurants  r ON r.id = res.restaurant_id
       WHERE res.status IN ('confirmed', 'pending')
         AND res.user_id IS NOT NULL
         -- Multiplied by an interval literal rather than passed to
         -- make_interval: Prisma binds a JS number as bigint and there is no
         -- make_interval(bigint) overload, so the named-argument form fails at
         -- runtime with 42883 -- which the sweeper would then swallow into its
         -- catch, once a minute, silently, forever.
         AND res.starts_at >= now() + ${reminder.fromHours} * interval '1 hour'
         AND res.starts_at <  now() + ${reminder.toHours} * interval '1 hour'
         -- ALREADY-TOLD ROWS ARE FILTERED HERE AS WELL AS REFUSED BY THE INDEX,
         -- and both are needed. The index is the GUARANTEE — it is what makes
         -- two workers safe. This predicate is what stops the ordinary case
         -- from reaching it: the 24h window is an hour wide and the sweeper
         -- ticks every minute, so without it every booking would be re-selected
         -- ~60 times and each attempt would raise a unique violation that
         -- Prisma logs as an ERROR. An operator watching the logs would see
         -- sixty failures a minute describing a system working exactly as
         -- designed, which is how real failures stop being visible.
         --
         -- Same relationship as layers 2 and 3 in the booking engine: the
         -- re-check makes the common path clean, the constraint makes it
         -- correct. Uses idx_notifications_dedupe.
         AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.dedupe_key = ${reminder.key} || ':' || res.id::text
         )
       ORDER BY res.starts_at ASC
       LIMIT 500`;

    let sent = 0;
    for (const row of due) {
      const local = localParts(row.starts_at, row.timezone);
      const id = await this.notifications.notify({
        userId: row.user_id,
        type: reminder.type,
        data: {
          reservation_id: row.id,
          code: row.code,
          venue: row.name_en,
          venue_ar: row.name_ar,
          starts_at: row.starts_at.toISOString(),
          date: local.date,
          time: local.time,
          party: String(row.party_size),
        },
        // THE ENFORCEMENT. One per reservation per lead time, for all time.
        dedupeKey: `${reminder.key}:${row.id}`,
      });
      // `notify` returns null for a dedupe hit as well as for a failure, and
      // counting only the writes is what makes "the second sweep sent nothing"
      // an assertable zero rather than an inference.
      if (id) sent++;
    }

    if (sent > 0) {
      this.logger.log(`Recorded ${sent} ${reminder.type} reminder(s).`);
    }
    return sent;
  }
}

/**
 * The venue's wall clock, not UTC and not the server's.
 *
 * A reminder that says "21:00" has to say the time printed on the booking. Egypt
 * is UTC+2/+3 depending on DST, so formatting the instant in UTC would tell a
 * diner their 21:00 table is at 19:00 — and they would arrive two hours early
 * or conclude we had moved it.
 */
function localParts(at: Date, timezone: string): { date: string; time: string } {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = Object.fromEntries(fmt.formatToParts(at).map((p) => [p.type, p.value]));
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    // `hour12: false` renders midnight as 24 in some ICU builds; normalise it.
    time: `${parts.hour === '24' ? '00' : parts.hour}:${parts.minute}`,
  };
}
