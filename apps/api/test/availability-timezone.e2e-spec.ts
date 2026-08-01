/**
 * Availability must derive from the RESTAURANT'S timezone, not the server's.
 *
 * doc 04 §3: "All timestamps TIMESTAMPTZ; restaurant-local logic derives from
 * the restaurant's `timezone`." Shifts store wall-clock TIME (18:00 means six
 * in the evening *there*), so turning that into an absolute instant requires
 * the venue's zone and the DST rules in force on that specific date.
 *
 * WRITTEN AGAINST THE BUG. Under the current UTC implementation every
 * assertion on `startsAt` below fails: 18:00 local is emitted as 18:00Z
 * regardless of zone or season.
 *
 * Egypt observes DST (reinstated 2023): last Friday of April → last Thursday
 * of October. So the SAME shift is a different absolute instant in January
 * than in August — which is exactly what a fixed +02:00 offset hack would get
 * wrong, and why both seasons are tested.
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const availability = new AvailabilityService(prisma as unknown as PrismaService);

/** Egypt: EET (UTC+2) in January, EEST (UTC+3) in August. */
const WINTER = '2026-01-07';
const SUMMER = '2026-08-05';
/** Dubai: UTC+4 all year, no DST — proves the zone is not hardcoded to Cairo. */
const DUBAI_DAY = '2026-08-05';

let ownerUserId: string;
let ownerId: string;
let cairoId: string;
let dubaiId: string;

async function makeVenue(slug: string, timezone: string): Promise<string> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, cuisines, location,
      status, city, timezone, slot_interval_min, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${slug}, 'TZ Test', 'اختبار التوقيت',
      ARRAY['levantine']::text[],
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', ${timezone}, 60, now(), now()
    ) RETURNING id`;
  return rows[0].id;
}

/** A dinner shift on one specific calendar date, 18:00–23:00 wall-clock. */
async function makeShift(restaurantId: string, date: string): Promise<void> {
  await prisma.shift.create({
    data: {
      restaurantId,
      nameEn: 'Dinner',
      nameAr: 'العشاء',
      specificDate: new Date(`${date}T00:00:00.000Z`),
      opensAt: new Date('1970-01-01T18:00:00.000Z'),
      closesAt: new Date('1970-01-01T23:00:00.000Z'),
      defaultTurnMinutes: { '1-2': 90, '3-4': 105, '5+': 120 },
    },
  });
}

beforeAll(async () => {
  await prisma.$connect();
  ownerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: ownerUserId,
      phone: `+2012${Date.now().toString().slice(-8)}`,
      fullName: 'TZ Test Owner',
      status: 'active',
    },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'TZ Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const stamp = Date.now();
  cairoId = await makeVenue(`tz-cairo-${stamp}`, 'Africa/Cairo');
  dubaiId = await makeVenue(`tz-dubai-${stamp}`, 'Asia/Dubai');

  await makeShift(cairoId, WINTER);
  await makeShift(cairoId, SUMMER);
  await makeShift(dubaiId, DUBAI_DAY);

  await prisma.table.create({
    data: { restaurantId: cairoId, name: 'C1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
  });
  await prisma.table.create({
    data: { restaurantId: dubaiId, name: 'D1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
  });
}, 60_000);

afterAll(async () => {
  for (const id of [cairoId, dubaiId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${id}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

describe('availability — restaurant-local timezone (doc 04 §3)', () => {
  it('emits the local wall-clock time the shift was written in', async () => {
    const res = await availability.getSlots({ restaurantId: cairoId, date: SUMMER, partySize: 2 });
    expect(res.slots.length).toBeGreaterThan(0);
    // The diner asked for dinner at 18:00; they must be shown 18:00.
    expect(res.slots[0].time).toBe('18:00');
  }, 60_000);

  it('resolves 18:00 Cairo in SUMMER to 15:00Z (EEST, UTC+3)', async () => {
    const res = await availability.getSlots({ restaurantId: cairoId, date: SUMMER, partySize: 2 });
    // Under the UTC implementation this is 18:00Z — three hours wrong.
    expect(res.slots[0].startsAt).toBe('2026-08-05T15:00:00.000Z');
  }, 60_000);

  it('resolves 18:00 Cairo in WINTER to 16:00Z (EET, UTC+2)', async () => {
    const res = await availability.getSlots({ restaurantId: cairoId, date: WINTER, partySize: 2 });
    // A hardcoded +03:00 would pass the summer case and fail here; a
    // hardcoded +02:00 the reverse. Only real DST handling passes both.
    expect(res.slots[0].startsAt).toBe('2026-01-07T16:00:00.000Z');
  }, 60_000);

  it('shifts the same wall-clock shift by an hour across the DST boundary', async () => {
    const [summer, winter] = await Promise.all([
      availability.getSlots({ restaurantId: cairoId, date: SUMMER, partySize: 2 }),
      availability.getSlots({ restaurantId: cairoId, date: WINTER, partySize: 2 }),
    ]);

    // Identical local time…
    expect(summer.slots[0].time).toBe(winter.slots[0].time);
    // …different absolute instant, by exactly one hour.
    const sUtc = new Date(summer.slots[0].startsAt).getUTCHours();
    const wUtc = new Date(winter.slots[0].startsAt).getUTCHours();
    expect(wUtc - sUtc).toBe(1);
  }, 60_000);

  it('uses each venue\'s own zone, not a global default', async () => {
    const dubai = await availability.getSlots({ restaurantId: dubaiId, date: DUBAI_DAY, partySize: 2 });
    expect(dubai.slots[0].time).toBe('18:00');
    // Dubai is UTC+4 year-round.
    expect(dubai.slots[0].startsAt).toBe('2026-08-05T14:00:00.000Z');
  }, 60_000);

  it('the last seating still finishes before local close', async () => {
    const res = await availability.getSlots({ restaurantId: cairoId, date: SUMMER, partySize: 2 });
    const times = res.slots.map((s) => s.time);
    // 60-min grid, 18:00–23:00 local, 90-min turn ⇒ last bookable is 21:00
    // (21:00 + 1h30 = 22:30 ≤ 23:00); 22:00 would overrun.
    expect(times).toContain('21:00');
    expect(times).not.toContain('22:00');
    expect(times).not.toContain('23:00');
  }, 60_000);

  it('a hold placed at the advertised instant lands on that local slot', async () => {
    const res = await availability.getSlots({ restaurantId: cairoId, date: SUMMER, partySize: 2 });
    const slot = res.slots.find((s) => s.time === '19:00')!;
    expect(slot).toBeDefined();

    // The instant the API advertises is the instant a client would POST.
    // If these disagree, clients silently book the wrong hour.
    const asDate = new Date(slot.startsAt);
    const localHour = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Africa/Cairo',
      hour: '2-digit',
      hour12: false,
    }).format(asDate);
    expect(localHour).toBe('19');
  }, 60_000);
});
