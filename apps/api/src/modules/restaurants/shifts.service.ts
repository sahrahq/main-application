import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { DEFAULT_TURN_MINUTES } from '../reservations/turn-time';
import { zonedWallTimeToUtc, isValidTimeZone } from '../../shared/time/timezone';
import { assertOwned, badRequest, hhmm, minutesOf, toTime, LIVE_STATUSES } from './venue-config.guards';

export interface CreateShiftInput {
  nameEn: string;
  nameAr: string;
  /** 0–6. Exactly one of this or specificDate. */
  dayOfWeek?: number;
  /** YYYY-MM-DD. Exactly one of this or dayOfWeek. */
  specificDate?: string;
  /** HH:MM, restaurant wall clock. */
  opensAt: string;
  closesAt: string;
  spansMidnight?: boolean;
  defaultTurnMinutes?: Record<string, number>;
  isRamadan?: boolean;
  active?: boolean;
}

export type UpdateShiftInput = Partial<CreateShiftInput>;

export interface ShiftRow {
  id: string;
  nameEn: string;
  nameAr: string;
  dayOfWeek: number | null;
  specificDate: string | null;
  opensAt: string;
  closesAt: string;
  spansMidnight: boolean;
  defaultTurnMinutes: Record<string, number>;
  isRamadan: boolean;
  active: boolean;
}

/** What an hours change did, and who it left stranded. */
export interface ShiftWriteResult {
  shift: ShiftRow;
  /** Live future bookings that now fall outside the shift. Never cancelled. */
  reservationsOutsideHours: string[];
}

interface AffectedRow {
  id: string;
  starts_at: Date;
}

/**
 * Opening hours and shifts (R-2.4).
 *
 * A shift is the only thing that says when a restaurant is open, so the
 * availability grid is built entirely from these rows. Multiple shifts per
 * weekday are the normal case, not an edge case — lunch and dinner with a
 * closed afternoon between them is how most of Cairo trades.
 *
 * THE DANGEROUS EDIT is narrowing hours. A confirmed booking at 12:30 does not
 * move because the owner decided to open at 18:00 next week; the restaurant
 * already promised that table. So a narrowing change that would strand a live
 * future booking is REFUSED, and the refusal names the bookings. With `force`
 * the owner's decision is honoured and the bookings are **kept**, returned so
 * somebody can call those diners.
 *
 * What this never does is auto-cancel. The platform did not make that promise
 * and cannot unmake it — a diner turning up to find their booking silently
 * gone is worse than any config friction.
 *
 * NOT IMPLEMENTED: Ramadan mode. `isRamadan` is persisted so the data model is
 * ready, but R-2.4's iftar-pegged-to-Maghrib behaviour needs a prayer-time
 * source and a daily recompute. Deliberately absent rather than half-built.
 */
