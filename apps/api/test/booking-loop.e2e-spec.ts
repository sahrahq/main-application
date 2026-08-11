/**
 * The core loop, end to end: a restaurant exists → a diner sees availability →
 * holds a table → confirms it.
 *
 * WRITTEN BEFORE THE IMPLEMENTATION. Every import below points at code that
 * does not exist yet; this suite is expected to fail to resolve them on the
 * first run. That failure is the point — CLAUDE.md requires the test to lead.
 *
 * Contracts asserted here come from:
 *   06-api-design.md §3 (availability, holds/:id/confirm) and §4 (/owner/...)
 *   05-reservation-engine.md §4 (hold expiry — an expired hold must never
 *     confirm, even if the sweeper has not run yet)
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';
import { RestaurantsService } from '../src/modules/restaurants/restaurants.service';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const reservations = new ReservationsService(p);
const availability = new AvailabilityService(p);
const restaurants = new RestaurantsService(p);

let ownerUserId: string;
let ownerId: string;
let restaurantId: string;
/**
 * The diner these bookings belong to.
 *
 * Added when C-1.6 was enforced: an app booking must have one, and the DB
 * constraint `app_booking_has_diner` says so beneath the service. These tests
 * previously created reservations with `user_id = NULL` — which is precisely
 * the bug that shipped, and precisely why nothing objected to it.
 */
let dinerUserId: string;

