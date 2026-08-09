/**
 * Walk-ins and phone bookings — R-3.2, "non-negotiable for adoption".
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — walk-ins.service does not exist.
 *
 * The bug being closed is the same class as the shiftFor one: a party seated
 * off-platform is INVISIBLE to the engine, so the table they are sitting at
 * still looks free and the next online booking double-seats them.
 *
 * doc 05 §7 states the rule in one line: "Walk-ins consume the same inventory
 * through the same engine path." So the thing under test is not really the new
 * endpoint — it is that the new endpoint has no separate seating logic at all.
 * Every guarantee holds because it goes through createHold's advisory lock,
 * free-table re-check and EXCLUDE USING GIST, not because it re-implements
 * them carefully.
 */
import { PrismaClient, ReservationStatus, ReservationSource } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { ReservationsService, extractPgCode } from '../src/modules/reservations/reservations.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';
import { HoldExpiryService } from '../src/modules/reservations/expiry/hold-expiry.service';
import { OwnerReservationsService } from '../src/modules/restaurants/owner-reservations.service';
import { TablesService } from '../src/modules/restaurants/tables.service';
import { ShiftsService } from '../src/modules/restaurants/shifts.service';
import { WalkInsService } from '../src/modules/restaurants/walk-ins.service';
import { createTestDiner, removeTestDiner } from './support/test-diner';
import { realWaitlistOffers } from './support/waitlist-offers';

const TEST_DB_URL = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  const sep = base.includes('?') ? '&' : '?';
  return `${base}${sep}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url: TEST_DB_URL } } });
const p = prisma as unknown as PrismaService;

const reservations = new ReservationsService(p);
const availability = new AvailabilityService(p);
const expiry = new HoldExpiryService(p, realWaitlistOffers(p));
const book = new OwnerReservationsService(p);
const tables = new TablesService(p);
const shifts = new ShiftsService(p);
const walkIns = new WalkInsService(p, reservations);

let ownerUserId: string;
let ownerId: string;
let rivalOwnerId: string;
let rivalOwnerUserId: string;
let restaurantId: string;
/**
 * Owns the app bookings below. C-1.6 requires one, and the DB constraint
 * `app_booking_has_diner` enforces it beneath the service — a fixture with a
 * null user was reproducing the bug that shipped.
 */
let testDinerId: string;

/** +5 days, clear of every other suite. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 5);
  return d.toISOString().slice(0, 10);
})();
const DOW = new Date(`${DATE}T12:00:00Z`).getUTCDay();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);
const TURNS = { '1-2': 90, '3-4': 105, '5+': 120 };

async function oneTable(name = 'W1') {
  return tables.create(ownerId, restaurantId, { name, minCapacity: 1, maxCapacity: 6 });
}

beforeAll(async () => {
  await prisma.$connect();
  testDinerId = await createTestDiner(prisma);
  const stamp = Date.now().toString().slice(-8);

  ownerUserId = randomUUID();
  rivalOwnerUserId = randomUUID();
  await prisma.user.createMany({
    data: [
      { id: ownerUserId, phone: `+2040${stamp}`, fullName: 'Walkin Owner', status: 'active' },
      { id: rivalOwnerUserId, phone: `+2041${stamp}`, fullName: 'Rival Owner', status: 'active' },
    ],
  });
  ownerId = (await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Walkin Co', verificationStatus: 'verified' },
  })).id;
  rivalOwnerId = (await prisma.restaurantOwner.create({
    data: { userId: rivalOwnerUserId, businessName: 'Rival Co', verificationStatus: 'verified' },
  })).id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, cuisines, location,
      status, city, timezone, slot_interval_min, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${'walkin-test-' + Date.now()}, 'Walkin Test', 'اختبار الدخول',
      ARRAY['levantine']::text[],
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', 'UTC', 30, now(), now()
    ) RETURNING id`;
  restaurantId = rows[0].id;
}, 120_000);

beforeEach(async () => {
  if (!restaurantId) return;
  await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
  await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${restaurantId}::uuid`;
  await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
  await shifts.create(ownerId, restaurantId, {
    nameEn: 'All day', nameAr: 'طول اليوم', dayOfWeek: DOW,
    opensAt: '00:00', closesAt: '23:30', defaultTurnMinutes: TURNS,
  });
});

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${restaurantId}::uuid`;
  }
  for (const id of [ownerId, rivalOwnerId]) {
    if (id) await prisma.restaurantOwner.delete({ where: { id } }).catch(() => undefined);
  }
  await prisma.user.deleteMany({
    where: { id: { in: [ownerUserId, rivalOwnerUserId].filter(Boolean) } },
  }).catch(() => undefined);
  await removeTestDiner(prisma, testDinerId);
  await prisma.$disconnect();
}, 120_000);

// ─────────────────────────────────────────── the three shapes of a walk-in ──