@Injectable()
export class ShiftsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(ownerId: string, restaurantId: string): Promise<ShiftRow[]> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    const rows = await this.prisma.shift.findMany({
      where: { restaurantId },
      orderBy: [{ dayOfWeek: 'asc' }, { specificDate: 'asc' }, { opensAt: 'asc' }],
    });
    return rows.map(toRow);
  }

  async get(ownerId: string, restaurantId: string, shiftId: string): Promise<ShiftRow> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    const s = await this.prisma.shift.findFirst({ where: { id: shiftId, restaurantId } });
    if (!s) throw this.notFound();
    return toRow(s);
  }

  async create(
    ownerId: string,
    restaurantId: string,
    input: CreateShiftInput,
  ): Promise<ShiftRow> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    this.assertScope(input.dayOfWeek, input.specificDate);
    const { opens, closes, spans } = this.assertHours(
      input.opensAt, input.closesAt, input.spansMidnight,
    );
    await this.assertNoOverlap(restaurantId, input, opens, closes, spans);

    const created = await this.prisma.shift.create({
      data: {
        restaurantId,
        nameEn: input.nameEn,
        nameAr: input.nameAr,
        dayOfWeek: input.dayOfWeek ?? null,
        specificDate: input.specificDate ? new Date(`${input.specificDate}T00:00:00.000Z`) : null,
        opensAt: opens,
        closesAt: closes,
        spansMidnight: spans,
        defaultTurnMinutes: (input.defaultTurnMinutes ?? DEFAULT_TURN_MINUTES) as Prisma.InputJsonValue,
        isRamadan: input.isRamadan ?? false,
        active: input.active ?? true,
      },
    });
    return toRow(created);
  }

  /**
   * Change a shift. `force` is the owner overriding the stranded-booking guard
   * — it changes what happens to the SHIFT, never to the bookings.
   */
  async update(
    ownerId: string,
    restaurantId: string,
    shiftId: string,
    input: UpdateShiftInput,
    opts: { force?: boolean } = {},
  ): Promise<ShiftWriteResult> {
    const restaurant = await assertOwned(this.prisma, ownerId, restaurantId);
    const current = await this.prisma.shift.findFirst({ where: { id: shiftId, restaurantId } });
    if (!current) throw this.notFound();

    const nextDow = input.dayOfWeek !== undefined ? input.dayOfWeek : current.dayOfWeek ?? undefined;
    const nextDate =
      input.specificDate !== undefined
        ? input.specificDate
        : current.specificDate?.toISOString().slice(0, 10);
    if (input.dayOfWeek !== undefined || input.specificDate !== undefined) {
      this.assertScope(nextDow, nextDate);
    }

    const { opens, closes, spans } = this.assertHours(
      input.opensAt ?? hhmm(current.opensAt),
      input.closesAt ?? hhmm(current.closesAt),
      input.spansMidnight ?? current.spansMidnight,
    );
    await this.assertNoOverlap(
      restaurantId,
      { dayOfWeek: nextDow, specificDate: nextDate },
      opens, closes, spans, shiftId,
    );

    // Who would this leave outside the new window?
    const stranded = await this.strandedBy(
      restaurantId, current, restaurant.timezone, opens, closes, spans,
      input.active === false,
    );
    if (stranded.length && !opts.force) throw this.strandedConflict(stranded);

    const updated = await this.prisma.shift.update({
      where: { id: shiftId },
      data: {
        ...(input.nameEn !== undefined ? { nameEn: input.nameEn } : {}),
        ...(input.nameAr !== undefined ? { nameAr: input.nameAr } : {}),
        ...(input.dayOfWeek !== undefined ? { dayOfWeek: input.dayOfWeek } : {}),
        ...(input.specificDate !== undefined
          ? { specificDate: new Date(`${input.specificDate}T00:00:00.000Z`) }
          : {}),
        ...(input.opensAt !== undefined ? { opensAt: opens } : {}),
        ...(input.closesAt !== undefined ? { closesAt: closes } : {}),
        ...(input.spansMidnight !== undefined ? { spansMidnight: spans } : {}),
        ...(input.defaultTurnMinutes !== undefined
          ? { defaultTurnMinutes: input.defaultTurnMinutes as Prisma.InputJsonValue }
          : {}),
        ...(input.isRamadan !== undefined ? { isRamadan: input.isRamadan } : {}),
        ...(input.active !== undefined ? { active: input.active } : {}),
      },
    });

    return { shift: toRow(updated), reservationsOutsideHours: stranded.map((r) => r.id) };
  }

  /**
   * Delete a shift. Same guard as narrowing hours to nothing — because that is
   * exactly what it is.
   */
  async remove(
    ownerId: string,
    restaurantId: string,
    shiftId: string,
    opts: { force?: boolean } = {},
  ): Promise<{ deleted: true; reservationsOutsideHours: string[] }> {
    const restaurant = await assertOwned(this.prisma, ownerId, restaurantId);
    const current = await this.prisma.shift.findFirst({ where: { id: shiftId, restaurantId } });
    if (!current) throw this.notFound();

    const stranded = await this.strandedBy(
      restaurantId, current, restaurant.timezone, current.opensAt, current.closesAt,
      current.spansMidnight, true,
    );
    if (stranded.length && !opts.force) throw this.strandedConflict(stranded);

    await this.prisma.shift.delete({ where: { id: shiftId } });
    return { deleted: true, reservationsOutsideHours: stranded.map((r) => r.id) };
  }

  // ─────────────────────────────────────────────────────────── validation ──

  private assertScope(dayOfWeek?: number, specificDate?: string): void {
    const hasDow = dayOfWeek !== undefined && dayOfWeek !== null;
    const hasDate = specificDate !== undefined && specificDate !== null;
    if (hasDow === hasDate) {
      throw badRequest(
        'invalid_shift_scope',
        'A shift is either weekly (day_of_week) or one-off (specific_date) — exactly one.',
        'الوردية إما أسبوعية أو بتاريخ محدد — واحدة بس.',
      );
    }
    if (hasDow && (!Number.isInteger(dayOfWeek) || dayOfWeek! < 0 || dayOfWeek! > 6)) {
      throw badRequest(
        'invalid_shift_scope',
        'day_of_week must be 0–6 (Sunday–Saturday).',
        'يوم الأسبوع لازم يكون رقم من 0 لـ 6.',
      );
    }
    if (hasDate && !/^\d{4}-\d{2}-\d{2}$/.test(specificDate!)) {
      throw badRequest(
        'invalid_shift_scope',
        'specific_date must be YYYY-MM-DD.',
        'التاريخ لازم يكون بصيغة YYYY-MM-DD.',
      );
    }
  }

  private assertHours(
    opensAt: string,
    closesAt: string,
    spansMidnight?: boolean,
  ): { opens: Date; closes: Date; spans: boolean } {
    const opens = toTime(opensAt, 'invalid_shift_hours');
    const closes = toTime(closesAt, 'invalid_shift_hours');
    const spans = spansMidnight ?? minutesOf(closesAt) < minutesOf(opensAt);

    if (!spans && minutesOf(closesAt) <= minutesOf(opensAt)) {
      throw badRequest(
        'invalid_shift_hours',
        'closes_at must be after opens_at, or spans_midnight must be set.',
        'وقت القفل لازم يكون بعد وقت الفتح، أو تحدد إن الوردية بتعدّي منتصف الليل.',
      );
    }
    return { opens, closes, spans };
  }

  /**
   * Two shifts covering the same minute on the same day make the grid
   * ambiguous — each carries its own turn-time table, so the engine would have
   * to pick one arbitrarily. Reject it at write time instead.
   */
  private async assertNoOverlap(
    restaurantId: string,
    scope: { dayOfWeek?: number | null; specificDate?: string | null },
    opens: Date,
    closes: Date,
    spans: boolean,
    excludeId?: string,
  ): Promise<void> {
    const siblings = await this.prisma.shift.findMany({
      where: {
        restaurantId,
        active: true,
        ...(excludeId ? { id: { not: excludeId } } : {}),
        ...(scope.specificDate
          ? { specificDate: new Date(`${scope.specificDate}T00:00:00.000Z`) }
          : { dayOfWeek: scope.dayOfWeek ?? undefined, specificDate: null }),
      },
      select: { id: true, opensAt: true, closesAt: true, spansMidnight: true, nameEn: true },
    });

    const a = span(opens, closes, spans);
    for (const s of siblings) {
      const b = span(s.opensAt, s.closesAt, s.spansMidnight);
      if (a.start < b.end && b.start < a.end) {
        throw new ConflictException({
          code: 'shift_overlap',
          message: `These hours overlap the existing shift "${s.nameEn}".`,
          message_ar: `المواعيد دي بتتعارض مع وردية "${s.nameEn}" الموجودة.`,
          details: [{ field: 'opens_at', issue: 'conflict' }],
        });
      }
    }
  }

  // ──────────────────────────────────────────── stranded-booking analysis ──

  /**
   * Live future bookings that the shift's CURRENT hours cover but the proposed
   * hours would not.
   *
   * Only bookings on the days this shift governs are considered, and only
   * future ones — a change cannot strand a dinner that already happened.
   */
  private async strandedBy(
    restaurantId: string,
    current: { dayOfWeek: number | null; specificDate: Date | null },
    timezone: string,
    opens: Date,
    closes: Date,
    spans: boolean,
    removing: boolean,
  ): Promise<AffectedRow[]> {
    const rows = await this.prisma.$queryRaw<AffectedRow[]>`
      SELECT id, starts_at
        FROM reservations
       WHERE restaurant_id = ${restaurantId}::uuid
         AND starts_at > now()
         AND status::text = ANY(${[...LIVE_STATUSES]}::text[])
       ORDER BY starts_at ASC`;
    if (rows.length === 0) return [];

    const tz = isValidTimeZone(timezone) ? timezone : 'Africa/Cairo';

    return rows.filter((r) => {
      const date = dateInZone(r.starts_at, tz);
      // Does this shift govern that day at all?
      if (current.specificDate) {
        if (date !== current.specificDate.toISOString().slice(0, 10)) return false;
      } else if (current.dayOfWeek !== null) {
        if (new Date(`${date}T12:00:00Z`).getUTCDay() !== current.dayOfWeek) return false;
      }

      if (removing) return true;

      // Resolve the proposed window to real instants ON THAT DATE, so a DST
      // shift cannot make a booking look stranded when it is not.
      const from = zonedWallTimeToUtc(date, opens.getUTCHours(), opens.getUTCMinutes(), tz);
      let to = zonedWallTimeToUtc(date, closes.getUTCHours(), closes.getUTCMinutes(), tz);
      if (spans || to <= from) {
        const next = new Date(`${date}T00:00:00.000Z`);
        next.setUTCDate(next.getUTCDate() + 1);
        const nextDate = next.toISOString().slice(0, 10);
        to = zonedWallTimeToUtc(nextDate, closes.getUTCHours(), closes.getUTCMinutes(), tz);
      }
      const t = r.starts_at.getTime();
      return t < from.getTime() || t >= to.getTime();
    });
  }

  private strandedConflict(stranded: AffectedRow[]): ConflictException {
    return new ConflictException({
      code: 'bookings_outside_new_hours',
      message:
        `${stranded.length} confirmed booking(s) would fall outside these hours, the first on ` +
        `${stranded[0].starts_at.toISOString()}. Re-send with force to change the hours anyway — ` +
        'the bookings will be kept and returned so you can contact those guests.',
      message_ar:
        'فيه حجوزات مؤكدة هتقع بره المواعيد الجديدة. ابعت الطلب تاني مع force لو متأكد — ' +
        'الحجوزات هتفضل زي ما هي وهنرجّعها لك عشان تتواصل مع الضيوف.',
      affected_reservations: stranded.length,
      reservation_ids: stranded.map((r) => r.id),
      earliest_reservation_at: stranded[0].starts_at.toISOString(),
      details: [{ field: 'opens_at', issue: 'conflict' }],
    });
  }

  private notFound(): NotFoundException {
    return new NotFoundException({
      code: 'shift_not_found',
      message: 'Shift not found.',
      message_ar: 'الوردية غير موجودة.',
    });
  }
}