/** Tomorrow, in UTC. Shifts below are defined to cover 18:00–23:00. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
})();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);

beforeAll(async () => {
  await prisma.$connect();

  ownerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: ownerUserId,
      phone: `+2011${Date.now().toString().slice(-8)}`,
      fullName: 'Loop Test Owner',
      status: 'active',
    },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Loop Test Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const diner = await prisma.user.create({
    data: {
      phone: `+2014${Date.now().toString().slice(-8)}`,
      fullName: 'Loop Test Diner',
      status: 'active',
    },
  });
  dinerUserId = diner.id;
}, 60_000);

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  if (dinerUserId) await prisma.user.delete({ where: { id: dinerUserId } }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

// ───────────────────────────────────────────── owner restaurant CRUD (§4) ──

describe('owner restaurants (doc 06 §4)', () => {
  it('creates a restaurant in draft, never active', async () => {
    const r = await restaurants.create(ownerId, {
      nameEn: 'Loop Test Venue',
      nameAr: 'مطعم الاختبار',
      cuisines: ['levantine'],
      city: 'Cairo',
      neighborhood: 'Zamalek',
      lat: 30.0622,
      lng: 31.2185,
      slotIntervalMin: 30,
    });
    restaurantId = r.id;

    // A restaurant must not be able to take bookings the moment it is created.
    expect(r.status).toBe('draft');
    expect(r.slug).toMatch(/^loop-test-venue/);
  }, 60_000);

  it('lists only this owner\'s restaurants', async () => {
    const mine = await restaurants.listMine(ownerId);
    expect(mine.map((x) => x.id)).toContain(restaurantId);

    const strangers = await restaurants.listMine(randomUUID());
    expect(strangers).toHaveLength(0);
  }, 60_000);

  it('updates bilingual fields', async () => {
    const updated = await restaurants.update(ownerId, restaurantId, {
      descriptionEn: 'A Nile-side terrace.',
      descriptionAr: 'تراس على النيل.',
      priceBand: 3,
    });
    expect(updated.descriptionAr).toBe('تراس على النيل.');
    expect(updated.priceBand).toBe(3);
  }, 60_000);

  it('refuses to update a restaurant owned by someone else', async () => {
    await expect(
      restaurants.update(randomUUID(), restaurantId, { priceBand: 1 }),
    ).rejects.toMatchObject({ response: { code: 'restaurant_not_found' } });
  }, 60_000);

  it('submit moves draft → pending_review, and only from draft', async () => {
    const submitted = await restaurants.submitForReview(ownerId, restaurantId);
    expect(submitted.status).toBe('pending_review');

    // Submitting twice is an invalid transition, not a silent no-op.
    await expect(restaurants.submitForReview(ownerId, restaurantId)).rejects.toMatchObject({
      response: { code: 'invalid_status_transition' },
    });
  }, 60_000);
});

// ──────────────────────────────────────────────────── availability (§3) ──

describe('availability (doc 06 §3)', () => {
  beforeAll(async () => {
    // Activate it, and pin the venue to UTC so wall-clock == UTC here.
    //
    // The `at()` helper builds absolute UTC instants. Once availability became
    // timezone-aware, a Cairo venue's "20:00" is 17:00Z — so holds placed at
    // 20:00Z landed at 23:00 local and the grid legitimately still offered
    // 20:00. Pinning to UTC keeps this suite about the booking loop; timezone
    // behaviour has its own suite in availability-timezone.e2e-spec.ts.
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'active', timezone = 'UTC'
      WHERE id = ${restaurantId}::uuid`;

    await prisma.shift.create({
      data: {
        restaurantId,
        nameEn: 'Dinner',
        nameAr: 'العشاء',
        dayOfWeek: new Date(`${DATE}T12:00:00Z`).getUTCDay(),
        opensAt: new Date('1970-01-01T18:00:00.000Z'),
        closesAt: new Date('1970-01-01T23:00:00.000Z'),
        defaultTurnMinutes: { '1-2': 90, '3-4': 105, '5+': 120 },
      },
    });

    // Three tables, not two. Traced the allocations by hand: with two, the
    // later confirm cases legitimately run the house out of capacity and fail
    // with slot_taken — a real answer to the wrong question. Zones stay
    // {indoor, outdoor} so the zone assertion below is unaffected.
    await prisma.table.createMany({
      data: [
        { restaurantId, name: 'A1', minCapacity: 1, maxCapacity: 2, zone: 'indoor', priority: 0 },
        { restaurantId, name: 'A2', minCapacity: 2, maxCapacity: 4, zone: 'outdoor', priority: 1 },
        { restaurantId, name: 'A3', minCapacity: 1, maxCapacity: 2, zone: 'indoor', priority: 2 },
      ],
    });
  }, 60_000);

  it('returns bookable slots on the shift grid', async () => {
    const res = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });

    expect(res.slots.length).toBeGreaterThan(0);
    // 30-minute interval, and nothing may be offered outside 18:00–23:00.
    for (const s of res.slots) {
      expect(s.time).toMatch(/^\d{2}:(00|30)$/);
      expect(s.time >= '18:00' && s.time <= '23:00').toBe(true);
    }
    // Last seating must finish before close, not merely start before it.
    expect(res.slots.map((s) => s.time)).not.toContain('23:00');
  }, 60_000);

  it('reports the zones actually available at each slot', async () => {
    const res = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    const slot = res.slots.find((s) => s.time === '19:00');
    expect(slot).toBeDefined();
    // Party of 2 fits A1 (indoor, max 2) and A2 (outdoor, max 4).
    expect(slot!.zones.sort()).toEqual(['indoor', 'outdoor']);
  }, 60_000);

  it('offers no slot for a party larger than every table', async () => {
    const res = await availability.getSlots({ restaurantId, date: DATE, partySize: 20 });
    expect(res.slots).toHaveLength(0);
  }, 60_000);

  it('stops offering a slot once the last table for it is taken', async () => {
    // Three tables, so three holds at 20:00 exhaust the house for a party of 2.
    const before = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(before.slots.map((s) => s.time)).toContain('20:00');

    for (let i = 0; i < 3; i++) {
      await reservations.createHold({
        restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('20:00'), idempotencyKey: randomUUID(),
      });
    }

    const after = await availability.getSlots({ restaurantId, date: DATE, partySize: 2 });
    expect(after.slots.map((s) => s.time)).not.toContain('20:00');

    // A 90-minute turn from 20:00 also blocks 19:00 and 19:30 (they overlap).
    expect(after.slots.map((s) => s.time)).not.toContain('19:30');
  }, 120_000);
});

// ──────────────────────────────────────────────── hold → confirm (§3) ──

describe('a booking in the past is refused — BOTH doors, not one', () => {
  /**
   * `modifyOwn` has refused a past `startsAt` since it was written.
   * `createHold` never checked, and on 2026-08-11 a real handset created and
   * CONFIRMED a booking nine days in the past. The rule existed, was correct,
   * and was enforced at one of the two entrances to the same room.
   *
   * Both are asserted here together, deliberately: the defect was not that
   * either check was wrong, it was that nobody knew they were the same rule.
   */
  it('createHold refuses a time that has already passed', async () => {
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    await expect(
      reservations.createHold({
        restaurantId,
        userId: dinerUserId,
        partySize: 2,
        startsAt: yesterday,
        idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'starts_at_in_past' } });
  });

  it('and still accepts a time a few seconds old, so clock skew does not lose a booking', async () => {
    // The tolerance is real, not incidental: a diner tapping the last slot of
    // the evening as it starts must not be refused because their handset is a
    // second ahead of this process.
    const justNow = new Date(Date.now() - 5_000);
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: justNow, idempotencyKey: randomUUID(),
    });
    expect(hold.status).toBe('held');
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${hold.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${hold.id}::uuid`;
  });
});

describe('hold → confirm (doc 06 §3, doc 05 §4)', () => {
  it('confirms a live hold and clears the expiry', async () => {
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('18:00'), idempotencyKey: randomUUID(),
    });
    expect(hold.status).toBe('held');

    const confirmed = await reservations.confirmHold({
      holdId: hold.id,
      specialRequests: 'Window table if possible',
      occasion: 'anniversary',
      idempotencyKey: randomUUID(),
    });

    expect(confirmed.status).toBe('confirmed');
    expect(confirmed.holdExpiresAt).toBeNull();
    expect(confirmed.specialRequests).toBe('Window table if possible');
    expect(confirmed.code).toMatch(/^SAH-[A-Z0-9]{4}$/);
  }, 60_000);

  it('keeps the table allocated after confirming', async () => {
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('18:30'), idempotencyKey: randomUUID(),
    });
    await reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() });

    const rows = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM reservation_tables
      WHERE reservation_id = ${hold.id}::uuid AND active`;
    expect(Number(rows[0].n)).toBeGreaterThan(0);
  }, 60_000);

  it('REFUSES to confirm an expired hold even before the sweeper runs', async () => {
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('21:30'), idempotencyKey: randomUUID(),
    });

    // Age the hold past its window without touching status — exactly the race
    // doc 05 §4 describes between the sweeper and a late confirm.
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 minute'
      WHERE id = ${hold.id}::uuid`;

    await expect(
      reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() }),
    ).rejects.toMatchObject({ response: { code: 'hold_expired' } });
  }, 60_000);

  it('refuses to confirm a reservation that is not held', async () => {
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('22:00'), idempotencyKey: randomUUID(),
    });
    await reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() });

    await expect(
      reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() }),
    ).rejects.toMatchObject({ response: { code: 'invalid_status_transition' } });
  }, 60_000);

  it('returns 404-shaped error for an unknown hold', async () => {
    await expect(
      reservations.confirmHold({ holdId: randomUUID(), idempotencyKey: randomUUID() }),
    ).rejects.toMatchObject({ response: { code: 'reservation_not_found' } });
  }, 60_000);

  it('replaying the confirm Idempotency-Key returns the same reservation', async () => {
    const hold = await reservations.createHold({
      restaurantId, userId: dinerUserId, partySize: 2, startsAt: at('18:00'), idempotencyKey: randomUUID(),
    });
    const key = randomUUID();

    const first = await reservations.confirmHold({ holdId: hold.id, idempotencyKey: key });
    const second = await reservations.confirmHold({ holdId: hold.id, idempotencyKey: key });

    expect(second.id).toBe(first.id);
    expect(second.status).toBe('confirmed');
  }, 60_000);
});
