/**
 * Hold expiry (doc 05 §4).
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — nothing under reservations/expiry/ exists.
 *
 * This closes a broken invariant, not a missing feature: today an abandoned
 * hold never releases, so a table stays locked forever and the restaurant
 * loses the cover.
 *
 * doc 05 §4 mandates BOTH mechanisms:
 *   Primary  — a BullMQ delayed job per hold (precise)
 *   Backstop — a 60s sweeper "catches jobs lost to worker crashes"
 *
 * The backstop is the reason this design is trustworthy, so it gets the
 * hardest test: a hold whose delayed job NEVER EXISTS must still be released.
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { HoldExpiryService } from '../src/modules/reservations/expiry/hold-expiry.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';
import { createTestDiner, removeTestDiner } from './support/test-diner';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const reservations = new ReservationsService(p);
const expiry = new HoldExpiryService(p);
const availability = new AvailabilityService(p);

let ownerUserId: string;
let ownerId: string;
let restaurantId: string;
let tableId: string;
/**
 * Owns the app bookings below. C-1.6 requires one, and the DB constraint
 * `app_booking_has_diner` enforces it beneath the service — a fixture with a
 * null user was reproducing the bug that shipped.
 */
let testDinerId: string;

/** Tomorrow, UTC — the venue is pinned to UTC so wall-clock == UTC here. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
})();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);

/** Force a hold's window into the past without touching its status. */
async function ageHold(id: string, secondsAgo = 60): Promise<void> {
  await prisma.$executeRaw`
    UPDATE reservations
       SET hold_expires_at = now() - make_interval(secs => ${secondsAgo}::double precision)
     WHERE id = ${id}::uuid`;
}

const statusOf = async (id: string): Promise<string> =>
  (await prisma.reservation.findUniqueOrThrow({ where: { id }, select: { status: true } })).status;

const liveAllocations = async (id: string): Promise<number> => {
  const r = await prisma.$queryRaw<{ n: bigint }[]>`
    SELECT COUNT(*) AS n FROM reservation_tables
    WHERE reservation_id = ${id}::uuid AND active`;
  return Number(r[0].n);
};