/** Minute-of-day range, unrolled past midnight so overlaps compare simply. */
function span(opens: Date, closes: Date, spansMidnight: boolean): { start: number; end: number } {
  const start = opens.getUTCHours() * 60 + opens.getUTCMinutes();
  let end = closes.getUTCHours() * 60 + closes.getUTCMinutes();
  if (spansMidnight || end <= start) end += 24 * 60;
  return { start, end };
}

function dateInZone(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(instant);
  const get = (t: string) => parts.find((p) => p.type === t)!.value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function toRow(s: {
  id: string; nameEn: string; nameAr: string; dayOfWeek: number | null;
  specificDate: Date | null; opensAt: Date; closesAt: Date; spansMidnight: boolean;
  defaultTurnMinutes: Prisma.JsonValue; isRamadan: boolean; active: boolean;
}): ShiftRow {
  return {
    id: s.id,
    nameEn: s.nameEn,
    nameAr: s.nameAr,
    dayOfWeek: s.dayOfWeek,
    specificDate: s.specificDate ? s.specificDate.toISOString().slice(0, 10) : null,
    opensAt: hhmm(s.opensAt),
    closesAt: hhmm(s.closesAt),
    spansMidnight: s.spansMidnight,
    defaultTurnMinutes: (s.defaultTurnMinutes as Record<string, number>) ?? DEFAULT_TURN_MINUTES,
    isRamadan: s.isRamadan,
    active: s.active,
  };
}
