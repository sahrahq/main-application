import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/** doc 05 §5 — 10 minutes. What it currently means: see the class docblock. */
export const OFFER_WINDOW_MINUTES = 10;

/** A table that just became available again. */
export interface FreedSlot {
  restaurantId: string;
  startsAt: Date;
  /** The party the freed table was holding — the capacity now going spare. */
  partySize: number;
}

interface EntryRow {
  id: string;
  user_id: string;
  desired_date: Date;
  /** The window this offer ran to. Used as the dedupe key's discriminator. */
  offer_expires_at: Date;
  name_en: string;
  name_ar: string;
}

/**
 * C-3.6 — the NOTIFY half of the waitlist. doc 05 §5.
 *
 * `WaitlistService` has said, for two batches, "nothing here offers anybody a
 * table". This is the thing that does.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHAT AN OFFER IS, AND WHAT IT IS NOT — READ THIS BEFORE CHANGING ANYTHING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * doc 05 §5 says the freed slot is withheld from public availability during the
 * offer window, "so the waiter's 10 minutes are real". **IT IS NOT WITHHELD.**
 * An offer here is a notification and a queue position; anybody may book that
 * slot in the meantime, including somebody who never joined the list.
 *
 * That is deliberate and it is argued in
 * `docs/decisions/2026-08-09-group-g-split.md` §3.1. Short version: doc 05
 * proposes a Redis marker, which would be a second source of truth for whether
 * a table is free — a question `EXCLUDE USING GIST on reservation_tables`
 * already owns. The right implementation is for the offer to create a real
 * `held` reservation, and that is a BOOKING WRITE from a background job, which
 * CLAUDE.md rule 1 says does not happen without its own concurrency test.
 *
 * ── THREE THINGS FOLLOW FROM IT, AND ALL THREE ARE DEVIATIONS ────────────
 *
 * **1. The copy must not promise a claim window.** doc 11 §4 draws "Table
 * available — claim in 10 min". `notification-copy.ts` says "Book now — it's
 * first come, first served". Sending a diner to a slot somebody else already
 * took is worse than never telling them, because they made the journey for it.
 *
 * **2. A lapsed offer returns the entry to `waiting`, NOT to `expired`.**
 * doc 05 §5 says `status='expired'` and doc 11 says the diner gets an "option
 * to rejoin" — i.e. they are out of the queue. That is the right rule for an
 * EXCLUSIVE offer: you were given a real ten-minute claim and did not take it,
 * so you go to the back. It is the wrong rule here, where the diner was told
 * about a table they never had any claim to. Losing a race is not declining an
 * offer, and dropping someone from a queue for losing one would be a punishment
 * for our missing feature. When withholding lands, this becomes `expired` and
 * doc 05 is right again.
 *
 * **3. There is no re-offer chain.** doc 05 §5's `goto loop` re-offers the slot
 * to the next waiter when an offer lapses. It cannot: ten minutes later we have
 * no idea whether that table is still free, because we never held it, and
 * telling a second diner about a table that is probably gone is the same defect
 * as the first one with an extra step. The next FREED table finds the next
 * waiter, which is the only re-offer we can honestly make.
 *
 * `waitlist-offer.e2e-spec.ts` asserts the freed slot is STILL on public
 * availability after an offer. When withholding lands, that assertion fails and
 * whoever implements it has to come and read this. A gap nobody can trip over
 * is a gap that gets forgotten.
 */
