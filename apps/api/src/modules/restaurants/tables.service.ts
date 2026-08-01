import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, TableZone } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { assertOwned, badRequest, LIVE_STATUSES } from './venue-config.guards';

export interface CreateTableInput {
  name: string;
  minCapacity: number;
  maxCapacity: number;
  zone?: TableZone | string;
  priority?: number;
  combinableWith?: string[];
}

export type UpdateTableInput = Partial<CreateTableInput> & { active?: boolean };

export interface TableRow {
  id: string;
  name: string;
  minCapacity: number;
  maxCapacity: number;
  zone: TableZone;
  priority: number;
  combinableWith: string[];
  active: boolean;
}

const SELECT = {
  id: true, name: true, minCapacity: true, maxCapacity: true,
  zone: true, priority: true, combinableWith: true, active: true,
} satisfies Prisma.TableSelect;

interface FutureBooking {
  reservation_id: string;
  starts_at: Date;
  party_size: number;
}

/**
 * Tables (R-2.5) — the inventory the reservation engine allocates from.
 *
 * Until this existed, every table on the platform had to be inserted by hand,
 * which is why the whole test suite passed while no restaurant could actually
 * be configured.
 *
 * This is also the API most able to CORRUPT the engine. A table is not a
 * config row in isolation — it is the thing a confirmed reservation is
 * standing on. Removing it, retiring it or shrinking it under a booking that
 * already exists turns a promise the restaurant made into one it cannot keep,
 * and the diner finds out at the door. Every destructive path here checks for
 * live future bookings first and refuses (doc 06 §4: "409 if deactivating a
 * table with future bookings").
 *
 * What it deliberately does NOT do is reassign or cancel anything on the
 * owner's behalf. Silently moving a booking to another table would be a
 * different promise than the one made; silently cancelling would be the
 * platform breaking it. Both belong to a human.
 */
