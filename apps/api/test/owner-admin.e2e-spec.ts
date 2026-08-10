/**
 * The owner's book (doc 06 §4) and admin approval (doc 06 §5).
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — OwnerReservationsService and
 * AdminRestaurantsService do not exist yet.
 *
 * The load-bearing assertion here is the SERVICE DAY. A Cairo restaurant's
 * "tonight" runs past midnight, and Cairo is UTC+2/+3, so filtering the book
 * by UTC calendar day splits one evening's service across two pages: the
 * 01:00 covers land on yesterday and the host loses them. The book must be
 * cut on the venue's local day, using the same conversion availability uses.
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { OwnerReservationsService } from '../src/modules/restaurants/owner-reservations.service';
import { AdminRestaurantsService } from '../src/modules/admin/admin-restaurants.service';
import { AuditService } from '../src/shared/audit/audit.service';
import { RestaurantsService } from '../src/modules/restaurants/restaurants.service';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const book = new OwnerReservationsService(p);
const admin = new AdminRestaurantsService(p, new AuditService(p));
const restaurants = new RestaurantsService(p);

/** August ⇒ Cairo is UTC+3 (EEST). */
const SERVICE_DAY = '2026-08-05';

let ownerUserId: string;
let ownerId: string;
let adminUserId: string;
let plainUserId: string;
let restaurantId: string;
let tableId: string;

/**
 * Insert a reservation directly at a known ABSOLUTE instant.
 *
 * `source = 'phone'`, not `'app'`. These fixtures carry a guest NAME and no
 * account, which is a staff-taken booking (R-3.2) — and the constraint
 * `app_booking_has_diner` correctly refuses to call that an app booking. This
 * suite is about the owner's BOOK, so which door a row came through is
 * incidental; naming it honestly is not.
 *
 * (A backtick inside the SQL below would end the template literal, which is
 * why this note lives up here rather than as a `--` comment in the query.)
 */
