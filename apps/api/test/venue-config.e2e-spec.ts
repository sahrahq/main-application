/**
 * Venue configuration — tables (R-2.5) and opening hours/shifts (R-2.4).
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — nothing under restaurants/tables.service
 * or restaurants/shifts.service exists.
 *
 * This closes a gap the test suite structurally could not see: the reservation
 * engine READS `tables` and `shifts`, and every test so far created them with
 * raw SQL. So the whole suite passed while no real restaurant could configure
 * a venue at all.
 *
 * The dangerous half is destructive edits. This is the one API that can corrupt
 * the booking engine, because a table or a shift is not just a config row — it
 * is the thing a confirmed reservation is standing on. Every guard below exists
 * to stop an owner's edit silently invalidating a diner's booking.
 *
 * doc 06 §4 line 103 is explicit: "409 if deactivating a table with future
 * bookings."
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';
import { TablesService } from '../src/modules/restaurants/tables.service';
import { ShiftsService } from '../src/modules/restaurants/shifts.service';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const reservations = new ReservationsService(p);
const availability = new AvailabilityService(p);
const tables = new TablesService(p);
const shifts = new ShiftsService(p);

let ownerUserId: string;
let ownerId: string;
let otherOwnerId: string;
let otherOwnerUserId: string;
let restaurantId: string;

/** +4 days, so this suite cannot collide with the expiry or search suites. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 4);
  return d.toISOString().slice(0, 10);
})();
const DOW = new Date(`${DATE}T12:00:00Z`).getUTCDay();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);
const time = (hhmm: string) => new Date(`1970-01-01T${hhmm}:00.000Z`);

const TURNS = { '1-2': 90, '3-4': 105, '5+': 120 };

async function freshShift(opens: string, closes: string, nameEn = 'Dinner') {
  return shifts.create(ownerId, restaurantId, {
    nameEn, nameAr: 'العشاء', dayOfWeek: DOW,
    opensAt: opens, closesAt: closes, defaultTurnMinutes: TURNS,
  });
}

async function wipeConfig(): Promise<void> {
  await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
  await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${restaurantId}::uuid`;
  await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
}

beforeAll(async () => {
  await prisma.$connect();
  const stamp = Date.now().toString().slice(-8);

  ownerUserId = randomUUID();
  otherOwnerUserId = randomUUID();
  await prisma.user.createMany({
    data: [
      { id: ownerUserId, phone: `+2030${stamp}`, fullName: 'Config Owner', status: 'active' },
      { id: otherOwnerUserId, phone: `+2031${stamp}`, fullName: 'Rival Owner', status: 'active' },
    ],
  });
  ownerId = (await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Config Co', verificationStatus: 'verified' },
  })).id;
  otherOwnerId = (await prisma.restaurantOwner.create({
    data: { userId: otherOwnerUserId, businessName: 'Rival Co', verificationStatus: 'verified' },
  })).id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, cuisines, location,
      status, city, timezone, slot_interval_min, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${'config-test-' + Date.now()}, 'Config Test', 'اختبار الإعداد',
      ARRAY['levantine']::text[],
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', 'UTC', 30, now(), now()
    ) RETURNING id`;
  restaurantId = rows[0].id;
}, 120_000);

beforeEach(async () => {
  if (restaurantId) await wipeConfig();
});

afterAll(async () => {
  if (restaurantId) {
    await wipeConfig();
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${restaurantId}::uuid`;
  }
  for (const id of [ownerId, otherOwnerId]) {
    if (id) await prisma.restaurantOwner.delete({ where: { id } }).catch(() => undefined);
  }
  await prisma.user.deleteMany({
    where: { id: { in: [ownerUserId, otherOwnerUserId].filter(Boolean) } },
  }).catch(() => undefined);
  await prisma.$disconnect();
}, 120_000);

// ───────────────────────────────────────────────────────── tables (R-2.5) ──

describe('tables CRUD (R-2.5)', () => {
  it('creates a table with capacity, zone and combinable flags', async () => {
    const t = await tables.create(ownerId, restaurantId, {
      name: 'T1', minCapacity: 2, maxCapacity: 4, zone: 'outdoor', priority: 1,
    });
    expect(t.name).toBe('T1');
    expect(t.minCapacity).toBe(2);
    expect(t.maxCapacity).toBe(4);
    expect(t.zone).toBe('outdoor');
    expect(t.active).toBe(true);
  }, 60_000);

  it('a new table is immediately bookable — config reaches the engine', async () => {
    await freshShift('18:00', '23:00');
    const before = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(before.slots).toEqual([]); // no tables yet

    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });

    const after = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(after.slots.length).toBeGreaterThan(0);
  }, 60_000);

  it('rejects min greater than max', async () => {
    await expect(
      tables.create(ownerId, restaurantId, { name: 'Bad', minCapacity: 6, maxCapacity: 2 }),
    ).rejects.toMatchObject({ response: { code: 'invalid_capacity_range' } });
  }, 60_000);

  it('rejects a duplicate name within the restaurant', async () => {
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    await expect(
      tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 }),
    ).rejects.toMatchObject({ response: { code: 'table_name_taken' } });
  }, 60_000);

  it('refuses a combinable reference to a table in another restaurant', async () => {
    const mine = await tables.create(ownerId, restaurantId, {
      name: 'T1', minCapacity: 1, maxCapacity: 4,
    });
    await expect(
      tables.update(ownerId, restaurantId, mine.id, { combinableWith: [randomUUID()] }),
    ).rejects.toMatchObject({ response: { code: 'invalid_combinable_reference' } });
  }, 60_000);

  it('another owner cannot read or write this restaurant\'s tables', async () => {
    const t = await tables.create(ownerId, restaurantId, {
      name: 'T1', minCapacity: 1, maxCapacity: 4,
    });
    // Same error either way — a different message would enumerate venues.
    await expect(tables.list(otherOwnerId, restaurantId))
      .rejects.toMatchObject({ response: { code: 'restaurant_not_found' } });
    await expect(tables.update(otherOwnerId, restaurantId, t.id, { name: 'Hijacked' }))
      .rejects.toMatchObject({ response: { code: 'restaurant_not_found' } });
  }, 60_000);
});

// ──────────────────────── the corruption surface: destructive table edits ──

describe('a table edit can never orphan a booking', () => {
  /** A confirmed booking on the only table, in the future. */
  async function bookedTable(partySize = 2, hhmm = '19:00') {
    await freshShift('18:00', '23:00');
    const t = await tables.create(ownerId, restaurantId, {
      name: 'T1', minCapacity: 1, maxCapacity: 6,
    });
    const hold = await reservations.createHold({
      restaurantId, partySize, startsAt: at(hhmm), idempotencyKey: randomUUID(),
    });
    const confirmed = await reservations.confirmHold({
      holdId: hold.id, idempotencyKey: randomUUID(),
    });
    return { table: t, reservationId: confirmed.id };
  }

  const statusOf = async (id: string) =>
    (await prisma.reservation.findUniqueOrThrow({ where: { id }, select: { status: true } })).status;

  const liveAllocations = async (id: string) => {
    const r = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM reservation_tables
      WHERE reservation_id = ${id}::uuid AND active`;
    return Number(r[0].n);
  };

  it('DEACTIVATING a table with a future booking is refused (doc 06 §4)', async () => {
    const { table, reservationId } = await bookedTable();

    await expect(
      tables.update(ownerId, restaurantId, table.id, { active: false }),
    ).rejects.toMatchObject({
      response: { code: 'table_has_future_reservations' },
    });

    // The booking is untouched, and so is the table.
    expect(await statusOf(reservationId)).toBe('confirmed');
    expect(await liveAllocations(reservationId)).toBe(1);
    const still = await tables.get(ownerId, restaurantId, table.id);
    expect(still.active).toBe(true);
  }, 120_000);

  it('the refusal says HOW MANY and WHEN, so the owner can act on it', async () => {
    const { table } = await bookedTable();
    const err = await tables
      .update(ownerId, restaurantId, table.id, { active: false })
      .then(() => null, (e) => e);

    expect(err.response.details).toBeDefined();
    expect(err.response.affected_reservations).toBeGreaterThanOrEqual(1);
    expect(err.response.earliest_reservation_at).toBeDefined();
  }, 120_000);

  it('DELETING a table with a future booking is refused too', async () => {
    const { table, reservationId } = await bookedTable();

    await expect(
      tables.remove(ownerId, restaurantId, table.id),
    ).rejects.toMatchObject({ response: { code: 'table_has_future_reservations' } });

    expect(await statusOf(reservationId)).toBe('confirmed');
  }, 120_000);

  it('SHRINKING max capacity below a seated party is refused', async () => {
    const { table, reservationId } = await bookedTable(6, '19:00');

    await expect(
      tables.update(ownerId, restaurantId, table.id, { maxCapacity: 4 }),
    ).rejects.toMatchObject({
      response: { code: 'capacity_conflict_with_reservations' },
    });

    // A party of 6 assigned to a table that now seats 4 is a booking the
    // restaurant cannot honour. Nothing changed.
    expect(await statusOf(reservationId)).toBe('confirmed');
    const still = await tables.get(ownerId, restaurantId, table.id);
    expect(still.maxCapacity).toBe(6);
  }, 120_000);

  it('RAISING min capacity above a booked party is refused', async () => {
    const { table } = await bookedTable(2, '19:00');
    await expect(
      tables.update(ownerId, restaurantId, table.id, { minCapacity: 4 }),
    ).rejects.toMatchObject({ response: { code: 'capacity_conflict_with_reservations' } });
  }, 120_000);

  it('widening capacity is always allowed', async () => {
    const { table } = await bookedTable(2, '19:00');
    const wider = await tables.update(ownerId, restaurantId, table.id, { maxCapacity: 8 });
    expect(wider.maxCapacity).toBe(8);
  }, 120_000);

  it('a table whose bookings are all in the PAST can be deactivated', async () => {
    await freshShift('18:00', '23:00');
    const t = await tables.create(ownerId, restaurantId, {
      name: 'T1', minCapacity: 1, maxCapacity: 4,
    });
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    const confirmed = await reservations.confirmHold({
      holdId: hold.id, idempotencyKey: randomUUID(),
    });
    // Age it into last week.
    await prisma.$executeRaw`
      UPDATE reservations SET starts_at = now() - interval '7 days',
                              ends_at   = now() - interval '7 days' + interval '90 minutes'
      WHERE id = ${confirmed.id}::uuid`;

    const off = await tables.update(ownerId, restaurantId, t.id, { active: false });
    expect(off.active).toBe(false);

    // History survives — a completed booking must remain reconstructable.
    const kept = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM reservation_tables WHERE reservation_id = ${confirmed.id}::uuid`;
    expect(Number(kept[0].n)).toBe(1);
  }, 120_000);

  it('a deactivated table stops being offered but keeps its existing booking', async () => {
    await freshShift('18:00', '23:00');
    const keep = await tables.create(ownerId, restaurantId, {
      name: 'KEEP', minCapacity: 1, maxCapacity: 4,
    });
    const retire = await tables.create(ownerId, restaurantId, {
      name: 'RETIRE', minCapacity: 1, maxCapacity: 4,
    });

    await tables.update(ownerId, restaurantId, retire.id, { active: false });

    const slots = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    // Still bookable via KEEP...
    expect(slots.slots.length).toBeGreaterThan(0);
    // ...but every offered slot is served by the live table only.
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    const alloc = await prisma.$queryRaw<{ table_id: string }[]>`
      SELECT table_id FROM reservation_tables WHERE reservation_id = ${hold.id}::uuid`;
    expect(alloc[0].table_id).toBe(keep.id);
  }, 120_000);

  it('a table that was never used is deleted outright', async () => {
    const t = await tables.create(ownerId, restaurantId, {
      name: 'TYPO', minCapacity: 1, maxCapacity: 4,
    });
    const res = await tables.remove(ownerId, restaurantId, t.id);
    expect(res.deleted).toBe(true);
    // Gone, so the name is free again — the point of allowing a hard delete.
    const reused = await tables.create(ownerId, restaurantId, {
      name: 'TYPO', minCapacity: 1, maxCapacity: 4,
    });
    expect(reused.id).not.toBe(t.id);
  }, 60_000);

  it('a table with only PAST bookings is retired, not deleted — history survives', async () => {
    await freshShift('18:00', '23:00');
    const t = await tables.create(ownerId, restaurantId, {
      name: 'OLD', minCapacity: 1, maxCapacity: 4,
    });
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    await prisma.$executeRaw`
      UPDATE reservations SET starts_at = now() - interval '30 days',
                              ends_at   = now() - interval '30 days' + interval '90 minutes',
                              status = 'completed'
      WHERE id = ${hold.id}::uuid`;

    const res = await tables.remove(ownerId, restaurantId, t.id);
    expect(res.deleted).toBe(false);
    expect(res.deactivated).toBe(true);

    // The row is still there, so last month's covers can still be reported.
    const still = await prisma.table.findUnique({ where: { id: t.id } });
    expect(still).not.toBeNull();
    expect(still!.active).toBe(false);
  }, 120_000);
});

