import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../../shared/prisma/prisma.service';

export interface ExpiredHold {
  id: string;
  restaurant_id: string;
  starts_at: Date;
}

/**
 * Hold expiry (doc 05 §4).
 *
 * Without this an abandoned hold never releases: the reservation stays `held`,
 * `reservation_tables.active` stays true, and the EXCLUDE constraint keeps the
 * table locked for that window permanently. The restaurant silently loses the
 * cover. That is a broken invariant in the booking loop, not a missing extra.
 *
 * Two mechanisms, deliberately:
 *   1. A BullMQ delayed job per hold — precise, fires at the 5-minute mark.
 *   2. THIS sweeper, every 60s — "catches jobs lost to worker crashes".
 *
 * The sweeper is the one that makes the design trustworthy, because it depends
 * on nothing but the database. If Redis is flushed, the worker is killed, or a
 * job is silently dropped, the table still comes back.
 */
@Injectable()
export class HoldExpiryService {
  private readonly logger = new Logger(HoldExpiryService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Expire every lapsed hold. Returns how many were claimed.
   *
   * One statement, and the predicate is evaluated by Postgres under the row
   * lock — the same discipline as confirm. `status = 'held'` is what makes
   * this safe against the confirm race: whoever commits first wins, and the
   * loser's WHERE clause no longer matches, so a confirmed booking can never
   * be expired out from under the diner (doc 05 §4).
   *
   * Setting `status` fires trg_resv_propagate, which flips
   * reservation_tables.active to false and releases the exclusion slot — so
   * inventory is freed by the same write, never as a second step that could
   * fail independently.
   *
   * Uses idx_resv_hold_expiry (partial, WHERE status='held'), so this touches
   * only live holds rather than scanning the reservation history.
   */
  async sweep(): Promise<number> {
    const expired = await this.prisma.$queryRaw<ExpiredHold[]>`
      UPDATE reservations
         SET status = 'expired',
             hold_expires_at = NULL,
             version = version + 1,
             updated_at = now()
       WHERE status = 'held'
         AND hold_expires_at IS NOT NULL
         AND hold_expires_at < now()
      RETURNING id, restaurant_id, starts_at`;

    if (expired.length > 0) {
      this.logger.log(`Expired ${expired.length} lapsed hold(s), releasing their tables.`);
      // doc 05 §4/§5: a freed slot should offer to the waitlist next. The
      // waitlist is P1 and not built, so the slot returns to public
      // availability — which is the correct interim behaviour, not a silent gap.
    }

    return expired.length;
  }

  /**
   * Expire ONE hold — what the BullMQ delayed job calls.
   *
   * Same guarded predicate as the sweep, so a job that fires late (or twice,
   * since BullMQ guarantees at-least-once) cannot expire a hold the diner
   * confirmed in the meantime. Returns false when there was nothing to do,
   * which is the normal outcome for a hold that was confirmed on time.
   */
  async expireOne(reservationId: string): Promise<boolean> {
    const affected = await this.prisma.$executeRaw`
      UPDATE reservations
         SET status = 'expired',
             hold_expires_at = NULL,
             version = version + 1,
             updated_at = now()
       WHERE id = ${reservationId}::uuid
         AND status = 'held'
         AND hold_expires_at IS NOT NULL
         AND hold_expires_at < now()`;

    if (affected > 0) {
      this.logger.debug(`Hold ${reservationId} expired by delayed job.`);
    }
    return affected > 0;
  }
}