@Injectable()
export class TablesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(ownerId: string, restaurantId: string): Promise<TableRow[]> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    return this.prisma.table.findMany({
      where: { restaurantId },
      select: SELECT,
      orderBy: [{ priority: 'asc' }, { name: 'asc' }],
    });
  }

  async get(ownerId: string, restaurantId: string, tableId: string): Promise<TableRow> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    const t = await this.prisma.table.findFirst({
      where: { id: tableId, restaurantId },
      select: SELECT,
    });
    if (!t) throw this.notFound();
    return t;
  }

  async create(
    ownerId: string,
    restaurantId: string,
    input: CreateTableInput,
  ): Promise<TableRow> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    this.assertCapacityRange(input.minCapacity, input.maxCapacity);
    await this.assertCombinable(restaurantId, input.combinableWith);

    try {
      return await this.prisma.table.create({
        data: {
          restaurantId,
          name: input.name,
          minCapacity: input.minCapacity,
          maxCapacity: input.maxCapacity,
          zone: (input.zone as TableZone) ?? TableZone.indoor,
          priority: input.priority ?? 0,
          combinableWith: input.combinableWith ?? [],
        },
        select: SELECT,
      });
    } catch (err) {
      throw this.translate(err, input.name);
    }
  }

  /**
   * Update a table, refusing anything that would break a live booking.
   *
   * Three edits are dangerous and each is checked against future reservations
   * on THIS table specifically:
   *
   *   active: false     — the table stops existing for the engine
   *   maxCapacity down  — a party already booked may no longer fit
   *   minCapacity up    — likewise, from the other end
   *
   * Everything else (name, zone, priority, combinable, widening capacity) is
   * safe: it changes how the table is described or preferred, not whether the
   * booking on it can be honoured.
   */
  async update(
    ownerId: string,
    restaurantId: string,
    tableId: string,
    input: UpdateTableInput,
  ): Promise<TableRow> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    const current = await this.prisma.table.findFirst({
      where: { id: tableId, restaurantId },
      select: { ...SELECT },
    });
    if (!current) throw this.notFound();

    const nextMin = input.minCapacity ?? current.minCapacity;
    const nextMax = input.maxCapacity ?? current.maxCapacity;
    this.assertCapacityRange(nextMin, nextMax);
    await this.assertCombinable(restaurantId, input.combinableWith, tableId);

    if (input.active === false && current.active) {
      const future = await this.futureBookings(tableId);
      if (future.length) throw this.futureBookingsConflict(future, 'retire this table');
    }

    const narrowing = nextMax < current.maxCapacity || nextMin > current.minCapacity;
    if (narrowing) {
      const future = await this.futureBookings(tableId);
      const wontFit = future.filter((b) => b.party_size > nextMax || b.party_size < nextMin);
      if (wontFit.length) {
        throw new ConflictException({
          code: 'capacity_conflict_with_reservations',
          message:
            `This table already has ${wontFit.length} upcoming reservation(s) whose party ` +
            `size no longer fits ${nextMin}–${nextMax}. Change those bookings first.`,
          message_ar:
            'فيه حجوزات قادمة على الطاولة دي عدد أفرادها مش هيناسب السعة الجديدة. ' +
            'عدّل الحجوزات دي الأول.',
          affected_reservations: wontFit.length,
          reservation_ids: wontFit.map((b) => b.reservation_id),
          earliest_reservation_at: wontFit[0].starts_at.toISOString(),
          details: [{ field: 'capacity', issue: 'conflict' }],
        });
      }
    }

    try {
      return await this.prisma.table.update({
        where: { id: tableId },
        data: {
          ...(input.name !== undefined ? { name: input.name } : {}),
          ...(input.minCapacity !== undefined ? { minCapacity: input.minCapacity } : {}),
          ...(input.maxCapacity !== undefined ? { maxCapacity: input.maxCapacity } : {}),
          ...(input.zone !== undefined ? { zone: input.zone as TableZone } : {}),
          ...(input.priority !== undefined ? { priority: input.priority } : {}),
          ...(input.combinableWith !== undefined ? { combinableWith: input.combinableWith } : {}),
          ...(input.active !== undefined ? { active: input.active } : {}),
        },
        select: SELECT,
      });
    } catch (err) {
      throw this.translate(err, input.name ?? current.name);
    }
  }

  /**
   * Remove a table.
   *
   * Three outcomes, because "delete" means different things depending on what
   * the table has been part of:
   *
   *   future live bookings  → 409. Nothing happens.
   *   never used at all     → hard delete. The name is freed, which is what an
   *                           owner fixing a typo actually wants.
   *   used, but all settled → deactivated, NOT deleted. The rows in
   *                           reservation_tables are last month's covers; a
   *                           hard delete would either fail on the foreign key
   *                           or erase history the restaurant is owed.
   */
  async remove(
    ownerId: string,
    restaurantId: string,
    tableId: string,
  ): Promise<{ deleted: boolean; deactivated: boolean }> {
    await assertOwned(this.prisma, ownerId, restaurantId);
    const table = await this.prisma.table.findFirst({
      where: { id: tableId, restaurantId },
      select: { id: true },
    });
    if (!table) throw this.notFound();

    const future = await this.futureBookings(tableId);
    if (future.length) throw this.futureBookingsConflict(future, 'delete this table');

    const everUsed = await this.prisma.reservationTable.count({ where: { tableId } });
    if (everUsed === 0) {
      await this.prisma.table.delete({ where: { id: tableId } });
      return { deleted: true, deactivated: false };
    }

    await this.prisma.table.update({ where: { id: tableId }, data: { active: false } });
    return { deleted: false, deactivated: true };
  }

  /**
   * Live reservations on this table that have not happened yet.
   *
   * Reads `reservation_tables` — the same join the EXCLUDE constraint guards —
   * rather than inferring from anything cached, so "is this table spoken for"
   * has exactly one answer across the codebase.
   */
  private async futureBookings(tableId: string): Promise<FutureBooking[]> {
    return this.prisma.$queryRaw<FutureBooking[]>`
      SELECT r.id AS reservation_id, r.starts_at, r.party_size
        FROM reservation_tables rt
        JOIN reservations r ON r.id = rt.reservation_id
       WHERE rt.table_id = ${tableId}::uuid
         AND rt.active
         AND r.starts_at > now()
         AND r.status::text = ANY(${[...LIVE_STATUSES]}::text[])
       ORDER BY r.starts_at ASC`;
  }

  private futureBookingsConflict(future: FutureBooking[], action: string): ConflictException {
    return new ConflictException({
      code: 'table_has_future_reservations',
      message:
        `Cannot ${action}: it has ${future.length} upcoming reservation(s), the first on ` +
        `${future[0].starts_at.toISOString()}. Move or cancel them first.`,
      message_ar:
        'مش ممكن تنفيذ ده: الطاولة عليها حجوزات قادمة. لازم تنقلها أو تلغيها الأول.',
      affected_reservations: future.length,
      reservation_ids: future.map((b) => b.reservation_id),
      earliest_reservation_at: future[0].starts_at.toISOString(),
      details: [{ field: 'active', issue: 'conflict' }],
    });
  }

  private assertCapacityRange(min: number, max: number): void {
    if (!Number.isInteger(min) || !Number.isInteger(max) || min < 1 || max < 1 || min > max) {
      throw badRequest(
        'invalid_capacity_range',
        `min_capacity (${min}) must be a positive integer no greater than max_capacity (${max}).`,
        'أقل عدد لازم يكون رقم موجب ومش أكبر من أقصى عدد.',
      );
    }
  }

  /**
   * A combinable reference must be another table in the SAME restaurant.
   * `combinable_with` is a bare uuid[] with no foreign key, so nothing at the
   * database level stops a table from being declared combinable with one that
   * belongs to a different venue — the engine would then try to seat a party
   * across two restaurants.
   */
  private async assertCombinable(
    restaurantId: string,
    ids: string[] | undefined,
    selfId?: string,
  ): Promise<void> {
    if (!ids?.length) return;
    if (selfId && ids.includes(selfId)) {
      throw badRequest(
        'invalid_combinable_reference',
        'A table cannot be combinable with itself.',
        'الطاولة ما ينفعش تتجمع مع نفسها.',
      );
    }
    const found = await this.prisma.table.count({
      where: { id: { in: ids }, restaurantId },
    });
    if (found !== new Set(ids).size) {
      throw badRequest(
        'invalid_combinable_reference',
        'Every combinable table must belong to this restaurant.',
        'كل طاولة قابلة للدمج لازم تكون في نفس المطعم.',
      );
    }
  }

  private translate(err: unknown, name: string): unknown {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      return new ConflictException({
        code: 'table_name_taken',
        message: `This restaurant already has a table called "${name}".`,
        message_ar: 'فيه طاولة بنفس الاسم في المطعم ده.',
        details: [{ field: 'name', issue: 'conflict' }],
      });
    }
    return err;
  }

  private notFound(): NotFoundException {
    return new NotFoundException({
      code: 'table_not_found',
      message: 'Table not found.',
      message_ar: 'الطاولة غير موجودة.',
    });
  }
}