@Injectable()
export class WaitlistOfferService {
  private readonly logger = new Logger(WaitlistOfferService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * A table freed. Offer it to the top matching waiter, if there is one.
   *
   * **NEVER THROWS.** Every caller is a cancellation or an expiry — work that
   * has already committed and must not be undone because the waitlist had a
   * bad day. Same contract as `NotificationsService.notify`, and for the same
   * reason: a cancellation that rolls back is a table nobody freed.
   *
   * Returns the entry id offered, or null when nobody matched — the common
   * case, and not a problem. The slot simply returns to public availability,
   * exactly as doc 05 §5 says it should when the queue is empty.
   */
  async onSlotFreed(slot: FreedSlot): Promise<string | null> {
    try {
      return await this.offerNext(slot);
    } catch (err) {
      this.logger.error(
        `Waitlist offer failed for ${slot.restaurantId} @ ${slot.startsAt.toISOString()}: ${String(err)}`,
      );
      return null;
    }
  }

  /**
   * The `loop:` body from doc 05 §5, as one statement.
   *
   * ── WHY ONE STATEMENT AND NOT SELECT-THEN-UPDATE ────────────────────────
   *
   * Two tables freeing at the same restaurant in the same second is not
   * exotic — a party of six cancels while the venue releases a no-show. A read
   * followed by a write would let both events pick the same top entry and offer
   * it twice, the second silently overwriting the first's expiry.
   * `FOR UPDATE SKIP LOCKED` inside a CTE is doc 05 §7's stated prevention for
   * exactly this ("waitlist double-offer"), and it makes concurrent freed-slot
   * events offer to DIFFERENT waiters rather than colliding or deadlocking.
   *
   * ── THE MATCH ───────────────────────────────────────────────────────────
   *
   * `window_start <= starts_at < window_end` — the diner said which range they
   * would actually accept, and an offer outside it teaches them to ignore the
   * next one. `party_size <= freed capacity` — a table for two cannot seat the
   * six waiting behind it.
   *
   * `priority DESC, created_at ASC` — FIFO within priority, doc 05 §5.
   * Priority is zero for everyone today; loyalty tiers raise it later.
   */
  private async offerNext(slot: FreedSlot): Promise<string | null> {
    const expiresAt = new Date(Date.now() + OFFER_WINDOW_MINUTES * 60_000);

    const offered = await this.prisma.$queryRaw<EntryRow[]>`
      WITH next_up AS (
        SELECT w.id
          FROM waitlists w
         WHERE w.restaurant_id = ${slot.restaurantId}::uuid
           AND w.status        = 'waiting'
           AND w.window_start <= ${slot.startsAt}
           AND w.window_end   >  ${slot.startsAt}
           AND w.party_size   <= ${slot.partySize}
         ORDER BY w.priority DESC, w.created_at ASC
         LIMIT 1
           FOR UPDATE SKIP LOCKED
      )
      UPDATE waitlists w
         SET status           = 'offered',
             offer_expires_at = ${expiresAt}
        FROM next_up, restaurants r
       WHERE w.id = next_up.id
         AND r.id = w.restaurant_id
      RETURNING w.id, w.user_id, w.desired_date, w.offer_expires_at,
                r.name_en, r.name_ar`;

    if (offered.length === 0) return null;

    const entry = offered[0];
    await this.tell(entry, 'waitlist_offer', slot.startsAt);
    this.logger.log(
      `Offered waitlist entry ${entry.id} a table at ${slot.startsAt.toISOString()}.`,
    );
    return entry.id;
  }

  /**
   * `on offer_expiry(entry)` from doc 05 §5 — as a sweep, and returning the
   * entry to the queue rather than dropping it (see the class docblock, §2).
   *
   * ── A SWEEP, NOT A DELAYED JOB, AND THAT IS THE DIFFERENCE FROM HOLDS ───
   *
   * Hold expiry has both: a BullMQ job for precision and a 60s sweeper as the
   * backstop, because a hold that never expires locks a table forever and the
   * table is what matters. A waitlist offer locks nothing, so a late expiry
   * costs the next person some minutes and costs the restaurant nothing. One
   * mechanism is enough, and the one worth having is the one that depends on
   * nothing but Postgres.
   *
   * Reads through `idx_wait_offered_expiry`, which is partial on
   * `status = 'offered'` — doc 04 created it for exactly this sweep, and until
   * now nothing ran it.
   *
   * Returns how many offers lapsed, so "the sweeper did nothing" is an integer
   * a test can assert rather than a state it has to infer.
   */
  async expireLapsedOffers(): Promise<number> {
    // THE OLD `offer_expires_at` IS CAPTURED IN THE CTE, not read back from the
    // UPDATE. `RETURNING` gives the NEW row, where the column is already NULL —
    // and that timestamp is what discriminates one offer from the next in the
    // dedupe key. Without it, a diner offered a second table weeks later would
    // silently not be told when that one lapsed too.
    const lapsed = await this.prisma.$queryRaw<EntryRow[]>`
      WITH lapsed AS (
        SELECT w.id, w.offer_expires_at
          FROM waitlists w
         WHERE w.status = 'offered'
           AND w.offer_expires_at IS NOT NULL
           AND w.offer_expires_at < now()
           FOR UPDATE SKIP LOCKED
      )
      UPDATE waitlists w
         SET status           = 'waiting',
             offer_expires_at = NULL
        FROM lapsed, restaurants r
       WHERE w.id = lapsed.id
         AND r.id = w.restaurant_id
      RETURNING w.id, w.user_id, w.desired_date,
                lapsed.offer_expires_at,
                r.name_en, r.name_ar`;

    for (const entry of lapsed) {
      // TOLD, AND TOLD THEY ARE STILL ON THE LIST — because they are.
      //
      // The entry went back to `waiting`, so the copy says so. If this ever
      // becomes `expired` (when withholding lands), `waitlist_offer_expired`'s
      // wording has to change in the same commit: a notification that says
      // "you're still on the list" to somebody who has been dropped sends them
      // to wait for a call that will not come.
      await this.tell(entry, 'waitlist_offer_expired', null);
    }

    if (lapsed.length > 0) {
      this.logger.log(`${lapsed.length} waitlist offer(s) lapsed; entries returned to the queue.`);
    }
    return lapsed.length;
  }

  /**
   * Record the notification for one entry.
   *
   * The **expiry** notification carries a dedupe key; the **offer** does not,
   * and the asymmetry is deliberate. An expiry is emitted by a sweeper, which
   * is at-least-once — two overlapping ticks would otherwise tell one diner
   * twice. An offer is emitted by an event, and a diner genuinely offered two
   * different freed tables on the same night should hear about both.
   *
   * The key includes the offer's own expiry timestamp, so it identifies THIS
   * offer rather than this entry: an entry that returns to the queue and is
   * offered again gets told again, which is the whole point of returning it.
   */
  private async tell(
    entry: EntryRow,
    type: 'waitlist_offer' | 'waitlist_offer_expired',
    startsAt: Date | null,
  ): Promise<void> {
    const date = entry.desired_date.toISOString().slice(0, 10);
    await this.notifications.notify({
      userId: entry.user_id,
      type,
      data: {
        waitlist_id: entry.id,
        venue: entry.name_en,
        venue_ar: entry.name_ar,
        date,
        ...(startsAt
          ? {
              starts_at: startsAt.toISOString(),
              time: startsAt.toISOString().slice(11, 16),
            }
          : {}),
      },
      dedupeKey:
        type === 'waitlist_offer_expired'
          ? `waitlist_offer_expired:${entry.id}:${entry.offer_expires_at.toISOString()}`
          : undefined,
    });
  }
}
