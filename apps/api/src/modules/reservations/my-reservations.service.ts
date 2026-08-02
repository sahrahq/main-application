import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { isValidTimeZone, utcToZonedHhmm, zoneOffsetMs } from '../../shared/time/timezone';

/**
 * One projection, used by both reads.
 *
 * The venue is joined rather than left to the client: "my bookings" is a list
 * of venue NAMES, and a screen that had to fetch each one would issue N+1
 * requests over a Cairo mobile connection to render its first screenful.
 */
const SELECT = Prisma.sql`
  SELECT res.id, res.code, res.status::text AS status, res.source::text AS source,
         res.starts_at, res.ends_at, res.party_size,
         res.special_requests, res.occasion,
         r.id           AS r_id,
         r.slug         AS r_slug,
         r.name_en      AS r_name_en,
         r.name_ar      AS r_name_ar,
         r.neighborhood AS r_neighborhood,
         r.city         AS r_city,
         r.timezone     AS r_timezone
    FROM reservations res
    JOIN restaurants  r ON r.id = res.restaurant_id`;

/** doc 06 §3 — `?status=upcoming|past`. */
export const RESERVATION_VIEWS = ['upcoming', 'past'] as const;
export type ReservationView = (typeof RESERVATION_VIEWS)[number];

/**
 * Statuses that mean "you are going".
 *
 * `held` is EXCLUDED. A hold is a five-minute claim, not a booking: it expires
 * on its own, so it would vanish from the list while the diner was looking at
 * it, and until then it reads as a confirmed table they do not have. The worst
 * failure in a reservation app is telling somebody they have a table when they
 * do not.
 *
 * `expired` is excluded from BOTH views for the same reason from the other
 * side — a hold that lapsed is not a thing that happened to the diner.
 */
const LIVE_STATUSES = ['pending', 'confirmed', 'seated'] as const;
const NEVER_SHOWN = ['held', 'expired'] as const;

export interface MyReservationRow {
  id: string;
  code: string;
  status: string;
  source: string;
  starts_at: string;
  ends_at: string;
  /** Venue wall clock, so no client has to guess a zone. */
  date: string;
  time: string;
  party_size: number;
  special_requests: string | null;
  occasion: string | null;
  restaurant: {
    id: string;
    slug: string;
    name_en: string;
    name_ar: string;
    neighborhood: string | null;
    city: string;
    timezone: string;
  };
}

interface Row {
  id: string;
  code: string;
  status: string;
  source: string;
  starts_at: Date;
  ends_at: Date;
  party_size: number;
  special_requests: string | null;
  occasion: string | null;
  r_id: string;
  r_slug: string;
  r_name_en: string;
  r_name_ar: string;
  r_neighborhood: string | null;
  r_city: string;
  r_timezone: string;
}

/**
 * A diner's own reservations (doc 06 §3).
 *
 * OWNERSHIP IS IN THE QUERY, not in a check after the fact. `user_id = $me` is
 * part of every WHERE clause here, so there is no code path that fetches a row
 * and then decides whether the caller may see it — which is the shape that
 * eventually forgets to decide.
 */
@Injectable()
export class MyReservationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, view: ReservationView): Promise<MyReservationRow[]> {
    const now = new Date();

    // Upcoming: still to come AND still on. A CANCELLED future booking is not
    // upcoming — "upcoming" answers "where am I going?" and the answer is not
    // there — but it does belong in history, because a diner looking for what
    // happened to a booking they cancelled should find it.
    const rows = view === 'upcoming'
      ? await this.prisma.$queryRaw<Row[]>`
          ${SELECT} WHERE res.user_id = ${userId}::uuid
                      AND res.starts_at >= ${now}
                      AND res.status::text = ANY(${[...LIVE_STATUSES]})
                    ORDER BY res.starts_at ASC
                    LIMIT ${PAGE_LIMIT}`
      : await this.prisma.$queryRaw<Row[]>`
          ${SELECT} WHERE res.user_id = ${userId}::uuid
                      AND NOT (res.status::text = ANY(${[...NEVER_SHOWN]}))
                      AND (res.starts_at < ${now}
                           OR NOT (res.status::text = ANY(${[...LIVE_STATUSES]})))
                    ORDER BY res.starts_at DESC
                    LIMIT ${PAGE_LIMIT}`;

    return rows.map(toRow);
  }

  /**
   * One reservation, by id, belonging to [userId].
   *
   * **404, NEVER 403**, for a row that belongs to somebody else — and the
   * response is identical to one for an id that exists for nobody. A 403
   * confirms the row exists, and the difference between "not yours" and "no
   * such thing" is exactly what an enumeration oracle needs. Unlike a venue
   * slug there is no legitimate reason for anyone to probe for a reservation
   * id, so there is nothing lost by refusing to distinguish them.
   */
  async one(userId: string, id: string): Promise<MyReservationRow> {
    const rows = await this.prisma.$queryRaw<Row[]>`
      ${SELECT} WHERE res.id = ${id}::uuid AND res.user_id = ${userId}::uuid LIMIT 1`;

    const row = rows[0];
    if (!row) {
      throw new NotFoundException({
        code: 'reservation_not_found',
        message: 'We could not find that reservation.',
        message_ar: 'مش لاقيين الحجز ده.',
      });
    }
    return toRow(row);
  }

  static parseView(raw: string | undefined): ReservationView {
    // Defaults to `upcoming` — what a diner opening "my bookings" wants — but
    // an UNKNOWN value is an error rather than a silent fall back to the
    // default. A client asking for `?status=cancelled` and quietly receiving
    // upcoming bookings would render the wrong list with no sign anything
    // went wrong.
    if (raw === undefined || raw === '') return 'upcoming';
    if ((RESERVATION_VIEWS as readonly string[]).includes(raw)) return raw as ReservationView;

    throw new BadRequestException({
      code: 'invalid_query_param',
      message: `status must be one of: ${RESERVATION_VIEWS.join(', ')}.`,
      message_ar: 'قيمة status لازم تكون upcoming أو past.',
      details: [{ field: 'status', issue: 'enum' }],
    });
  }
}

/** doc 06 §1 wants cursor pagination; this is a cap until that lands. */
const PAGE_LIMIT = 50;

function toRow(r: Row): MyReservationRow {
  const tz = isValidTimeZone(r.r_timezone) ? r.r_timezone : 'Africa/Cairo';
  return {
    id: r.id,
    code: r.code,
    status: r.status,
    source: r.source,
    starts_at: r.starts_at.toISOString(),
    ends_at: r.ends_at.toISOString(),
    // BOTH forms, deliberately. `starts_at` is the absolute instant; `date`
    // and `time` are the venue's wall clock. A client deriving the second from
    // the first plus a guessed zone is 2–3 hours out in Cairo depending on the
    // date, which is the error class the whole timezone module exists for.
    date: zonedDate(r.starts_at, tz),
    time: utcToZonedHhmm(r.starts_at, tz),
    party_size: r.party_size,
    special_requests: r.special_requests,
    occasion: r.occasion,
    restaurant: {
      id: r.r_id,
      slug: r.r_slug,
      name_en: r.r_name_en,
      name_ar: r.r_name_ar,
      neighborhood: r.r_neighborhood,
      city: r.r_city,
      timezone: tz,
    },
  };
}

/** YYYY-MM-DD on the venue's wall clock, not the server's. */
function zonedDate(instant: Date, timeZone: string): string {
  const shifted = new Date(instant.getTime() + zoneOffsetMs(instant, timeZone));
  return shifted.toISOString().slice(0, 10);
}