// ────────────────────────────────────────────── shifts / hours (R-2.4) ──

describe('opening hours and shifts (R-2.4)', () => {
  it('creates a weekly shift that the availability grid honours', async () => {
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    await freshShift('18:00', '22:00');

    const slots = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    const times = slots.slots.map((s) => s.time);
    expect(times).toContain('18:00');
    expect(times).not.toContain('17:30');
  }, 60_000);

  it('MULTIPLE shifts per weekday both produce slots — lunch AND dinner', async () => {
    // The requirement R-2.4 states plainly ("multiple shifts"), and the thing
    // this API is useless without: an owner adding lunch must not have it
    // silently ignored because the engine only ever read one shift.
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    await freshShift('12:00', '15:00', 'Lunch');
    await freshShift('18:00', '23:00', 'Dinner');

    const times = (await availability.getSlots({ restaurantId, date: DATE, partySize: 2 }))
      .slots.map((s) => s.time);

    expect(times).toContain('12:00'); // lunch
    expect(times).toContain('18:00'); // dinner
    expect(times).not.toContain('16:00'); // the gap between them stays closed
  }, 60_000);

  it('a date-specific shift overrides the weekly pattern for that day', async () => {
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    await freshShift('18:00', '23:00');
    await shifts.create(ownerId, restaurantId, {
      nameEn: 'Holiday', nameAr: 'إجازة', specificDate: DATE,
      opensAt: '20:00', closesAt: '23:00', defaultTurnMinutes: TURNS,
    });

    const times = (await availability.getSlots({ restaurantId, date: DATE, partySize: 2 }))
      .slots.map((s) => s.time);
    expect(times).toContain('20:00');
    expect(times).not.toContain('18:00'); // weekly pattern is superseded
  }, 60_000);

  it('rejects two overlapping shifts on the same weekday', async () => {
    // Overlapping shifts make the grid ambiguous — two different turn-time
    // configs would claim the same minute.
    await freshShift('18:00', '23:00');
    await expect(
      freshShift('22:00', '23:30', 'Late'),
    ).rejects.toMatchObject({ response: { code: 'shift_overlap' } });
  }, 60_000);

  it('requires exactly one of dayOfWeek or specificDate', async () => {
    await expect(
      shifts.create(ownerId, restaurantId, {
        nameEn: 'Bad', nameAr: 'خطأ', opensAt: '18:00', closesAt: '23:00',
        defaultTurnMinutes: TURNS,
      }),
    ).rejects.toMatchObject({ response: { code: 'invalid_shift_scope' } });

    await expect(
      shifts.create(ownerId, restaurantId, {
        nameEn: 'Bad', nameAr: 'خطأ', dayOfWeek: DOW, specificDate: DATE,
        opensAt: '18:00', closesAt: '23:00', defaultTurnMinutes: TURNS,
      }),
    ).rejects.toMatchObject({ response: { code: 'invalid_shift_scope' } });
  }, 60_000);

  it('rejects a zero-length shift', async () => {
    await expect(
      freshShift('18:00', '18:00'),
    ).rejects.toMatchObject({ response: { code: 'invalid_shift_hours' } });
  }, 60_000);

  it('accepts a shift that runs past midnight', async () => {
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    const s = await shifts.create(ownerId, restaurantId, {
      nameEn: 'Sohour', nameAr: 'سحور', dayOfWeek: DOW,
      opensAt: '22:00', closesAt: '03:00', spansMidnight: true,
      defaultTurnMinutes: TURNS,
    });
    expect(s.spansMidnight).toBe(true);
  }, 60_000);
});

