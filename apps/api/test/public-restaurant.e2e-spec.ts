/**
 * The public restaurant profile — doc 06 §3:
 *
 *   | `/restaurants/:idOrSlug` | GET | Full profile: photos, hours, policies,
 *   |                          |     | rating, amenities |
 *
 * WRITTEN BEFORE THE IMPLEMENTATION. `GET /v1/restaurants/:idOrSlug` does not
 * exist; every request below is expected to 404 on the first run for the wrong
 * reason (no route) before it passes for the right one.
 *
 * This is the one contract the customer app cannot be built without. Search
 * returns a teaser and availability returns times; neither carries a
 * description, an address, opening hours or a phone number, so a "restaurant
 * detail" screen built on what exists today would have to invent them.
 *
 * Two behaviours here are security, not presentation:
 *
 *   - A venue that is not `active` is 404, never 403. A 403 confirms the row
 *     exists, which turns this endpoint into an enumeration oracle for
 *     competitors' unlaunched venues.
 *   - No authentication. Guest browsing all the way to the booking button is
 *     C-1.6, and gating discovery behind login is exactly the drop-off the
 *     requirement exists to avoid.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;

let ownerUserId: string;
let ownerId: string;
let activeId: string;
let activeSlug: string;
let draftId: string;

const suffix = Date.now().toString().slice(-8);

async function makeVenue(name: string, status: 'active' | 'draft'): Promise<{ id: string; slug: string }> {
  const slug = `${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${suffix}`;
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, description_en, description_ar,
      cuisines, phone, website, address_en, address_ar,
      city, neighborhood, location, price_band, amenities, policies,
      booking_mode, slot_interval_min, rating_avg, rating_count,
      status, timezone, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${slug}, ${name}, 'مطعم الاختبار',
      'A Nile-side terrace built for long evenings.', 'تراس على النيل للسهرات الطويلة.',
      ARRAY['levantine','egyptian'], '+20 2 2735 0000', 'https://example.test',
      '26th of July St, Zamalek', 'شارع 26 يوليو، الزمالك',
      'Cairo', 'Zamalek', ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      3, '{"outdoor":true,"shisha":true}'::jsonb,
      '{"cancellation_hours":2}'::jsonb,
      'instant', 30, 4.80, 312,
      ${status}::restaurant_status, 'Africa/Cairo', now(), now()
    ) RETURNING id`;
  return { id: rows[0].id, slug };
}

beforeAll(async () => {
  await prisma.$connect();

  ownerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: ownerUserId,
      phone: `+2012${suffix}`,
      fullName: 'Public Profile Owner',
      status: 'active',
    },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Public Profile Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const active = await makeVenue('Public Profile Venue', 'active');
  activeId = active.id;
  activeSlug = active.slug;
  draftId = (await makeVenue('Unlaunched Venue', 'draft')).id;

  // Two shifts on the SAME weekday, so the response has to union them rather
  // than pick the first — a venue with lunch and dinner is the normal case,
  // and `shiftFor`-style code that takes findFirst silently hides one.
  const dow = 3;
  await prisma.$executeRaw`
    INSERT INTO shifts (restaurant_id, name_en, name_ar, day_of_week,
                        opens_at, closes_at, spans_midnight, default_turn_minutes,
                        active, created_at, updated_at)
    VALUES
      (${activeId}::uuid, 'Lunch',  'الغداء', ${dow}, '12:00', '16:00', false, '{"1-2":90}'::jsonb, true,  now(), now()),
      (${activeId}::uuid, 'Dinner', 'العشاء', ${dow}, '18:00', '23:00', false, '{"1-2":90}'::jsonb, true,  now(), now()),
      (${activeId}::uuid, 'Retired','ملغي',   ${dow}, '02:00', '04:00', false, '{"1-2":90}'::jsonb, false, now(), now())`;

  const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();
}, 90_000);

afterAll(async () => {
  if (app) await app.close();
  for (const id of [activeId, draftId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM shifts      WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id            = ${id}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

describe('GET /v1/restaurants/:idOrSlug (doc 06 §3)', () => {
  it('returns the full profile by id, with no Authorization header', async () => {
    const res = await request(http as never).get(`/v1/restaurants/${activeId}`).expect(200);

    expect(res.body).toMatchObject({
      id: activeId,
      slug: activeSlug,
      name_en: 'Public Profile Venue',
      name_ar: 'مطعم الاختبار',
      cuisines: ['levantine', 'egyptian'],
      neighborhood: 'Zamalek',
      city: 'Cairo',
      price_band: 3,
      rating: 4.8,
      rating_count: 312,
      phone: '+20 2 2735 0000',
      timezone: 'Africa/Cairo',
      booking_mode: 'instant',
    });
    expect(res.body.description_en).toContain('Nile-side');
    expect(res.body.description_ar).toContain('تراس');
    expect(res.body.address_en).toContain('Zamalek');
    expect(res.body.amenities).toEqual(expect.arrayContaining(['outdoor', 'shisha']));
    expect(res.body.policies).toMatchObject({ cancellation_hours: 2 });
  });

  it('resolves the same venue by slug', async () => {
    const byId = await request(http as never).get(`/v1/restaurants/${activeId}`).expect(200);
    const bySlug = await request(http as never).get(`/v1/restaurants/${activeSlug}`).expect(200);
    expect(bySlug.body).toEqual(byId.body);
  });

  it('carries lat/lng as numbers, in that order', async () => {
    // ST_MakePoint is (lng, lat). Reversing them puts Zamalek in the Indian
    // Ocean and no type catches it, so the values are asserted, not the shape.
    const res = await request(http as never).get(`/v1/restaurants/${activeId}`).expect(200);
    expect(res.body.lat).toBeCloseTo(30.0622, 4);
    expect(res.body.lng).toBeCloseTo(31.2185, 4);
  });

  it('unions every ACTIVE shift on a weekday, and drops inactive ones', async () => {
    const res = await request(http as never).get(`/v1/restaurants/${activeId}`).expect(200);

    const wed = (res.body.hours as { day_of_week: number }[]).filter((h) => h.day_of_week === 3);
    expect(wed).toHaveLength(2);
    expect(wed.map((h) => (h as unknown as { opens_at: string }).opens_at)).toEqual(['12:00', '18:00']);
    expect(res.body.hours).not.toContainEqual(expect.objectContaining({ name_en: 'Retired' }));
  });

  it('404s an unknown id inside the doc 06 §1 envelope', async () => {
    const res = await request(http as never).get(`/v1/restaurants/${randomUUID()}`).expect(404);
    expect(res.body.error.code).toBe('restaurant_not_found');
    expect(typeof res.body.error.message_ar).toBe('string');
    expect(res.body.error.message_ar.length).toBeGreaterThan(0);
  });

  it('404s a venue that is not active — never 403, which would confirm it exists', async () => {
    const res = await request(http as never).get(`/v1/restaurants/${draftId}`).expect(404);
    expect(res.body.error.code).toBe('restaurant_not_found');
  });

  it('404s a slug-shaped string that matches nothing, without a 500', async () => {
    const res = await request(http as never).get('/v1/restaurants/no-such-venue-anywhere').expect(404);
    expect(res.body.error.code).toBe('restaurant_not_found');
  });

  it('does not shadow /restaurants/search', async () => {
    // `:idOrSlug` is a wildcard on the same base path as the search route.
    // Nest resolves by registration order, which is a property of module
    // imports and therefore silently reorderable — so it is asserted here
    // rather than assumed. A shadowed search is a 404 on the app's home
    // screen, and nothing else in the suite would notice.
    const res = await request(http as never).get('/v1/restaurants/search?q=zzz-no-such-venue');
    expect(res.status).not.toBe(404);
    expect(res.body).not.toHaveProperty('slug');
  });
});
