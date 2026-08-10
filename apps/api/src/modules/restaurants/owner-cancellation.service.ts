import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { LIVE_STATUSES } from './venue-config.guards';

export interface CancelledReservation {
  id: string;
  code: string;
  status: string;
  cancelled_at: string;
  cancel_reason: string;
  starts_at: string;
  party_size: number;
  /** For the notification the caller emits. Null for a walk-in. */
  user_id: string | null;
  restaurant_id: string;
}

/**
 * A restaurant cancels a booking — doc 06 §4.
 *
 * **doc 06 §4 HAS NO CANCEL ROW.** `accept`, `decline`, `seat`, `no-show`,
 * `complete` and `transfer` are all there; cancel is not. Its absence is why
 * the whole diner-side acknowledgement model — a migration, a partial index,
 * an endpoint and six tests — shipped ahead of anything that could set
 * `cancelled_by_restaurant`. Correct machinery that had never once run from
 * its actual cause.
 *
 * A venue with a burst pipe or a double-booked private room has to be able to
 * tell us. Without this they telephone the diner if they have the number and
 * simply do not seat them if they do not, and every one of those becomes a
 * SAHRA problem that SAHRA never saw.
 */
@Injectable()
export class OwnerCancellationService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Cancel [reservationId], which must belong to a venue owned by [ownerId].
   *
   * Ownership is IN THE UPDATE, not a check before it. A find-then-update
   * would leave a window where the row changed hands between the two
   * statements, and more importantly it is the shape that eventually forgets
   * to check at all.
   */
  async cancel(
    ownerId: string,
    reservationId: string,
    reason: string,
  ): Promise<CancelledReservation> {
    // Conditional UPDATE, so concurrency is settled by Postgres rather than by
    // hoping two staff do not tap at once: the status predicate means exactly
    // one of them writes, and the loser sees the same 409 as a late retry.
    const updated = await this.prisma.$queryRaw<
      {
        id: string;
        code: string;
        status: string;
        cancelled_at: Date;
        cancel_reason: string;
        starts_at: Date;
        party_size: number;
        user_id: string | null;
        restaurant_id: string;
      }[]
    >`
      UPDATE reservations res
         SET status       = 'cancelled_by_restaurant',
             cancelled_at = now(),
             cancel_reason = ${reason},
             version      = res.version + 1
         -- No updated_at here either, deliberately. It is set by
         -- trg_touch_updated_at, and this statement is the OTHER one that used
         -- to forget — the venue cancelling a booking, which left the column
         -- reading from before the cancellation.
        FROM restaurants r
       WHERE res.id            = ${reservationId}::uuid
         AND r.id              = res.restaurant_id
         AND r.owner_id        = ${ownerId}::uuid
         AND r.deleted_at IS NULL
         AND res.status::text  = ANY(${[...LIVE_STATUSES]})
      RETURNING res.id, res.code, res.status::text AS status,
                res.cancelled_at, res.cancel_reason, res.starts_at,
                res.party_size, res.user_id, res.restaurant_id`;

    if (updated.length === 1) {
      const r = updated[0];
      return {
        id: r.id,
        code: r.code,
        status: r.status,
        cancelled_at: r.cancelled_at.toISOString(),
        cancel_reason: r.cancel_reason,
        starts_at: r.starts_at.toISOString(),
        party_size: r.party_size,
        user_id: r.user_id,
        restaurant_id: r.restaurant_id,
      };
    }

    // Nothing was updated. Three different situations, and only two of them
    // may be distinguished from each other.
    const existing = await this.prisma.$queryRaw<{ status: string }[]>`
      SELECT res.status::text AS status
        FROM reservations res
        JOIN restaurants  r ON r.id = res.restaurant_id
       WHERE res.id     = ${reservationId}::uuid
         AND r.owner_id = ${ownerId}::uuid
         AND r.deleted_at IS NULL`;

    if (existing.length === 0) {
      // Belongs to somebody else, or does not exist. **The same answer for
      // both**, deliberately: an owner who could tell them apart could
      // enumerate the platform's reservations, and could confirm that a
      // competitor holds a booking at a given id.
      throw new NotFoundException({
        code: 'reservation_not_found',
        message: 'We could not find that reservation.',
        message_ar: 'مش لاقيين الحجز ده.',
      });
    }

    // Theirs, but already settled — cancelled, completed, no-show or expired.
    // A second cancel must not overwrite the reason the diner is about to
    // read, so this fails rather than re-applying.
    throw new ConflictException({
      code: 'invalid_status_transition',
      message: `This reservation is ${existing[0].status.replace(/_/g, ' ')} and cannot be cancelled.`,
      message_ar: 'الحجز ده مش في حالة تسمح بالإلغاء.',
      details: [{ field: 'status', issue: existing[0].status }],
    });
  }
}
