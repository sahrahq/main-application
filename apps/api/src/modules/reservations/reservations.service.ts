import {
  Injectable,
  Logger,
  ConflictException,
  NotFoundException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Prisma, ReservationStatus, ReservationSource } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { bookingWindow, DEFAULT_TURN_MINUTES } from './turn-time';
import { generateReservationCode } from './reservation-code';
import { HoldExpiryQueue } from './expiry/hold-expiry.queue';

/** Statuses that occupy inventory (doc 05 §2). Mirrored by idx_resv_active. */
export const LIVE_STATUSES: ReservationStatus[] = [
  ReservationStatus.held,
  ReservationStatus.pending,
  ReservationStatus.confirmed,
  ReservationStatus.seated,
];

/** Postgres error raised by the EXCLUDE constraint. */
const PG_EXCLUSION_VIOLATION = '23P01';
/** Postgres unique-violation — used by the idempotency race path. */
const PG_UNIQUE_VIOLATION = '23505';
/** Prisma: could not start an interactive transaction within maxWait. */
const PRISMA_TX_TIMEOUT = 'P2028';
/** doc 05 §3 — the Retry-After the client is told to honour. */
export const RETRY_AFTER_SECONDS = 2;

export const HOLD_TTL_MINUTES = 5;

/**
 * Pull the underlying Postgres SQLSTATE out of whatever Prisma threw.
 *
 * This is not defensive noise — it is load-bearing. Prisma reports errors from
 * `$executeRaw` as P2010 with the real SQLSTATE buried in `meta.code`, while
 * ORM-level writes surface the code directly. Our layer-3 insert IS raw, so
 * matching only on `err.code` would silently miss every single exclusion
 * violation and leak a 500 instead of a clean 409. Caught by the e2e suite.
 */
export function extractPgCode(err: unknown): string | undefined {
  const e = err as { code?: string; meta?: { code?: string; message?: string }; message?: string };
  if (e?.meta?.code) return e.meta.code;
  if (e?.code && e.code !== 'P2010') return e.code;

  // Last resort: P2010 without structured meta still names the code in text.
  const text = e?.meta?.message ?? e?.message ?? '';
  const m = /\b(23[A-Z0-9]{3})\b/.exec(text);
  return m ? m[1] : e?.code;
}

export interface CreateHoldInput {
  restaurantId: string;

  /**
   * The diner, or `null` for a staff-entered booking (R-3.2).
   *
   * **REQUIRED, AND EXPLICITLY NULLABLE. Do not make this optional again.**
   *
   * It was `userId?:` for weeks. The HTTP controller simply never passed one,
   * so every reservation created through the API had `user_id = NULL` — a
   * diner's own booking never appeared in their own `GET /reservations`, and
   * nothing anywhere objected. The service supported the field, stored it, and
   * even checked it on confirm; the layer above just never mentioned it.
   *
   * Optional meant the difference between "no account" and "I FORGOT TO SAY"
   * was invisible. Required-and-nullable makes every caller state which one it
   * means, and makes the compiler the thing that notices — which is the only
   * tool that reliably can. Two regex audits were run over this codebase
   * looking for the same shape elsewhere and BOTH were dominated by false
   * positives; a type is not.
   */
  userId: string | null;

  guestName?: string | null;
  guestPhone?: string | null;
  partySize: number;
  startsAt: Date;
  seatingPref?: 'indoor' | 'outdoor' | 'family' | 'bar' | 'private' | null;
  specialRequests?: string | null;
  occasion?: string | null;
  source?: ReservationSource;
  /**
   * Skip the hold phase and create the reservation already confirmed.
   *
   * For staff-entered bookings (walk-ins, phone) only. A party standing at the
   * podium has no checkout to abandon, so there is nothing for a 5-minute hold
   * to protect — and a crash between hold and confirm would let the sweeper
   * expire a reservation while the guests are physically at the table, which
   * is the exact double-seat walk-in support exists to prevent.
   *
   * This is a PARAMETER, not a second seating path: the advisory lock, the
   * free-table re-check and the EXCLUDE constraint are all still the ones
   * below (doc 05 §7 — "walk-ins consume the same inventory through the same
   * engine path").
   */
  confirmImmediately?: boolean;
  idempotencyKey: string;
}

