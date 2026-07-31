/**
 * THE test. CLAUDE.md rule 1 / DEVELOPMENT.md §5:
 *
 *   "Before building any UI on top of booking, write the concurrency test:
 *    spin up N concurrent requests for the same last table and assert exactly
 *    one succeeds. This test must pass and stay in CI forever — it's the
 *    platform's core promise to restaurants."
 *
 * Requires a real Postgres with the guards from prisma/sql/01_guards.sql
 * applied. It cannot be faked with mocks: the whole point is to exercise
 * pg_advisory_xact_lock and the EXCLUDE USING GIST constraint for real.
 */
import { PrismaClient, ReservationStatus } from '@prisma/client';
import { randomUUID } from 'crypto';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { PrismaService } from '../src/shared/prisma/prisma.service';

const prisma = new PrismaClient();
const service = new ReservationsService(prisma as unknown as PrismaService);

/** How many diners race for the same last table. */
const CONCURRENCY = 25;

let ownerUserId: string;
let ownerId: string;
let restaurantId: string;
let tableId: string;

/** Tomorrow 21:00 UTC — deterministic, never collides with other test data. */
const SLOT = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(21, 0, 0, 0);
  return d;
})();

beforeAll(async () => {
  await prisma.$connect();

  ownerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: ownerUserId,
      phone: `+2010${Date.now().toString().slice(-8)}`,
      fullName: 'Concurrency Test Owner',
      status: 'active',
    },
  });

  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Concurrency Test Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  // location is PostGIS and unsupported by Prisma — insert via raw SQL.
  const slug = `concurrency-test-${Date.now()}`;
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, location, status, city, slot_interval_min)
    VALUES (
      ${ownerId}::uuid, ${slug}, 'Concurrency Test', 'اختبار التزامن',
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', 30
    )
    RETURNING id`;
  restaurantId = rows[0].id;

  // EXACTLY ONE table. This is the last table in the house.
  const table = await prisma.table.create({
    data: {
      restaurantId,
      name: 'T1',
      minCapacity: 1,
      maxCapacity: 4,
      zone: 'indoor',
      priority: 0,
      active: true,
    },
  });
  tableId = table.id;
}, 60_000);

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

describe('reservation engine — concurrency', () => {
  it(`allows exactly one of ${CONCURRENCY} simultaneous holds on the last table`, async () => {
    const attempts = Array.from({ length: CONCURRENCY }, (_, i) =>
      service
        .createHold({
          restaurantId,
          partySize: 2,
          startsAt: SLOT,
          guestName: `Racer ${i}`,
          guestPhone: '+201000000000',
          // Distinct keys — this is a genuine race, NOT idempotent replay.
          idempotencyKey: randomUUID(),
        })
        .then((r) => ({ ok: true as const, id: r.id }))
        .catch((e) => ({ ok: false as const, code: e?.response?.code ?? e?.code ?? 'unknown' })),
    );

    const results = await Promise.all(attempts);
    const winners = results.filter((r) => r.ok);
    const losers = results.filter((r) => !r.ok);

    // ── The promise to restaurants.
    expect(winners).toHaveLength(1);
    expect(losers).toHaveLength(CONCURRENCY - 1);

    // Losers must fail for the right reason — a 500 would also produce one
    // winner while hiding a real bug.
    for (const l of losers) {
      expect(['slot_taken', 'pacing_limit_reached']).toContain(l.code);
    }

    // ── And the database agrees.
    const live = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n
      FROM reservation_tables rt
      JOIN reservations r ON r.id = rt.reservation_id
      WHERE rt.table_id = ${tableId}::uuid
        AND rt.active
        AND r.status IN ('held','pending','confirmed','seated')`;
    expect(Number(live[0].n)).toBe(1);
  }, 120_000);

  it('layer 3 alone rejects an overlap even when the service is bypassed', async () => {
    // Simulate layers 1-2 regressing: write straight to the join table.
    const held = await prisma.reservation.findFirst({
      where: { restaurantId, status: ReservationStatus.held },
    });
    expect(held).not.toBeNull();

    const rogue = await prisma.reservation.create({
      data: {
        code: `SAH-R${Date.now().toString().slice(-3)}`,
        restaurantId,
        partySize: 2,
        // Overlaps the winner's window by 30 minutes.
        startsAt: new Date(SLOT.getTime() + 30 * 60_000),
        endsAt: new Date(SLOT.getTime() + 120 * 60_000),
        status: ReservationStatus.held,
        guestName: 'Rogue Writer',
      },
    });

    await expect(
      prisma.$executeRaw`
        INSERT INTO reservation_tables (reservation_id, table_id, during, active)
        VALUES (
          ${rogue.id}::uuid, ${tableId}::uuid,
          tstzrange(${rogue.startsAt}, ${rogue.endsAt}, '[)'), true
        )`,
    ).rejects.toMatchObject({ code: '23P01' }); // exclusion_violation

    await prisma.reservation.delete({ where: { id: rogue.id } });
  }, 60_000);

  it('replaying the same Idempotency-Key returns the original reservation', async () => {
    const key = randomUUID();
    const slot = new Date(SLOT.getTime() + 4 * 60 * 60_000); // a free window

    const first = await service.createHold({
      restaurantId,
      partySize: 2,
      startsAt: slot,
      guestName: 'Replay',
      idempotencyKey: key,
    });
    const second = await service.createHold({
      restaurantId,
      partySize: 2,
      startsAt: slot,
      guestName: 'Replay',
      idempotencyKey: key,
    });

    expect(second.id).toBe(first.id);

    const count = await prisma.reservation.count({ where: { idempotencyKey: key } });
    expect(count).toBe(1);
  }, 60_000);
});
