import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { LiveRestaurantResolver } from '../restaurants/live-restaurant';
import { reviewIneligibility } from './review-eligibility';

export interface PublicReview {
  id: string;
  rating: number;
  food_rating: number | null;
  service_rating: number | null;
  ambience_rating: number | null;
  body: string | null;
  /** First name plus a surname initial — see `displayName`. */
  author: string;
  created_at: string;
  owner_reply: string | null;
  owner_replied_at: string | null;
}

export interface ReviewSummary {
  rating: number;
  rating_count: number;
  /** How many gave 5, 4, 3, 2, 1 — keyed by the figure, as strings. */
  breakdown: Record<string, number>;
}

export interface ReviewPage {
  summary: ReviewSummary;
  results: PublicReview[];
  next_cursor: string | null;
}

interface ReviewRow {
  id: string;
  rating: number;
  food_rating: number | null;
  service_rating: number | null;
  ambience_rating: number | null;
  body: string | null;
  full_name: string;
  created_at: Date;
  owner_reply: string | null;
  owner_replied_at: Date | null;
}


/**
 * A NAME A STRANGER CAN SEE.
 *
 * `users.full_name` is what the diner gave at registration and is often their
 * full legal name. Publishing it under a review attaches a real person's name
 * to a place they were, on a given evening, on a public page.
 *
 * So: first name, and the initial of whatever follows. «نور حسن» becomes
 * «نور ح.», "Omar Abdelrahman" becomes "Omar A." — which is also exactly what
 * the design reference shows in `AvatarStack` ("Nour H"), so this is the
 * product's own convention rather than a privacy measure invented here.
 *
 * A single-word name is left alone. Adding a dot after it would invent an
 * initial that does not exist.
 */