interface CandidateTable {
  id: string;
  name: string;
  min_capacity: number;
  max_capacity: number;
  priority: number;
  combinable_with: string[];
}

@Injectable()
export class ReservationsService {
  private readonly logger = new Logger(ReservationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    /**
     * Optional so the service is constructible in tests and in environments
     * without Redis. Expiry still happens via the 60s sweeper — the queue is
     * the precise path, not the only one (doc 05 §4).
     */
    private readonly expiryQueue?: HoldExpiryQueue,
  ) {}

  /**
   * Create a 5-minute hold on a table (doc 05 §3).
   *
   * Three defense layers against double-booking, in order:
   *   1. pg_advisory_xact_lock on (restaurant_id, date) — serializes every
   *      booking write for one restaurant-day. Auto-released on commit OR
   *      rollback, so a crash mid-transaction cannot strand the lock.
   *   2. Free-table re-check inside the same transaction, after the lock.
   *   3. EXCLUDE USING GIST on reservation_tables(table_id, during) — the DB
   *      physically refuses an overlap even if 1 and 2 regress.
   *
   * Layer 1 is the *reason* this is correct under load; layer 3 is the reason
   * it stays correct when someone later refactors layer 1 wrongly.
   */
  async createHold(input: CreateHoldInput) {
    // ── Idempotency (doc 06 §1): same key ⇒ same reservation, never a second one.
    const prior = await this.prisma.reservation.findUnique({
      where: { idempotencyKey: input.idempotencyKey },
      include: { tables: true },
    });
    if (prior) return prior;

    if (input.partySize < 1 || input.partySize > 50) {
      throw new BadRequestException({
        code: 'invalid_party_size',
        message: 'Party size must be between 1 and 50.',
        message_ar: 'عدد الأفراد لازم يكون بين 1 و 50.',
      });
    }

    const restaurant = await this.prisma.restaurant.findUnique({
      where: { id: input.restaurantId },
      select: { id: true, pacingLimit: true, slotIntervalMin: true, status: true },
    });
    if (!restaurant) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }

    const turnConfig = await this.turnConfigFor(input.restaurantId, input.startsAt);
    const { startsAt, endsAt } = bookingWindow(input.startsAt, input.partySize, turnConfig);

