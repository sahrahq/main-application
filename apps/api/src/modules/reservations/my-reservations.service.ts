import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { isValidTimeZone, utcToZonedHhmm, zoneOffsetMs } from '../../shared/time/timezone';
import { isReviewable } from '../reviews/review-eligibility';

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
         res.cancelled_at, res.cancel_reason, res.cancellation_seen_at,
         r.id           AS r_id,
         r.slug         AS r_slug,
         r.name_en      AS r_name_en,
         r.name_ar      AS r_name_ar,
         r.neighborhood AS r_neighborhood,
         r.city         AS r_city,
         r.timezone     AS r_timezone,
         rv.id          AS review_id
    FROM reservations res
    JOIN restaurants  r  ON r.id = res.restaurant_id
    -- LEFT JOIN, one row at most: reviews.reservation_id is UNIQUE, so this
    -- cannot multiply the reservation. Joined rather than fetched per row
    -- because the bookings list would otherwise make one query per booking to
    -- answer "have I reviewed this".
    LEFT JOIN reviews rv ON rv.reservation_id = res.id`;

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

/**
 * The one cancellation the diner did not perform.
 *
 * A booking the DINER cancelled can leave the upcoming list immediately: they
 * were there, they know. A booking the RESTAURANT cancelled cannot — if it
 * simply disappears, the diner turns up to a venue that is not expecting them,
 * in front of their guests, and blames SAHRA. That is the worst experience
 * this product can produce, and it is produced by a `WHERE status IN (...)`
 * clause that looks entirely reasonable.
 *
 * So it stays VISIBLE until acknowledged — **regardless of date**. It leaves
 * because they saw it, not because the date passed. A diner opening the app
 * three days late is exactly the person who most needs telling.
 */
const CANCELLED_BY_VENUE = 'cancelled_by_restaurant';

// The review rule, imported rather than restated. See `review-eligibility.ts`
// for why an invariant with no schema behind it must have exactly one copy.


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
  /** 'user' | 'restaurant' | null — derived, so no client parses a status. */
  cancelled_by: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  /**
   * The restaurant cancelled and the diner has not been shown it yet. The
   * client MUST surface this; it is the only signal that a booking they think
   * they have is gone.
   */
  needs_acknowledgement: boolean;
  /**
   * Whether `POST /reviews` would accept this reservation right now.
   *
   * DERIVED ON THE SERVER, and that is the point. The rule — seated or
   * completed, and the table time is over — lives in `ReviewsService` because
   * the database cannot hold it. Sending the client a status and letting it
   * reach the same conclusion would make TWO definitions of an invariant that
   * already has no schema behind it, and the client's copy would be the one
   * nobody tests against a real `no_show`.
   *
   * False when already reviewed, so a screen never has to combine two fields
   * to decide whether to draw one control.
   */
  can_review: boolean;
  /** The review this visit already has, if any. Null is the common case. */
  review_id: string | null;
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
  cancelled_at: Date | null;
  cancel_reason: string | null;
  cancellation_seen_at: Date | null;
  review_id: string | null;
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
                      AND (
                            (res.starts_at >= ${now}
                             AND res.status::text = ANY(${[...LIVE_STATUSES]}))
                         OR (res.status::text = ${CANCELLED_BY_VENUE}
                             AND res.cancellation_seen_at IS NULL)
                          )
                    ORDER BY res.starts_at ASC
                    LIMIT ${PAGE_LIMIT}`
      : await this.prisma.$queryRaw<Row[]>`
          ${SELECT} WHERE res.user_id = ${userId}::uuid
                      AND NOT (res.status::text = ANY(${[...NEVER_SHOWN]}))
                      AND NOT (res.status::text = ${CANCELLED_BY_VENUE}
                               AND res.cancellation_seen_at IS NULL)
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

  /**
   * The diner has seen that the restaurant cancelled.
   *
   * Its own call, not a side effect of reading the reservation. A GET that
   * acknowledged would be acknowledged by a prefetch, a retry, or a list
   * render — none of which is a human reading the notice, which is the only
   * event that should clear it.
   *
   * Idempotent, and only ever writes once: `cancellation_seen_at IS NULL`
   * guards the UPDATE, so a double tap does not move the timestamp.
   */
  async acknowledgeCancellation(userId: string, id: string): Promise<void> {
    // Ownership first, and it doubles as the 404 for someone else's id —
    // identical to the one for an id that exists for nobody.
    await this.one(userId, id);

    await this.prisma.$executeRaw`
      UPDATE reservations
         SET cancellation_seen_at = now()
         -- updated_at is NOT set here, and no longer needs to be:
         -- trg_touch_updated_at sets it on every UPDATE to every table that has
         -- the column. This statement is one of the two that forgot, which is
         -- why the trigger exists (20260809020000_no_silent_lapses).
       WHERE id = ${id}::uuid
         AND user_id = ${userId}::uuid
         AND status = 'cancelled_by_restaurant'
         AND cancellation_seen_at IS NULL`;
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
    cancelled_by: cancelledBy(r.status),
    cancelled_at: r.cancelled_at?.toISOString() ?? null,
    cancel_reason: r.cancel_reason,
    // Derived here rather than left to the client to work out from a status
    // string and a null check. A client that got the rule slightly wrong would
    // fail silently, in the one place where failing silently is the harm.
    needs_acknowledgement:
      r.status === 'cancelled_by_restaurant' && r.cancellation_seen_at === null,
    // ONE DEFINITION of the review rule, and this is not it — it defers to the
    // service that enforces it, so the answer here cannot drift from the
    // answer `POST /reviews` gives. `reviews-eligibility.spec.ts` asserts the
    // two agree on every status.
    can_review:
      r.review_id === null && isReviewable(r.status, r.ends_at),
    review_id: r.review_id,
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

/** Who cancelled, as a word rather than a status string to be parsed. */
function cancelledBy(status: string): string | null {
  if (status === 'cancelled_by_user') return 'user';
  if (status === 'cancelled_by_restaurant') return 'restaurant';
  return null;
}

/** YYYY-MM-DD on the venue's wall clock, not the server's. */
function zonedDate(instant: Date, timeZone: string): string {
  const shifted = new Date(instant.getTime() + zoneOffsetMs(instant, timeZone));
  return shifted.toISOString().slice(0, 10);
}