export function displayName(fullName: string): string {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '';
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[1].charAt(0)}.`;
}

/**
 * C-4.4 — reviews, from diners who actually turned up.
 *
 * ── THE ELIGIBILITY RULE LIVES HERE, IN CODE, AND THAT IS THE WEAK POINT ──
 *
 * Quoting the decision doc so it cannot drift from it:
 *
 *   "'only a seated diner may review' enforced in code, not the database, and
 *    flagged rather than dressed up as enforced."
 *
 * The database holds the half it can: `reservation_id` is NOT NULL and UNIQUE,
 * so there is no review without a visit and no second review per visit. What
 * it cannot hold is which STATUS that reservation is in, because a CHECK
 * cannot read another table and every mechanism that can — a composite foreign
 * key into `(id, status)`, a trigger — makes an unrelated later write fail:
 * once a review exists, an owner correcting the reservation to `no_show` would
 * get a foreign-key error from a table they have never heard of.
 *
 * So it is `assertEligible` below, and `reviews.e2e-spec.ts` attempts a review
 * from every non-eligible status rather than asserting the happy path twice.
 */
@Injectable()
export class ReviewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly live: LiveRestaurantResolver,
  ) {}

  /**
   * Published reviews for a live venue, newest first.
   *
   * Keyset pagination on `created_at`, matching `idx_reviews_rest`. OFFSET
   * would drift as new reviews land: a diner reading page two after somebody
   * posts would see one they already read and miss one they did not.
   */
  async forRestaurant(
    idOrSlug: string,
    opts: { cursor?: string; limit: number },
  ): Promise<ReviewPage> {
    const restaurantId = await this.live.resolveId(idOrSlug);

    const cursor = opts.cursor ? new Date(opts.cursor) : null;
    if (cursor && Number.isNaN(cursor.getTime())) {
      throw new NotFoundException({
        code: 'invalid_query_param',
        message: 'That cursor is not a time.',
        message_ar: 'المؤشر ده مش وقت صالح.',
      });
    }

    const rows = await this.prisma.$queryRaw<ReviewRow[]>`
      SELECT rv.id, rv.rating, rv.food_rating, rv.service_rating, rv.ambience_rating,
             rv.body, u.full_name, rv.created_at, rv.owner_reply, rv.owner_replied_at
        FROM reviews rv
        JOIN users u ON u.id = rv.user_id
       WHERE rv.restaurant_id = ${restaurantId}::uuid
         AND rv.status = 'published'
         AND (${cursor}::timestamptz IS NULL OR rv.created_at < ${cursor}::timestamptz)
       ORDER BY rv.created_at DESC
       LIMIT ${opts.limit + 1}`;

    const page = rows.slice(0, opts.limit);
    const more = rows.length > opts.limit;

    return {
      summary: await this.summaryFor(restaurantId),
      results: page.map((r) => ({
        id: r.id,
        rating: Number(r.rating),
        food_rating: r.food_rating === null ? null : Number(r.food_rating),
        service_rating: r.service_rating === null ? null : Number(r.service_rating),
        ambience_rating: r.ambience_rating === null ? null : Number(r.ambience_rating),
        body: r.body,
        author: displayName(r.full_name),
        created_at: r.created_at.toISOString(),
        owner_reply: r.owner_reply,
        owner_replied_at: r.owner_replied_at?.toISOString() ?? null,
      })),
      next_cursor: more ? page[page.length - 1].created_at.toISOString() : null,
    };
  }

  /**
   * The star breakdown, read from `reviews` rather than from
   * `restaurants.rating_avg`.
   *
   * Those two must agree — the trigger in the migration is what makes them —
   * and reading the denormalized copy here would mean the histogram and the
   * headline number could disagree on the same screen without anything
   * noticing. `idx_reviews_rest` covers this in one pass.
   */
  private async summaryFor(restaurantId: string): Promise<ReviewSummary> {
    const rows = await this.prisma.$queryRaw<{ rating: number; n: bigint }[]>`
      SELECT rating, COUNT(*) AS n
        FROM reviews
       WHERE restaurant_id = ${restaurantId}::uuid AND status = 'published'
       GROUP BY rating`;

    const breakdown: Record<string, number> = { '1': 0, '2': 0, '3': 0, '4': 0, '5': 0 };
    let total = 0;
    let sum = 0;
    for (const r of rows) {
      const n = Number(r.n);
      breakdown[String(r.rating)] = n;
      total += n;
      sum += n * Number(r.rating);
    }

    return {
      // Rounded to the same two places the column holds, so the number here
      // and the number on the venue profile are the same string.
      rating: total === 0 ? 0 : Math.round((sum / total) * 100) / 100,
      rating_count: total,
      breakdown,
    };
  }

  /**
   * Write one. doc 06 §"Reviews": 403 unless it is the caller's own eligible
   * reservation, 409 on a duplicate.
   *
   * NO `Idempotency-Key`, and not by omission. `reservation_id` is UNIQUE, so a
   * replay cannot create a second review — the database refuses it and the
   * caller gets the 409 the contract already specifies. A key would be a second
   * mechanism for a guarantee that is already structural.
   */
  async create(input: {
    userId: string;
    reservationId: string;
    rating: number;
    foodRating?: number;
    serviceRating?: number;
    ambienceRating?: number;
    body?: string;
  }): Promise<PublicReview> {
    const reservation = await this.prisma.reservation.findFirst({
      where: { id: input.reservationId, userId: input.userId },
      select: { id: true, restaurantId: true, status: true, endsAt: true },
    });

    // A reservation that is not the caller's is a 404, not a 403 — the same
    // call `my-reservations.controller.ts` makes. A 403 would confirm the id
    // exists, which turns this into a way to test whether a reservation code
    // is real.
    if (!reservation) {
      throw new NotFoundException({
        code: 'reservation_not_found',
        message: 'We could not find that reservation.',
        message_ar: 'مش لاقيين الحجز ده.',
      });
    }

    this.assertEligible(reservation.status, reservation.endsAt);

    try {
      const created = await this.prisma.review.create({
        data: {
          reservationId: reservation.id,
          userId: input.userId,
          restaurantId: reservation.restaurantId,
          rating: input.rating,
          foodRating: input.foodRating ?? null,
          serviceRating: input.serviceRating ?? null,
          ambienceRating: input.ambienceRating ?? null,
          body: input.body?.trim() ? input.body.trim() : null,
        },
        include: { user: { select: { fullName: true } } },
      });

      return {
        id: created.id,
        rating: created.rating,
        food_rating: created.foodRating,
        service_rating: created.serviceRating,
        ambience_rating: created.ambienceRating,
        body: created.body,
        author: displayName(created.user.fullName),
        created_at: created.createdAt.toISOString(),
        owner_reply: created.ownerReply,
        owner_replied_at: created.ownerRepliedAt?.toISOString() ?? null,
      };
    } catch (e) {
      // CAUGHT AT THE DATABASE, not checked before. A "does one exist yet"
      // read followed by an insert has a window between the two statements,
      // and a double submit on a slow connection lands in it. The unique index
      // has no window.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'review_already_exists',
          message: 'You have already reviewed this visit.',
          message_ar: 'انت قيّمت الزيارة دي قبل كده.',
        });
      }
      throw e;
    }
  }

  /**
   * THE INVARIANT THE DATABASE CANNOT HOLD, turned into a 403.
   *
   * The rule itself is `review-eligibility.ts` — a pure function, shared with
   * `MyReservationsService.can_review` so the answer the bookings list predicts
   * cannot drift from the answer this endpoint gives. This method is only the
   * translation from "why not" to an HTTP response.
   *
   * A no-show cannot review. Neither can a cancellation, in either direction: a
   * diner whose table the venue cancelled has a complaint, and it is a real
   * one, but it is not a review of a meal they did not eat. That belongs in
   * support, which is the honest answer even though it is the less convenient
   * one.
   */
  private assertEligible(status: string, endsAt: Date): void {
    switch (reviewIneligibility(status, endsAt)) {
      case 'not_eligible':
        throw new ForbiddenException({
          code: 'review_not_eligible',
          message: 'Reviews are for visits that happened.',
          message_ar: 'التقييم بيكون للزيارات اللي حصلت فعلاً.',
        });
      case 'too_early':
        throw new ForbiddenException({
          code: 'review_too_early',
          message: 'You can review this once your table time is over.',
          message_ar: 'تقدر تقيّم بعد ما ميعاد الطاولة يخلص.',
        });
      case null:
        return;
    }
  }
}