describe('a walk-in has no customer account (R-3.2)', () => {
  it('records a name and a phone', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Nour', guestPhone: '+201000000001',
      startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    expect(r.userId).toBeNull();
    expect(r.guestName).toBe('Nour');
    expect(r.guestPhone).toBe('+201000000001');
    expect(r.source).toBe(ReservationSource.walk_in);
  }, 60_000);

  it('records a name alone', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Nour', startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    expect(r.guestName).toBe('Nour');
    expect(r.guestPhone).toBeNull();
    expect(r.userId).toBeNull();
  }, 60_000);

  it('accepts nothing but a party size — the host is holding a queue, not a form', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    expect(r.guestName).toBeNull();
    expect(r.guestPhone).toBeNull();
    expect(r.userId).toBeNull();
    expect(r.partySize).toBe(2);
  }, 60_000);

  it('a phone booking is a distinct source from a walk-in', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Omar', guestPhone: '+201000000002',
      startsAt: at('20:00'), source: 'phone', idempotencyKey: randomUUID(),
    });
    expect(r.source).toBe(ReservationSource.phone);
  }, 60_000);

  it('rejects a source that is not a staff channel', async () => {
    await oneTable();
    // `app` would launder a staff-entered booking as a customer one, and
    // `admin`/`waitlist` belong to other flows.
    await expect(
      walkIns.create(ownerId, restaurantId, {
        partySize: 2, startsAt: at('19:00'), source: 'app' as never,
        idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'invalid_source' } });
  }, 60_000);

  it('defaults to seating now when no time is given', async () => {
    await oneTable();
    const before = Date.now();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, idempotencyKey: randomUUID(),
    });
    // A walk-in is a party standing at the door.
    expect(r.startsAt.getTime()).toBeGreaterThanOrEqual(before - 60_000);
    expect(r.startsAt.getTime()).toBeLessThanOrEqual(Date.now() + 60_000);
  }, 60_000);
});

// ───────────────────────────────── the whole point: one shared inventory ──

describe('walk-ins consume the SAME inventory (doc 05 §7)', () => {
  it('a walk-in takes the table away from the app', async () => {
    await oneTable();
    await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Walk', startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    // The exact failure that made this feature necessary: without it, this
    // hold succeeds and two parties are sent to one table.
    await expect(
      reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'slot_taken' } });
  }, 60_000);

  it('an app booking takes the table away from the walk-in — cleanly, not with a 500', async () => {
    await oneTable();
    await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    await expect(
      walkIns.create(ownerId, restaurantId, {
        partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'slot_taken' } });
  }, 60_000);

  it('removes the slot from the availability grid', async () => {
    await oneTable();
    const before = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(before.slots.map((s) => s.time)).toContain('19:00');

    await walkIns.create(ownerId, restaurantId, {
      partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    const after = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(after.slots.map((s) => s.time)).not.toContain('19:00');
  }, 60_000);

  it('holds a real table allocation, guarded by the same EXCLUDE constraint', async () => {
    const table = await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    const alloc = await prisma.$queryRaw<{ table_id: string }[]>`
      SELECT table_id FROM reservation_tables
      WHERE reservation_id = ${r.id}::uuid AND active`;
    expect(alloc).toHaveLength(1);
    expect(alloc[0].table_id).toBe(table.id);

    // The DB itself refuses a second row on the same table and window — proof
    // the walk-in sits under layer 3, not beside it.
    const clash = await prisma.$executeRawUnsafe(`
      INSERT INTO reservation_tables (reservation_id, table_id, during, active)
      VALUES ('${r.id}'::uuid, '${table.id}'::uuid,
              tstzrange('${at('19:00').toISOString()}', '${at('20:00').toISOString()}', '[)'), true)
    `).then(() => 'inserted', (e) => extractPgCode(e));
    expect(clash).not.toBe('inserted');
  }, 60_000);
});

// ─────────────────────────── seated now, never a hold the sweeper can eat ──