    let created: string | null = null;
    try {
      const result = await this.prisma.$transaction(
        async (tx) => {
          // ══ LAYER 1 ══ serialize this restaurant-day.
          const lockKey = `${input.restaurantId}:${startsAt.toISOString().slice(0, 10)}`;
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${lockKey})::bigint)`;

          // ══ LAYER 2 ══ recompute free tables *inside* the lock.
          const allocation = await this.allocate(tx, {
            restaurantId: input.restaurantId,
            partySize: input.partySize,
            startsAt,
            endsAt,
          });

          if (allocation.length === 0) {
            throw new ConflictException({
              code: 'slot_taken',
              message: 'That time is no longer available.',
              message_ar: 'الوقت ده مابقاش متاح.',
            });
          }

          await this.assertPacing(tx, {
            restaurantId: input.restaurantId,
            startsAt,
            intervalMin: restaurant.slotIntervalMin,
            pacingLimit: restaurant.pacingLimit,
            partySize: input.partySize,
          });

          const reservation = await tx.reservation.create({
            data: {
              code: generateReservationCode(),
              restaurantId: input.restaurantId,
              userId: input.userId ?? null,
              guestName: input.guestName ?? null,
              guestPhone: input.guestPhone ?? null,
              partySize: input.partySize,
              startsAt,
              endsAt,
              status: input.confirmImmediately
                ? ReservationStatus.confirmed
                : ReservationStatus.held,
              source: input.source ?? ReservationSource.app,
              seatingPref: input.seatingPref ?? null,
              specialRequests: input.specialRequests ?? null,
              occasion: input.occasion ?? null,
              // A confirmed row has no expiry; leaving one set would arm the
              // sweeper against a booking that is already seated.
              holdExpiresAt: input.confirmImmediately
                ? null
                : new Date(Date.now() + HOLD_TTL_MINUTES * 60_000),
              idempotencyKey: input.idempotencyKey,
            },
          });

          // ══ LAYER 3 ══ `during` and `active` are set by trigger; the
          // EXCLUDE constraint fires here if anything slipped through.
          for (const table of allocation) {
            await tx.$executeRaw`
              INSERT INTO reservation_tables (reservation_id, table_id, during, active)
              VALUES (
                ${reservation.id}::uuid,
                ${table.id}::uuid,
                tstzrange(${startsAt}, ${endsAt}, '[)'),
                true
              )`;
          }

          created = reservation.id;
          return { ...reservation, tables: allocation.map((t) => ({ tableId: t.id })) };
        },
        // maxWait is how long a caller queues for a POOL CONNECTION before
        // giving up. Bookings for one restaurant-day serialize on the advisory
        // lock by design, so during an iftar burst the tail legitimately waits.
        // Too tight and a healthy queue surfaces as a 500.
        { timeout: 20_000, maxWait: 15_000 },
      );

      // AFTER commit, never inside: a job scheduled in the transaction could
      // fire against a row that then rolled back. Best-effort by design — the
      // sweeper is the guarantee (doc 05 §4).
      // Nothing to expire when the row was never held — scheduling a job for a
      // confirmed walk-in would be a no-op at best (expireOne is guarded on
      // status='held') and noise in the queue at worst.
      if (created && !input.confirmImmediately) {
        await this.expiryQueue?.scheduleExpiry(created, HOLD_TTL_MINUTES * 60_000);
      }

      return result;
    } catch (err) {
      return this.translateWriteError(err, input.idempotencyKey);
    }
  }

  /**
   * Confirm a hold (doc 06 §3, doc 05 §4).
   *
   * The whole correctness question is the race between this and the expiry
   * sweeper. Doc 05 §4: "Confirmation re-validates status='held' AND
   * hold_expires_at > now() inside its transaction, so an expired hold can
   * never be confirmed."
   *
   * That re-validation is expressed as a conditional UPDATE — `WHERE status =
   * 'held' AND hold_expires_at > now()` — evaluated by Postgres under the row
   * lock, not by us against a value we read a moment earlier. Reading first
   * and then writing would leave exactly the window the doc warns about.
   */
  async confirmHold(input: {
    holdId: string;
    userId?: string | null;
    specialRequests?: string | null;
    occasion?: string | null;
    idempotencyKey: string;
  }) {
    const existing = await this.prisma.reservation.findUnique({
      where: { id: input.holdId },
      select: { id: true, status: true, userId: true, holdExpiresAt: true },
    });
    if (!existing) throw this.reservationNotFound();

    // A caller may only confirm their own hold. Guest holds (userId null) are
    // confirmable by the session that created them, enforced at the controller.
    if (input.userId && existing.userId && existing.userId !== input.userId) {
      throw this.reservationNotFound();
    }

    // Idempotent replay: already confirmed by THIS key ⇒ return it unchanged.
    if (existing.status === ReservationStatus.confirmed) {
      const prior = await this.prisma.reservation.findFirst({
        where: { id: input.holdId, confirmIdempotencyKey: input.idempotencyKey },
      });
      if (prior) return prior;
      throw new ConflictException({
        code: 'invalid_status_transition',
        message: 'This reservation is already confirmed.',
        message_ar: 'هذا الحجز مؤكّد بالفعل.',
      });
    }

    // An already-swept hold must report hold_expired, not a generic
    // transition error (doc 06 §3). The distinction is the whole message to
    // the diner: "your five minutes ran out, pick another time" is actionable;
    // "invalid status transition" tells them nothing. Reached whenever the
    // sweeper or the delayed job won the race before the confirm arrived.
    if (existing.status === ReservationStatus.expired) {
      throw new ConflictException({
        code: 'hold_expired',
        message: 'That hold expired. Please pick a time again.',
        message_ar: 'انتهت مهلة الحجز المؤقت. اختر وقتًا من جديد.',
      });
    }

    if (existing.status !== ReservationStatus.held) {
      throw new ConflictException({
        code: 'invalid_status_transition',
        message: `A reservation can only be confirmed from a hold (this one is ${existing.status}).`,
        message_ar: 'لا يمكن تأكيد الحجز إلا وهو في حالة انتظار.',
      });
    }

    // Postgres evaluates the guard under the row lock — this is the atomic
    // step. If the sweeper won, count is 0 and nothing was written.
    const claimed = await this.prisma.$executeRaw`
      UPDATE reservations
         SET status = 'confirmed',
             hold_expires_at = NULL,
             special_requests = COALESCE(${input.specialRequests ?? null}, special_requests),
             occasion = COALESCE(${input.occasion ?? null}, occasion),
             confirm_idempotency_key = ${input.idempotencyKey}::uuid,
             version = version + 1,
             updated_at = now()
       WHERE id = ${input.holdId}::uuid
         AND status = 'held'
         AND hold_expires_at > now()`;

    if (claimed === 0) {
      // Distinguish "it lapsed" from "someone else moved it" for the client.
      const now = await this.prisma.reservation.findUnique({
        where: { id: input.holdId },
        select: { status: true, holdExpiresAt: true },
      });
      const lapsed =
        now?.status === ReservationStatus.expired ||
        (now?.holdExpiresAt != null && now.holdExpiresAt.getTime() <= Date.now());

      throw new ConflictException(
        lapsed
          ? {
              code: 'hold_expired',
              message: 'That hold expired. Please pick a time again.',
              message_ar: 'انتهت مهلة الحجز المؤقت. اختر وقتًا من جديد.',
            }
          : {
              code: 'invalid_status_transition',
              message: 'This reservation can no longer be confirmed.',
              message_ar: 'لم يعد من الممكن تأكيد هذا الحجز.',
            },
      );
    }

    return this.prisma.reservation.findUniqueOrThrow({ where: { id: input.holdId } });
  }

  /**
   * C-3.4 — the DINER moves their own booking.
   *
   * ── WHY THIS IS A BOOKING WRITE, NOT AN UPDATE ──────────────────────────
   *
   * It is tempting to read a modify as "change two columns". It is not: it
   * releases inventory and takes different inventory, which is exactly what
   * `createHold` does, so it runs through the same three layers or it is a
   * double-booking with a friendlier name.
   *
   * ── THE ORDER INSIDE THE LOCK, WHICH IS THE WHOLE PROBLEM ───────────────
   *
   * A reservation can collide with ITSELF. Moving 19:00 → 20:00 with a
   * 90-minute turn asks for 17:00–18:30Z while still holding 16:00–17:30Z on
   * the same table. So the old allocation is DELETED first, inside the lock,
   * before the re-check runs — otherwise the EXCLUDE constraint rejects a move
   * that is obviously legal, and it does so only for overlapping moves, which
   * is the subset least likely to be tried by hand.
   *
   * DELETE rather than `active = false`: the triggers own that column, and
   * `sahra_resv_propagate` would set it straight back to true on the very next
   * status/window update. A column with a trigger owner has no second owner.
   *
   * ── AND WHY THE WHOLE THING IS ONE TRANSACTION ──────────────────────────
   *
   * If the re-check fails after the delete, the rollback puts the original
   * allocation back. A diner whose modify was refused must still have the
   * table they already had — the alternative is a confirmed reservation seated
   * nowhere, which is worse than the change they were denied.
   *
   * ── NO IDEMPOTENCY-KEY, DELIBERATELY (CLAUDE.md rule 2) ─────────────────
   *
   * The rule covers mutations that CREATE or COMMIT a reservation. This one
   * does neither: it names absolute values, so replaying it lands on the same
   * window with the same party, and no retry can produce a second row. That is
   * idempotency by construction rather than by bookkeeping, and it is the
   * reason this route needs no third key column. Pinned in
   * `idempotency-contract.spec.ts` with that reasoning attached — if the shape
   * ever becomes relative ("move by 30 minutes") the argument collapses and
   * the key becomes mandatory.
   */
  async modifyOwn(input: {
    reservationId: string;
    userId: string;
    startsAt?: Date;
    partySize?: number;
  }) {
    const existing = await this.prisma.reservation.findFirst({
      where: { id: input.reservationId, userId: input.userId },
      select: {
        id: true,
        restaurantId: true,
        status: true,
        startsAt: true,
        partySize: true,
      },
    });

    // 404 for another diner's booking, byte-identical to one that exists for
    // nobody — the ownership rule already established on the reads.
    if (!existing) throw this.reservationNotFound();

    if (
      existing.status !== ReservationStatus.confirmed &&
      existing.status !== ReservationStatus.pending
    ) {
      throw new ConflictException({
        code: 'invalid_status_transition',
        message: `This reservation is ${existing.status.replace(/_/g, ' ')} and cannot be changed.`,
        message_ar: 'الحجز ده مش في حالة تسمح بالتعديل.',
        details: [{ field: 'status', issue: existing.status }],
      });
    }

    // A booking whose time has passed is not a thing to move — the party
    // either arrived or did not, and both of those are the venue's call now.
    // Distinct from the status refusal above because the diner's next step is
    // different: book again, rather than nothing.
    if (existing.startsAt.getTime() <= Date.now()) {
      throw new ConflictException({
        code: 'reservation_not_modifiable',
        message: 'That booking has already started. Please make a new one.',
        message_ar: 'الحجز ده بدأ خلاص. من فضلك اعمل حجز جديد.',
      });
    }

    const partySize = input.partySize ?? existing.partySize;
    const requestedStart = input.startsAt ?? existing.startsAt;

    const turnConfig = await this.turnConfigFor(existing.restaurantId, requestedStart);
    const { startsAt, endsAt } = bookingWindow(requestedStart, partySize, turnConfig);

    const restaurant = await this.prisma.restaurant.findUnique({
      where: { id: existing.restaurantId },
      select: { pacingLimit: true, slotIntervalMin: true },
    });

    try {
      return await this.prisma.$transaction(
        async (tx) => {
          // ══ LAYER 1 ══ the restaurant-day being ALLOCATED into.
          //
          // Only the target day. Releasing the old allocation can never create
          // an overlap — it only ever gives inventory back — so serialising
          // the old day would buy nothing and introduce a two-lock ordering
          // problem across a date change, which is how deadlocks are written.
          const lockKey = `${existing.restaurantId}:${startsAt.toISOString().slice(0, 10)}`;
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${lockKey})::bigint)`;

          // Release FIRST, so the re-check does not see this reservation as
          // its own competitor. Rolled back with everything else if the move
          // is refused below.
          await tx.$executeRaw`
            DELETE FROM reservation_tables WHERE reservation_id = ${existing.id}::uuid`;

          // ══ LAYER 2 ══ recompute free tables inside the lock.
          const allocation = await this.allocate(tx, {
            restaurantId: existing.restaurantId,
            partySize,
            startsAt,
            endsAt,
          });

          if (allocation.length === 0) {
            throw new ConflictException({
              code: 'slot_taken',
              message: 'That time is no longer available.',
              message_ar: 'الوقت ده مابقاش متاح.',
            });
          }

          await this.assertPacing(tx, {
            restaurantId: existing.restaurantId,
            startsAt,
            intervalMin: restaurant?.slotIntervalMin ?? 15,
            pacingLimit: restaurant?.pacingLimit ?? null,
            partySize,
            // ITS OWN COVERS DO NOT COUNT AGAINST IT. Without this a party of
            // four at a venue paced to four could not change its own booking
            // by five minutes: the pacing query would find the reservation
            // being moved sitting in the target bucket and refuse to make room
            // for the thing already occupying it.
            excludeReservationId: existing.id,
          });

          // Written BEFORE the new allocation rows, because
          // `sahra_resv_table_sync` reads `starts_at`/`ends_at` off this row
          // to compute `during`. Insert first and the EXCLUDE constraint is
          // checked against the OLD window.
          await tx.$executeRaw`
            UPDATE reservations
               SET starts_at = ${startsAt},
                   ends_at   = ${endsAt},
                   party_size = ${partySize},
                   version    = version + 1,
                   updated_at = now()
             WHERE id = ${existing.id}::uuid`;

          // ══ LAYER 3 ══ the EXCLUDE constraint fires here if 1–2 regressed.
          for (const table of allocation) {
            await tx.$executeRaw`
              INSERT INTO reservation_tables (reservation_id, table_id, during, active)
              VALUES (
                ${existing.id}::uuid,
                ${table.id}::uuid,
                tstzrange(${startsAt}, ${endsAt}, '[)'),
                true
              )`;
          }

          return { id: existing.id };
        },
        { timeout: 20_000, maxWait: 15_000 },
      );
    } catch (err) {
      if (err instanceof ConflictException) throw err;
      return this.translateWriteError(err, `modify:${input.reservationId}`);
    }
  }

  /**
   * C-3.5 — the DINER cancels their own booking.
   *
   * A SEPARATE DOOR FROM THE VENUE'S, and it must stay that way. The actor on
   * the row is what the entire acknowledgement model keys off: a booking the
   * diner cancelled leaves their upcoming list at once, and one the RESTAURANT
   * cancelled stays visible until they have actually seen it. One handler with
   * a role branch inside would be one refactor from recording the wrong one.
   *
   * ── NO TIME LIMIT ON CANCELLING, DELIBERATELY ───────────────────────────
   *
   * A diner who cannot cancel a booking that starts in ten minutes does not
   * become a diner who attends. They become a no-show, and the venue learns
   * about the empty table when it stays empty. Refusing a late cancellation
   * manufactures the exact outcome the feature exists to prevent, so the only
   * bar is the status: it must still be a booking somebody could turn up for.
   *
   * `seated` is excluded — you are at the table. What follows is `completed`
   * or a conversation with the staff, not a cancellation.
   *
   * NOT IMPLEMENTED, AND SAID PLAINLY: doc 02 C-3.5 also wants "policy
   * display" and late-cancel tracking per user. There is no cancellation
   * window on `restaurants` and no late-cancel counter on `users` — both are
   * migrations, and R-2.1 owns the first. Logged rather than improvised.
   */
  async cancelOwn(input: {
    reservationId: string;
    userId: string;
    reason?: string | null;
  }): Promise<void> {
    // Conditional UPDATE, so two taps race in Postgres rather than in us:
    // exactly one writes and the loser reads the same 409 as a late retry.
    const cancelled = await this.prisma.$executeRaw`
      UPDATE reservations
         SET status        = 'cancelled_by_user',
             cancelled_at  = now(),
             cancel_reason = ${input.reason ?? null},
             version       = version + 1,
             updated_at    = now()
       WHERE id      = ${input.reservationId}::uuid
         AND user_id = ${input.userId}::uuid
         AND status::text IN ('pending', 'confirmed')`;

    if (cancelled === 1) return;

    // Nothing was written. Two situations, and only one of them may be named.
    const existing = await this.prisma.reservation.findFirst({
      where: { id: input.reservationId, userId: input.userId },
      select: { status: true },
    });

    // Someone else's, or nobody's. The same answer for both.
    if (!existing) throw this.reservationNotFound();

    throw new ConflictException({
      code: 'invalid_status_transition',
      message: `This reservation is ${existing.status.replace(/_/g, ' ')} and cannot be cancelled.`,
      message_ar: 'الحجز ده مش في حالة تسمح بالإلغاء.',
      details: [{ field: 'status', issue: existing.status }],
    });
  }

  private reservationNotFound(): NotFoundException {
    return new NotFoundException({
      code: 'reservation_not_found',
      message: 'Reservation not found.',
      message_ar: 'الحجز غير موجود.',
    });
  }

  /**
   * Best-fit allocation (doc 05 §2): tightest capacity fit first, then the
   * restaurant's own priority. Falls back to a 2-table combination.
   *
   * The NOT EXISTS against reservation_tables is the authoritative free check —
   * it reads the same `during`/`active` columns the EXCLUDE constraint guards,
   * so the re-check and the constraint can never disagree about what "free" means.
   */
  private async allocate(
    tx: Prisma.TransactionClient,
    args: { restaurantId: string; partySize: number; startsAt: Date; endsAt: Date },
  ): Promise<CandidateTable[]> {
    const single = await tx.$queryRaw<CandidateTable[]>`
      SELECT t.id, t.name, t.min_capacity, t.max_capacity, t.priority, t.combinable_with
      FROM tables t
      WHERE t.restaurant_id = ${args.restaurantId}::uuid
        AND t.active
        AND t.max_capacity >= ${args.partySize}
        AND t.min_capacity <= ${args.partySize}
        AND NOT EXISTS (
          SELECT 1 FROM reservation_tables rt
          WHERE rt.table_id = t.id
            AND rt.active
            AND rt.during && tstzrange(${args.startsAt}, ${args.endsAt}, '[)')
        )
      ORDER BY (t.max_capacity - ${args.partySize}) ASC, t.priority ASC, t.name ASC
      LIMIT 1`;

    if (single.length > 0) return [single[0]];

    // ── Combination fallback: 2 tables max at MVP (doc 05 §2).
    const free = await tx.$queryRaw<CandidateTable[]>`
      SELECT t.id, t.name, t.min_capacity, t.max_capacity, t.priority, t.combinable_with
      FROM tables t
      WHERE t.restaurant_id = ${args.restaurantId}::uuid
        AND t.active
        AND cardinality(t.combinable_with) > 0
        AND NOT EXISTS (
          SELECT 1 FROM reservation_tables rt
          WHERE rt.table_id = t.id
            AND rt.active
            AND rt.during && tstzrange(${args.startsAt}, ${args.endsAt}, '[)')
        )
      ORDER BY t.priority ASC, t.name ASC`;

    const byId = new Map(free.map((t) => [t.id, t]));
    let best: { pair: CandidateTable[]; waste: number } | null = null;

    for (const t1 of free) {
      for (const otherId of t1.combinable_with ?? []) {
        const t2 = byId.get(otherId);
        if (!t2 || t2.id === t1.id) continue;

        const maxSum = t1.max_capacity + t2.max_capacity;
        const minSum = t1.min_capacity + t2.min_capacity;
        if (args.partySize > maxSum || args.partySize < minSum) continue;

        const waste = maxSum - args.partySize;
        if (!best || waste < best.waste) best = { pair: [t1, t2], waste };
      }
    }

    return best ? best.pair : [];
  }

  /**
   * Pacing (doc 05 §2): refuse a slot when the kitchen already has
   * `pacing_limit` covers starting in the same interval — even if tables are
   * free. This is what keeps iftar service from collapsing at 18:10.
   */
  private async assertPacing(
    tx: Prisma.TransactionClient,
    args: {
      restaurantId: string;
      startsAt: Date;
      intervalMin: number;
      pacingLimit: number | null;
      partySize: number;
      /**
       * A reservation whose covers must NOT count against the limit — the one
       * being moved. Its party is already in `args.partySize`, so leaving it
       * in the sum counts the same diners twice and refuses a modify on the
       * strength of the booking being modified.
       */
      excludeReservationId?: string;
    },
  ): Promise<void> {
    if (args.pacingLimit == null) return;

    const intervalMs = args.intervalMin * 60_000;
    const bucketStart = new Date(Math.floor(args.startsAt.getTime() / intervalMs) * intervalMs);
    const bucketEnd = new Date(bucketStart.getTime() + intervalMs);

    const rows = await tx.$queryRaw<{ covers: bigint | null }[]>`
      SELECT COALESCE(SUM(party_size), 0) AS covers
      FROM reservations
      WHERE restaurant_id = ${args.restaurantId}::uuid
        AND status IN ('held', 'pending', 'confirmed', 'seated')
        AND starts_at >= ${bucketStart}
        AND starts_at <  ${bucketEnd}
        AND id IS DISTINCT FROM ${args.excludeReservationId ?? null}::uuid`;

    const existing = Number(rows[0]?.covers ?? 0);
    if (existing + args.partySize > args.pacingLimit) {
      throw new ConflictException({
        code: 'pacing_limit_reached',
        message: 'The kitchen is at capacity for that time. Try a nearby slot.',
        message_ar: 'المطبخ محجوز بالكامل في الوقت ده. جرّب وقت قريب.',
      });
    }
  }

  /** Turn-time config from the shift covering this datetime, else the default. */
  private async turnConfigFor(
    restaurantId: string,
    at: Date,
  ): Promise<Record<string, number>> {
    const dow = at.getUTCDay();
    const onDate = new Date(`${at.toISOString().slice(0, 10)}T00:00:00.000Z`);

    // A date-specific shift (Ramadan, a holiday) overrides the weekly pattern,
    // so look for one first rather than relying on NULLS ordering.
    const specific = await this.prisma.shift.findFirst({
      where: { restaurantId, active: true, specificDate: onDate },
      select: { defaultTurnMinutes: true },
    });

    const weekly = specific
      ? null
      : await this.prisma.shift.findFirst({
          where: { restaurantId, active: true, dayOfWeek: dow },
          select: { defaultTurnMinutes: true },
        });

    const cfg = (specific ?? weekly)?.defaultTurnMinutes as Record<string, number> | undefined;
    return cfg && Object.keys(cfg).length > 0 ? cfg : DEFAULT_TURN_MINUTES;
  }

  /**
   * Turn raw Postgres failures into the bilingual error envelope (doc 06 §1).
   *
   * 23P01 means layer 3 caught what layers 1–2 missed. That is a *correct*
   * outcome for the diner (no double-booking) but a defect signal for us —
   * log it loudly.
   */
  private translateWriteError(err: unknown, idempotencyKey: string): never {
    const code = extractPgCode(err);

    // doc 05 §3: "Acquire lock restaurant:date, timeout 3s" → "503 retry-after".
    // P2028 means we never got into the transaction — no reservation was
    // written and nothing is half-done, so this is safely retryable. Returning
    // 500 here would tell a client that succeeded-or-not is unknowable, when
    // in fact nothing happened at all.
    if ((err as { code?: string })?.code === PRISMA_TX_TIMEOUT) {
      this.logger.warn(
        `Lock/transaction wait exceeded for idempotencyKey=${idempotencyKey}; ` +
          `advising retry. Sustained occurrences mean the pool is undersized.`,
      );
      throw new HttpException(
        {
          code: 'service_busy',
          message: 'That restaurant is busy right now. Please try again in a moment.',
          message_ar: 'المطعم مزحوم دلوقتي. حاول تاني بعد لحظات.',
          retry_after: RETRY_AFTER_SECONDS,
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    if (code === PG_EXCLUSION_VIOLATION) {
      this.logger.error(
        `EXCLUDE constraint caught an overlap that layers 1-2 let through ` +
          `(idempotencyKey=${idempotencyKey}). Investigate the lock path.`,
      );
      throw new ConflictException({
        code: 'slot_taken',
        message: 'That time is no longer available.',
        message_ar: 'الوقت ده مابقاش متاح.',
      });
    }

    if (code === PG_UNIQUE_VIOLATION) {
      // Two identical requests raced past the idempotency read. The loser
      // reports the winner's outcome rather than a spurious error.
      throw new ConflictException({
        code: 'duplicate_request',
        message: 'This request was already processed.',
        message_ar: 'الطلب ده اتنفذ قبل كده.',
      });
    }

    throw err as Error;
  }
}
