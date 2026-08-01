import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ReservationStatus } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { zonedWallTimeToUtc, utcToZonedHhmm, isValidTimeZone } from '../../shared/time/timezone';

export interface BookQuery {
  ownerId: string;
  restaurantId: string;
  /** The venue's local calendar day, YYYY-MM-DD. */
  date: string;
  status?: ReservationStatus | string;
}

export interface BookRow {
  id: string;
  code: string;
  /** HH:MM on the venue's wall clock — what the host reads off the screen. */
  time: string;
  /** Absolute instant, ISO-8601 UTC. */
  startsAt: string;
  partySize: number;
  status: ReservationStatus;
  guestName: string | null;
  guestPhone: string | null;
  specialRequests: string | null;
  occasion: string | null;
  tables: string[];
}

export interface BookResult {
  date: string;
  timezone: string;
  reservations: BookRow[];
}

interface RawBookRow {
  id: string;
  code: string;
  starts_at: Date;
  party_size: number;
  status: ReservationStatus;
  guest_name: string | null;
  guest_phone: string | null;
  special_requests: string | null;
  occasion: string | null;
  tables: string[] | null;
}

/**
 * The owner's book (doc 06 §4) — the screen a host works from all evening.
 *
 * THE SERVICE DAY IS LOCAL, NOT UTC. A Cairo venue serving until 02:00 has
 * covers that fall on the next UTC date while plainly belonging to tonight's
 * service. Cutting the book on UTC days would file the 01:00 party under
 * yesterday, and the host would never see them coming. The window is therefore
 * [local 00:00, next local 00:00), resolved through the same
 * `zonedWallTimeToUtc` the availability grid uses — one conversion, so the
 * book and the slot list can never disagree about which night a booking is on.
 */
@Injectable()
export class OwnerReservationsService {
  constructor(private readonly prisma: PrismaService) {}

  async listForDate(q: BookQuery): Promise<BookResult> {
    const restaurant = await this.prisma.restaurant.findFirst({
      where: { id: q.restaurantId, ownerId: q.ownerId, deletedAt: null },
      select: { id: true, timezone: true },
    });
    // Same error whether it is missing or another owner's — do not let this
    // endpoint enumerate other people's venues.
    if (!restaurant) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }

    const tz = isValidTimeZone(restaurant.timezone) ? restaurant.timezone : 'Africa/Cairo';

    const from = zonedWallTimeToUtc(q.date, 0, 0, tz);
    const to = zonedWallTimeToUtc(nextDay(q.date), 0, 0, tz);

    // Prisma.sql / Prisma.empty so the optional clause composes as a real
    // parameterised fragment — string-splicing a filter into raw SQL is how
    // injection gets in.
    const statusClause = q.status
      ? Prisma.sql`AND r.status = ${q.status}::reservation_status`
      : Prisma.empty;

    const rows = await this.prisma.$queryRaw<RawBookRow[]>(Prisma.sql`
      SELECT r.id, r.code, r.starts_at, r.party_size, r.status,
             r.guest_name, r.guest_phone, r.special_requests, r.occasion,
             ARRAY_REMOVE(ARRAY_AGG(t.name ORDER BY t.name), NULL) AS tables
      FROM reservations r
      LEFT JOIN reservation_tables rt ON rt.reservation_id = r.id
      LEFT JOIN tables t ON t.id = rt.table_id
      WHERE r.restaurant_id = ${q.restaurantId}::uuid
        AND r.starts_at >= ${from}
        AND r.starts_at <  ${to}
        ${statusClause}
      GROUP BY r.id
      ORDER BY r.starts_at ASC`);

    return {
      date: q.date,
      timezone: tz,
      reservations: rows.map((r) => ({
        id: r.id,
        code: r.code,
        time: utcToZonedHhmm(r.starts_at, tz),
        startsAt: r.starts_at.toISOString(),
        partySize: r.party_size,
        status: r.status,
        guestName: r.guest_name,
        guestPhone: r.guest_phone,
        specialRequests: r.special_requests,
        occasion: r.occasion,
        tables: r.tables ?? [],
      })),
    };
  }

}

/** Next calendar date, on the calendar — not "+24h", which DST breaks. */
function nextDay(date: string): string {
  const [y, m, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);
}