describe('a walk-in is seated, not held', () => {
  it('is created already confirmed with no hold expiry', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    // A walk-in has no checkout to abandon. If it were created `held`, a crash
    // before confirm would let the sweeper expire it while the party is
    // physically sitting at the table — the exact double-seat this feature
    // exists to prevent.
    expect(r.status).toBe(ReservationStatus.confirmed);
    expect(r.holdExpiresAt).toBeNull();
  }, 60_000);

  it('the hold sweeper never touches it', async () => {
    await oneTable();
    const r = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 hour'
      WHERE id = ${r.id}::uuid`;

    await expiry.sweep();

    const after = await prisma.reservation.findUniqueOrThrow({
      where: { id: r.id }, select: { status: true },
    });
    expect(after.status).toBe(ReservationStatus.confirmed);
  }, 60_000);
});

// ──────────────────────────────────────────────── visible to the operator ──

describe('the owner can tell a walk-in from an app booking', () => {
  it('appears in the book, tagged by source', async () => {
    await oneTable('W1');
    await tables.create(ownerId, restaurantId, { name: 'W2', minCapacity: 1, maxCapacity: 6 });

    const walk = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Walk', startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    const online = await reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });

    const list = await book.listForDate({ ownerId, restaurantId, date: DATE });
    const byId = new Map(list.reservations.map((r) => [r.id, r]));

    expect(byId.get(walk.id)!.source).toBe(ReservationSource.walk_in);
    expect(byId.get(online.id)!.source).toBe(ReservationSource.app);
  }, 60_000);
});

// ───────────────────────────────────────────────────────────────── access ──

describe('staff of one restaurant cannot seat at another', () => {
  it('a rival owner is refused, with the same error as a missing venue', async () => {
    await oneTable();
    await expect(
      walkIns.create(rivalOwnerId, restaurantId, {
        partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'restaurant_not_found' } });
  }, 60_000);

  it('the refusal happens BEFORE any inventory is touched', async () => {
    await oneTable();
    await walkIns
      .create(rivalOwnerId, restaurantId, {
        partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      })
      .catch(() => undefined);

    // No phantom row, and the slot is still sellable.
    const count = await prisma.reservation.count({ where: { restaurantId } });
    expect(count).toBe(0);
    const slots = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(slots.slots.map((s) => s.time)).toContain('19:00');
  }, 60_000);
});

// ──────────────────────────────────────────────────── idempotency & input ──

describe('idempotency and validation', () => {
  it('a replayed key returns the same reservation, never a second table', async () => {
    await oneTable();
    const key = randomUUID();
    const first = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Nour', startsAt: at('19:00'), idempotencyKey: key,
    });
    const again = await walkIns.create(ownerId, restaurantId, {
      partySize: 2, guestName: 'Nour', startsAt: at('19:00'), idempotencyKey: key,
    });

    expect(again.id).toBe(first.id);
    expect(await prisma.reservation.count({ where: { restaurantId } })).toBe(1);
  }, 60_000);

  it('rejects an impossible party size', async () => {
    await oneTable();
    await expect(
      walkIns.create(ownerId, restaurantId, {
        partySize: 0, startsAt: at('19:00'), idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'invalid_party_size' } });
  }, 60_000);
});

// ═══════════════════════════════════════════════════════════ CONCURRENCY ══

/**
 * The non-negotiable one, in the same style as reservation-concurrency.
 *
 * A host tapping "seat this party" at the same instant a diner taps "book" is
 * not a hypothetical — it is a Thursday night. Both must contend for the same
 * table through the same advisory lock, and exactly one may win.
 */
describe('a walk-in racing an online hold for the last table', () => {
  it('produces exactly ONE winner and clean 409s — never two, never a 500', async () => {
    await oneTable(); // exactly one table in the house
    const startsAt = at('19:00');
    const CONTENDERS = 12;

    const attempts = Array.from({ length: CONTENDERS }, (_, i) =>
      i % 2 === 0
        ? // host, at the podium
          () =>
            walkIns.create(ownerId, restaurantId, {
              partySize: 2, guestName: `Walk ${i}`, startsAt, idempotencyKey: randomUUID(),
            })
        : // diner, in the app
          () =>
            reservations.createHold({ userId: testDinerId,
      restaurantId, partySize: 2, startsAt, idempotencyKey: randomUUID(),
            }),
    );

    const settled = await Promise.allSettled(attempts.map((fn) => fn()));

    const won = settled.filter((s) => s.status === 'fulfilled');
    const lost = settled.filter((s) => s.status === 'rejected') as PromiseRejectedResult[];

    expect(won).toHaveLength(1);
    expect(lost).toHaveLength(CONTENDERS - 1);

    // Every loser must be a clean, actionable 409. A 500 here would mean the
    // race is being resolved by an unhandled constraint violation rather than
    // by the engine, which is the difference between a queue and a crash.
    for (const l of lost) {
      const code = l.reason?.response?.code;
      expect(code).toBe('slot_taken');
      expect(l.reason?.status).toBe(409);
    }

    // And the database agrees there is exactly one live allocation.
    const live = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n
        FROM reservation_tables rt
        JOIN reservations r ON r.id = rt.reservation_id
       WHERE r.restaurant_id = ${restaurantId}::uuid AND rt.active`;
    expect(Number(live[0].n)).toBe(1);
  }, 180_000);

  it('two simultaneous walk-ins for the last table also settle to one', async () => {
    await oneTable();
    const startsAt = at('20:00');

    const settled = await Promise.allSettled(
      Array.from({ length: 6 }, (_, i) =>
        walkIns.create(ownerId, restaurantId, {
          partySize: 2, guestName: `Party ${i}`, startsAt, idempotencyKey: randomUUID(),
        }),
      ),
    );

    expect(settled.filter((s) => s.status === 'fulfilled')).toHaveLength(1);
    for (const l of settled.filter((s) => s.status === 'rejected') as PromiseRejectedResult[]) {
      expect(l.reason?.response?.code).toBe('slot_taken');
    }
  }, 180_000);
});