beforeAll(async () => {
  await prisma.$connect();
  testDinerId = await createTestDiner(prisma);
  const stamp = Date.now().toString().slice(-8);

  ownerUserId = randomUUID();
  await prisma.user.create({
    data: { id: ownerUserId, phone: `+2018${stamp}`, fullName: 'Expiry Owner', status: 'active' },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Expiry Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, cuisines, location,
      status, city, timezone, slot_interval_min, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${'expiry-test-' + Date.now()}, 'Expiry Test', 'اختبار الانتهاء',
      ARRAY['levantine']::text[],
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', 'UTC', 30, now(), now()
    ) RETURNING id`;
  restaurantId = rows[0].id;

  await prisma.shift.create({
    data: {
      restaurantId,
      nameEn: 'Dinner', nameAr: 'العشاء',
      dayOfWeek: new Date(`${DATE}T12:00:00Z`).getUTCDay(),
      opensAt: new Date('1970-01-01T18:00:00.000Z'),
      closesAt: new Date('1970-01-01T23:00:00.000Z'),
      defaultTurnMinutes: { '1-2': 90, '3-4': 105, '5+': 120 },
    },
  });

  // ONE table, so "released or not" is unambiguous.
  const t = await prisma.table.create({
    data: { restaurantId, name: 'E1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
  });
  tableId = t.id;
}, 60_000);

/**
 * Every test starts with an empty book.
 *
 * The venue has ONE table so "released or not" is unambiguous, but that also
 * means a hold left behind by an earlier test blocks any overlapping window
 * later — with 90-minute turns inside an 18:00–23:00 shift there are barely
 * three non-overlapping slots. Four tests were failing on `slot_taken` during
 * SETUP, which looks like a sweeper bug and is not one. Independent tests are
 * worth more here than a shared fixture.
 */
beforeEach(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
  }
});

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  await removeTestDiner(prisma, testDinerId);
  await prisma.$disconnect();
}, 60_000);

describe('the sweeper (doc 05 §4 backstop)', () => {
  it('expires a lapsed hold', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('18:00'), idempotencyKey: randomUUID(),
    });
    expect(await statusOf(hold.id)).toBe('held');

    await ageHold(hold.id);
    const n = await expiry.sweep();

    expect(n).toBeGreaterThanOrEqual(1);
    expect(await statusOf(hold.id)).toBe('expired');
  }, 60_000);

  it('RELEASES THE TABLE — the invariant that was broken', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    // Only table in the house is now taken.
    await expect(
      reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'slot_taken' } });

    await ageHold(hold.id);
    await expiry.sweep();

    // Allocation released...
    expect(await liveAllocations(hold.id)).toBe(0);
    // ...and someone else can actually book it.
    const next = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    expect(next.status).toBe('held');
  }, 60_000);

  it('puts the slot back on the availability grid', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('21:30'), idempotencyKey: randomUUID(),
    });
    const taken = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(taken.slots.map((s) => s.time)).not.toContain('21:30');

    await ageHold(hold.id);
    await expiry.sweep();

    const freed = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(freed.slots.map((s) => s.time)).toContain('21:30');
  }, 60_000);

  it('leaves a hold that is still within its window alone', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('22:00'), idempotencyKey: randomUUID(),
    });
    await expiry.sweep();
    expect(await statusOf(hold.id)).toBe('held');
    expect(await liveAllocations(hold.id)).toBeGreaterThan(0);
  }, 60_000);

  it('never touches a confirmed reservation, however old the column is', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('18:30'), idempotencyKey: randomUUID(),
    });
    await reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() });

    // Confirm nulls hold_expires_at, but belt and braces: a stale value must
    // not resurrect the sweeper against a confirmed booking.
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 hour'
      WHERE id = ${hold.id}::uuid`;
    await expiry.sweep();

    expect(await statusOf(hold.id)).toBe('confirmed');
    expect(await liveAllocations(hold.id)).toBeGreaterThan(0);
  }, 60_000);

  it('is idempotent — a second sweep is a no-op', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('20:00'), idempotencyKey: randomUUID(),
    });
    await ageHold(hold.id);

    await expiry.sweep();
    const second = await expiry.sweep();

    expect(await statusOf(hold.id)).toBe('expired');
    // Nothing left matching the predicate, so the second pass claims nothing.
    expect(second).toBe(0);
  }, 60_000);
});

describe('THE POINT OF HAVING BOTH: the delayed job is lost entirely', () => {
  it('sweeper releases a hold whose expire-hold job never ran', async () => {
    // Simulates a worker crash, a Redis flush, or a queue that silently
    // dropped the job: NOTHING is ever enqueued for this hold. The only thing
    // that can save the table is the 60s backstop.
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('20:30'), idempotencyKey: randomUUID(),
    });
    expect(await statusOf(hold.id)).toBe('held');
    expect(await liveAllocations(hold.id)).toBe(1);

    await ageHold(hold.id, 600); // ten minutes past its five-minute window

    // No job exists. No job is created. Only the sweeper runs.
    await expiry.sweep();

    expect(await statusOf(hold.id)).toBe('expired');
    expect(await liveAllocations(hold.id)).toBe(0);

    // The table is genuinely usable again, which is the business outcome.
    const rebooked = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('20:30'), idempotencyKey: randomUUID(),
    });
    expect(rebooked.status).toBe('held');
    expect(rebooked.id).not.toBe(hold.id);
  }, 60_000);
});

describe('sweeper vs confirm (doc 05 §4 race)', () => {
  it('a confirm that lands first wins, and the sweeper does not undo it', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('22:30'), idempotencyKey: randomUUID(),
    });

    const confirmed = await reservations.confirmHold({
      holdId: hold.id, idempotencyKey: randomUUID(),
    });
    expect(confirmed.status).toBe('confirmed');

    await expiry.sweep();
    expect(await statusOf(hold.id)).toBe('confirmed');
  }, 60_000);

  it('a confirm arriving after expiry is refused, not silently honoured', async () => {
    const hold = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('18:00'), idempotencyKey: randomUUID(),
    });
    await ageHold(hold.id);
    await expiry.sweep();

    await expect(
      reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() }),
    ).rejects.toMatchObject({ response: { code: 'hold_expired' } });
  }, 60_000);
});
