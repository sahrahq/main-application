import {
  Injectable,
  Logger,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { Prisma, ReservationStatus, ReservationSource } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { bookingWindow, DEFAULT_TURN_MINUTES } from './turn-time';
import { generateReservationCode } from './reservation-code';

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
  userId?: string | null;
  guestName?: string | null;
  guestPhone?: string | null;
  partySize: number;
  startsAt: Date;
  seatingPref?: 'indoor' | 'outdoor' | 'family' | 'bar' | 'private' | null;
  specialRequests?: string | null;
  occasion?: string | null;
  source?: ReservationSource;
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

  constructor(private readonly prisma: PrismaService) {}

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

    try {
      return await this.prisma.$transaction(
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
              status: ReservationStatus.held,
              source: input.source ?? ReservationSource.app,
              seatingPref: input.seatingPref ?? null,
              specialRequests: input.specialRequests ?? null,
              occasion: input.occasion ?? null,
              holdExpiresAt: new Date(Date.now() + HOLD_TTL_MINUTES * 60_000),
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

          return { ...reservation, tables: allocation.map((t) => ({ tableId: t.id })) };
        },
        { timeout: 10_000, maxWait: 5_000 },
      );
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
        AND starts_at <  ${bucketEnd}`;

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
