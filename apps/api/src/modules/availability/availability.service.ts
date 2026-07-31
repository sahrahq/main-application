import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { turnMinutes, DEFAULT_TURN_MINUTES } from '../reservations/turn-time';

export interface SlotQuery {
  restaurantId: string;
  /** YYYY-MM-DD */
  date: string;
  partySize: number;
}

export interface Slot {
  /** HH:MM, restaurant-local grid (UTC for now — see note below). */
  time: string;
  zones: string[];
}

export interface AvailabilityResult {
  date: string;
  partySize: number;
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
 * NOTE ON TIMEZONES: the slot grid is currently computed in UTC. Restaurants
 * carry a `timezone` column (default Africa/Cairo) and doc 04 §3 says
 * restaurant-local logic derives from it. Cairo is UTC+2/+3 with DST, so this
 * is correct only while the seed data is expressed in UTC. Converting the grid
 * to restaurant-local time is required before real venues are onboarded — it
 * is a presentation-layer bug, not a double-booking one, because every
 * comparison below happens on absolute timestamps.
 */
@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async getSlots(q: SlotQuery): Promise<AvailabilityResult> {
    const restaurant = await this.prisma.restaurant.findFirst({
      where: { id: q.restaurantId, deletedAt: null },
      select: { id: true, slotIntervalMin: true, status: true },
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
    if (!shift) return { date: q.date, partySize: q.partySize, slots: [] };

    const turnCfg =
      (shift.defaultTurnMinutes as Record<string, number> | null) ?? DEFAULT_TURN_MINUTES;
    const duration = turnMinutes(q.partySize, turnCfg) * 60_000;

    const open = combine(q.date, shift.opensAt);
    let close = combine(q.date, shift.closesAt);
    // A shift that closes "before" it opens runs past midnight (doc 04 shifts).
    if (shift.spansMidnight || close <= open) close = new Date(close.getTime() + 86_400_000);

    const stepMs = Math.max(5, restaurant.slotIntervalMin) * 60_000;
    const slots: Slot[] = [];

    for (let t = open.getTime(); t + duration <= close.getTime(); t += stepMs) {
      const startsAt = new Date(t);
      const endsAt = new Date(t + duration);
      const free = await this.freeTables(q.restaurantId, q.partySize, startsAt, endsAt);
      if (free.length === 0) continue;

      slots.push({
        time: hhmm(startsAt),
        zones: [...new Set(free.map((f) => f.zone))].sort(),
      });
    }

    return { date: q.date, partySize: q.partySize, slots };
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

/** Postgres TIME arrives as a Date on 1970-01-01; graft it onto the real date. */
function combine(date: string, time: Date): Date {
  return new Date(
    `${date}T${String(time.getUTCHours()).padStart(2, '0')}:` +
      `${String(time.getUTCMinutes()).padStart(2, '0')}:00.000Z`,
  );
}

function hhmm(d: Date): string {
  return `${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`;
}