// ───────────────────── changing hours must not quietly break a booking ──

describe('an hours change can never silently invalidate a confirmed booking', () => {
  async function bookedAt(hhmm: string) {
    await tables.create(ownerId, restaurantId, { name: 'T1', minCapacity: 1, maxCapacity: 4 });
    const shift = await freshShift('12:00', '23:00');
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at(hhmm), idempotencyKey: randomUUID(),
    });
    const confirmed = await reservations.confirmHold({
      holdId: hold.id, idempotencyKey: randomUUID(),
    });
    return { shift, reservationId: confirmed.id };
  }

  const statusOf = async (id: string) =>
    (await prisma.reservation.findUniqueOrThrow({ where: { id }, select: { status: true } })).status;

  it('narrowing hours past a confirmed booking is REFUSED by default', async () => {
    const { shift, reservationId } = await bookedAt('12:30');

    await expect(
      shifts.update(ownerId, restaurantId, shift.id, { opensAt: '18:00' }),
    ).rejects.toMatchObject({ response: { code: 'bookings_outside_new_hours' } });

    // Hours unchanged, booking unchanged.
    const still = await shifts.get(ownerId, restaurantId, shift.id);
    expect(still.opensAt).toBe('12:00');
    expect(await statusOf(reservationId)).toBe('confirmed');
  }, 120_000);

  it('the refusal names the affected bookings so the owner can call them', async () => {
    const { shift, reservationId } = await bookedAt('12:30');
    const err = await shifts
      .update(ownerId, restaurantId, shift.id, { opensAt: '18:00' })
      .then(() => null, (e) => e);

    expect(err.response.affected_reservations).toBeGreaterThanOrEqual(1);
    expect(err.response.reservation_ids).toContain(reservationId);
  }, 120_000);

  it('with force, the hours change and the booking SURVIVES — never auto-cancelled', async () => {
    const { shift, reservationId } = await bookedAt('12:30');

    const res = await shifts.update(
      ownerId, restaurantId, shift.id, { opensAt: '18:00' }, { force: true },
    );

    // The owner's decision is honoured...
    expect(res.shift.opensAt).toBe('18:00');
    // ...but the platform does not cancel a diner's confirmed table on their
    // behalf. The restaurant promised it; only a human can unpromise it.
    expect(await statusOf(reservationId)).toBe('confirmed');
    // And the response hands back exactly who needs a phone call.
    expect(res.reservationsOutsideHours).toContain(reservationId);
  }, 120_000);

  it('a booking now outside hours keeps its table allocation', async () => {
    const { shift, reservationId } = await bookedAt('12:30');
    await shifts.update(ownerId, restaurantId, shift.id, { opensAt: '18:00' }, { force: true });

    const live = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM reservation_tables
      WHERE reservation_id = ${reservationId}::uuid AND active`;
    expect(Number(live[0].n)).toBe(1);
  }, 120_000);

  it('narrowing hours that affects only PAST bookings needs no force', async () => {
    const { shift, reservationId } = await bookedAt('12:30');
    await prisma.$executeRaw`
      UPDATE reservations SET starts_at = now() - interval '10 days',
                              ends_at   = now() - interval '10 days' + interval '90 minutes'
      WHERE id = ${reservationId}::uuid`;

    const res = await shifts.update(ownerId, restaurantId, shift.id, { opensAt: '18:00' });
    expect(res.shift.opensAt).toBe('18:00');
    expect(res.reservationsOutsideHours).toEqual([]);
  }, 120_000);

  it('deleting a shift with future bookings inside it is refused without force', async () => {
    const { shift, reservationId } = await bookedAt('12:30');

    await expect(
      shifts.remove(ownerId, restaurantId, shift.id),
    ).rejects.toMatchObject({ response: { code: 'bookings_outside_new_hours' } });

    expect(await statusOf(reservationId)).toBe('confirmed');
  }, 120_000);

  it('widening hours is always allowed', async () => {
    const { shift } = await bookedAt('12:30');
    const res = await shifts.update(ownerId, restaurantId, shift.id, { closesAt: '23:59' });
    expect(res.shift.closesAt).toBe('23:59');
    expect(res.reservationsOutsideHours).toEqual([]);
  }, 120_000);
});

// ────────────────────────────────────────────────────── explicitly out of scope ──

describe('Ramadan mode is NOT built (R-2.4, scoped out)', () => {
  it('the is_ramadan flag round-trips but anchors nothing yet', async () => {
    const s = await shifts.create(ownerId, restaurantId, {
      nameEn: 'Iftar', nameAr: 'إفطار', dayOfWeek: DOW,
      opensAt: '18:00', closesAt: '21:00', isRamadan: true,
      defaultTurnMinutes: TURNS,
    });
    expect(s.isRamadan).toBe(true);

    // R-2.4 requires iftar seating pegged to Maghrib, auto-adjusting daily with
    // sunset. That is a separate feature — it needs a prayer-time source and a
    // daily recompute. The flag is persisted so the data model is ready; the
    // behaviour is deliberately absent rather than half-built.
    const slots = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(slots.slots.every((x) => x.time >= '18:00')).toBe(true);
  }, 60_000);
});
