import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { turnMinutes, DEFAULT_TURN_MINUTES } from '../reservations/turn-time';
import { zonedWallTimeToUtc, utcToZonedHhmm, isValidTimeZone } from '../../shared/time/timezone';

export interface SlotQuery {
  restaurantId: string;
  /** YYYY-MM-DD */
  date: string;
  partySize: number;
}

export interface Slot {
  /** HH:MM on the RESTAURANT'S wall clock — what the diner is shown. */
  time: string;
  /** Absolute instant the seating begins, ISO-8601 UTC. */
  startsAt: string;
  zones: string[];
}

export interface AvailabilityResult {
  date: string;
  partySize: number;
  /** IANA zone the `time` fields are expressed in. */
  timezone: string;
  slots: Slot[];
}

interface FreeTableRow {
  id: string;
  zone: string;
}

/**
 * Availability is DERIVED, never stored (doc 05 §1). The truth is: shifts
 * (when they serve) + tables (capacity) + live reservations (what is taken).
 * Nothing here writes; a stale cache is the only failure mode, never a
 * phantom booking.
 *
 * TIMEZONES (doc 04 §3): shifts store wall-clock TIME — 18:00 means six in the
 * evening *at the restaurant*. The grid is therefore built in the venue's own
 * zone and converted to absolute instants for every overlap check. Cairo runs
 * UTC+2 in winter and UTC+3 in summer, so the same shift is a different
 * instant depending on the date; `zonedWallTimeToUtc` resolves that per slot
 * rather than applying a fixed offset.
 *
 * Each slot carries BOTH representations: `time` for the diner, `startsAt` for
 * the client to POST back. Returning only the local string would force every
 * client to redo this conversion, and any client that got it wrong would book
 * the wrong hour.
 */
@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async getSlots(q: SlotQuery): Promise<AvailabilityResult> {
    const restaurant = await this.prisma.restaurant.findFirst({
      where: { id: q.restaurantId, deletedAt: null },
      select: { id: true, slotIntervalMin: true, status: true, timezone: true },
    });
    if (!restaurant) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }

    const dayStart = new Date(`${q.date}T00:00:00.000Z`);
    const shift = await this.shiftFor(q.restaurantId, dayStart);
    if (!shift) return { date: q.date, partySize: q.partySize, timezone: 'Africa/Cairo', slots: [] };

    const turnCfg =
      (shift.defaultTurnMinutes as Record<string, number> | null) ?? DEFAULT_TURN_MINUTES;
    const duration = turnMinutes(q.partySize, turnCfg) * 60_000;

    // Fall back to Cairo rather than the server's zone: a bad timezone value
    // must not silently become "wherever this container happens to run".
    const tz = isValidTimeZone(restaurant.timezone) ? restaurant.timezone : 'Africa/Cairo';

    // The shift's wall-clock bounds, resolved to real instants on this date.
    const open = wallToInstant(q.date, shift.opensAt, tz);
    let close = wallToInstant(q.date, shift.closesAt, tz);
    // A shift that closes "before" it opens runs past midnight (doc 04 shifts).
    if (shift.spansMidnight || close <= open) {
      const [y, m, d] = q.date.split('-').map(Number);
      const next = new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);
      close = wallToInstant(next, shift.closesAt, tz);
    }

    const stepMs = Math.max(5, restaurant.slotIntervalMin) * 60_000;
    const slots: Slot[] = [];

    for (let t = open.getTime(); t + duration <= close.getTime(); t += stepMs) {
      const startsAt = new Date(t);
      const endsAt = new Date(t + duration);
      const free = await this.freeTables(q.restaurantId, q.partySize, startsAt, endsAt);
      if (free.length === 0) continue;

      slots.push({
        // What the diner reads…
        time: utcToZonedHhmm(startsAt, tz),
        // …and what the client posts back. Never let these disagree.
        startsAt: startsAt.toISOString(),
        zones: [...new Set(free.map((f) => f.zone))].sort(),
      });
    }

    return { date: q.date, partySize: q.partySize, timezone: tz, slots };
  }

  /**
   * Tables that fit the party and have no live allocation overlapping the
   * window. Reads the same `during`/`active` columns the EXCLUDE constraint
   * guards, so availability and the booking re-check can never disagree about
   * what "free" means.
   */
  private async freeTables(
    restaurantId: string,
    partySize: number,
    startsAt: Date,
    endsAt: Date,
  ): Promise<FreeTableRow[]> {
    return this.prisma.$queryRaw<FreeTableRow[]>`
      SELECT t.id, t.zone::text AS zone
      FROM tables t
      WHERE t.restaurant_id = ${restaurantId}::uuid
        AND t.active
        AND t.max_capacity >= ${partySize}
        AND t.min_capacity <= ${partySize}
        AND NOT EXISTS (
          SELECT 1 FROM reservation_tables rt
          WHERE rt.table_id = t.id
            AND rt.active
            AND rt.during && tstzrange(${startsAt}, ${endsAt}, '[)')
        )`;
  }

  /** Date-specific shift wins over the weekly pattern (doc 04 §2 shifts). */
  private async shiftFor(restaurantId: string, dayStart: Date) {
    const specific = await this.prisma.shift.findFirst({
      where: { restaurantId, active: true, specificDate: dayStart },
      select: { opensAt: true, closesAt: true, spansMidnight: true, defaultTurnMinutes: true },
    });
    if (specific) return specific;

    return this.prisma.shift.findFirst({
      where: { restaurantId, active: true, dayOfWeek: dayStart.getUTCDay() },
      select: { opensAt: true, closesAt: true, spansMidnight: true, defaultTurnMinutes: true },
    });
  }
}

/**
 * Postgres TIME arrives as a Date pinned to 1970-01-01; its UTC hours/minutes
 * ARE the wall-clock digits the owner typed. Resolve those digits against the
 * real calendar date in the venue's zone.
 */
function wallToInstant(date: string, time: Date, timeZone: string): Date {
  return zonedWallTimeToUtc(date, time.getUTCHours(), time.getUTCMinutes(), timeZone);
}