async function seatAt(utcIso: string, guest: string, status = 'confirmed'): Promise<string> {
  const startsAt = new Date(utcIso);
  const endsAt = new Date(startsAt.getTime() + 90 * 60_000);
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (
      code, restaurant_id, guest_name, party_size, starts_at, ends_at,
      status, source, created_at, updated_at
    ) VALUES (
      ${'SAH-' + Math.random().toString(36).slice(2, 6).toUpperCase()},
      ${restaurantId}::uuid, ${guest}, 2, ${startsAt}, ${endsAt},
      ${status}::reservation_status, 'phone', now(), now()
    ) RETURNING id`;
  await prisma.$executeRaw`
    INSERT INTO reservation_tables (reservation_id, table_id, during, active)
    VALUES (${rows[0].id}::uuid, ${tableId}::uuid,
            tstzrange(${startsAt}, ${endsAt}, '[)'), true)`;
  return rows[0].id;
}

beforeAll(async () => {
  await prisma.$connect();
  const stamp = Date.now().toString().slice(-8);

  ownerUserId = randomUUID();
  adminUserId = randomUUID();
  plainUserId = randomUUID();

  await prisma.user.createMany({
    data: [
      { id: ownerUserId, phone: `+2013${stamp}`, fullName: 'Book Owner', status: 'active' },
      { id: adminUserId, phone: `+2014${stamp}`, fullName: 'Platform Admin', status: 'active' },
      { id: plainUserId, phone: `+2015${stamp}`, fullName: 'Just A Diner', status: 'active' },
    ],
  });

  const adminRole = await prisma.role.upsert({
    where: { name: 'admin' }, update: {}, create: { name: 'admin' },
  });
  await prisma.userRole.create({ data: { userId: adminUserId, roleId: adminRole.id } });

  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Book Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const r = await restaurants.create(ownerId, {
    nameEn: 'Book Test Venue', nameAr: 'مطعم الدفتر',
    lat: 30.0622, lng: 31.2185, city: 'Cairo',
  });
  restaurantId = r.id;
  // Explicitly Cairo — the point of these tests.
  await prisma.$executeRaw`
    UPDATE restaurants SET timezone = 'Africa/Cairo' WHERE id = ${restaurantId}::uuid`;

  const t = await prisma.table.create({
    data: { restaurantId, name: 'B1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
  });
  tableId = t.id;
}, 60_000);

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  await prisma.userRole.deleteMany({ where: { userId: adminUserId } }).catch(() => undefined);
  await prisma.user.deleteMany({
    where: { id: { in: [ownerUserId, adminUserId, plainUserId].filter(Boolean) } },
  }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

// ───────────────────────────────────────────────── the owner's book (§4) ──

describe("owner's reservation book (doc 06 §4)", () => {
  it('reports every time on the venue wall clock, not UTC', async () => {
    // 19:00 Cairo on the service day = 16:00Z (UTC+3 in August).
    await seatAt('2026-08-05T16:00:00.000Z', 'Evening Guest');

    const res = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });

    expect(res.timezone).toBe('Africa/Cairo');
    const row = res.reservations.find((r) => r.guestName === 'Evening Guest');
    expect(row).toBeDefined();
    // The host reads 19:00 off the screen; 16:00 would be three hours wrong.
    expect(row!.time).toBe('19:00');
    expect(row!.startsAt).toBe('2026-08-05T16:00:00.000Z');
  }, 60_000);

  it('cuts the day on the VENUE clock, so after-midnight covers stay on their service night', async () => {
    // 01:00 Cairo on 6 Aug = 22:00Z on 5 Aug. Filtering by UTC day would file
    // this under the 5th and the host would never see it on the 6th.
    await seatAt('2026-08-05T22:00:00.000Z', 'Late Night Guest');

    const sixth = await book.listForDate({ ownerId, restaurantId, date: '2026-08-06' });
    expect(sixth.reservations.map((r) => r.guestName)).toContain('Late Night Guest');
    expect(sixth.reservations.find((r) => r.guestName === 'Late Night Guest')!.time).toBe('01:00');

    // …and it must NOT also appear on the 5th, which UTC filtering would do.
    const fifth = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });
    expect(fifth.reservations.map((r) => r.guestName)).not.toContain('Late Night Guest');
  }, 60_000);

  it('excludes the previous evening', async () => {
    // 23:00 Cairo on 4 Aug = 20:00Z on 4 Aug — the night before.
    await seatAt('2026-08-04T20:00:00.000Z', 'Yesterday Guest');
    const res = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });
    expect(res.reservations.map((r) => r.guestName)).not.toContain('Yesterday Guest');
  }, 60_000);

  it('orders the book by seating time', async () => {
    await seatAt('2026-08-05T18:30:00.000Z', 'Later Guest'); // 21:30 local
    const res = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });
    const times = res.reservations.map((r) => r.time);
    expect([...times]).toEqual([...times].sort());
  }, 60_000);

  it('filters by status', async () => {
    await seatAt('2026-08-05T17:00:00.000Z', 'Cancelled Guest', 'cancelled_by_user');

    const all = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });
    expect(all.reservations.map((r) => r.guestName)).toContain('Cancelled Guest');

    const confirmed = await book.listForDate({
      ownerId, restaurantId, date: SERVICE_DAY, status: 'confirmed',
    });
    expect(confirmed.reservations.map((r) => r.guestName)).not.toContain('Cancelled Guest');
  }, 60_000);

  it('includes the allocated tables and party size', async () => {
    const res = await book.listForDate({ ownerId, restaurantId, date: SERVICE_DAY });
    const row = res.reservations.find((r) => r.guestName === 'Evening Guest')!;
    expect(row.partySize).toBe(2);
    expect(row.tables).toContain('B1');
  }, 60_000);

  it("refuses another owner's book", async () => {
    await expect(
      book.listForDate({ ownerId: randomUUID(), restaurantId, date: SERVICE_DAY }),
    ).rejects.toMatchObject({ response: { code: 'restaurant_not_found' } });
  }, 60_000);
});

// ───────────────────────────────────────────── admin approve/reject (§5) ──

describe('admin approval (doc 06 §5)', () => {
  it('refuses a caller without the admin role', async () => {
    await expect(
      admin.approve({ actorId: plainUserId, actorRoles: ['customer'], restaurantId }),
    ).rejects.toMatchObject({ response: { code: 'forbidden_role' } });
  }, 60_000);

  it('refuses to approve a restaurant that is not pending_review', async () => {
    // It is still draft at this point.
    await expect(
      admin.approve({ actorId: adminUserId, actorRoles: ['admin'], restaurantId }),
    ).rejects.toMatchObject({ response: { code: 'invalid_status_transition' } });
  }, 60_000);

  it('approves pending_review → active', async () => {
    await restaurants.submitForReview(ownerId, restaurantId);
    const out = await admin.approve({ actorId: adminUserId, actorRoles: ['admin'], restaurantId });
    expect(out.status).toBe('active');
  }, 60_000);

  it('lists the pending_review queue', async () => {
    // Put it back in the queue to be found.
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'pending_review' WHERE id = ${restaurantId}::uuid`;
    const queue = await admin.listPendingReview({ actorRoles: ['admin'] });
    expect(queue.map((r) => r.id)).toContain(restaurantId);
  }, 60_000);

  it('rejects with a reason, returning the venue to draft so the owner can fix it', async () => {
    const out = await admin.reject({
      actorId: adminUserId, actorRoles: ['admin'], restaurantId, reason: 'Photos are too low-res.',
    });
    expect(out.status).toBe('draft');
  }, 60_000);

  it('a moderator may read the queue but not approve', async () => {
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'pending_review' WHERE id = ${restaurantId}::uuid`;

    await expect(admin.listPendingReview({ actorRoles: ['moderator'] })).resolves.toBeDefined();
    await expect(
      admin.approve({ actorId: adminUserId, actorRoles: ['moderator'], restaurantId }),
    ).rejects.toMatchObject({ response: { code: 'forbidden_role' } });
  }, 60_000);
});
