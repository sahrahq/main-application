/**
 * Discovery search (doc 06 §3) — Meilisearch + availability post-filter.
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — nothing under modules/search/ exists.
 *
 * Two rules this suite exists to hold:
 *
 *  1. `next_available` comes from AvailabilityService — the SAME code path a
 *     hold uses. Never from a field cached in the Meilisearch document.
 *     Availability is derived, never stored (doc 05 §1), and an index is by
 *     definition stale.
 *
 *  2. Search never PROMISES a table. A slot shown in results is a hint; the
 *     hold re-validates and returns slot_taken if it has gone. Search making a
 *     guarantee it cannot keep is the failure mode search exists to prevent.
 */
import { PrismaClient } from '@prisma/client';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { AvailabilityService } from '../src/modules/availability/availability.service';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { AdminRestaurantsService } from '../src/modules/admin/admin-restaurants.service';
import { RestaurantsService } from '../src/modules/restaurants/restaurants.service';
import { AuditService } from '../src/shared/audit/audit.service';
import { MeiliSearchIndex } from '../src/modules/search/meili-search.index';
import { RestaurantSearchService, SEARCH_PAGE_SIZE } from '../src/modules/search/restaurant-search.service';

const MEILI_UP = process.env.MEILI_AVAILABLE === '1';
const describeIf = MEILI_UP ? describe : describe.skip;

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const availability = new AvailabilityService(p);
const reservations = new ReservationsService(p);
const restaurants = new RestaurantsService(p);
const audit = new AuditService(p);

let index: MeiliSearchIndex;
let search: RestaurantSearchService;
let admin: AdminRestaurantsService;

let ownerUserId: string;
let ownerId: string;
let adminUserId: string;
const made: string[] = [];

/** +3 days so this suite cannot collide with the expiry suites. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 3);
  return d.toISOString().slice(0, 10);
})();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);

async function makeVenue(opts: {
  nameEn: string; nameAr: string; cuisines: string[];
  neighborhood: string; priceBand: number; withTable?: boolean;
}): Promise<string> {
  const r = await restaurants.create(ownerId, {
    nameEn: opts.nameEn, nameAr: opts.nameAr, cuisines: opts.cuisines,
    neighborhood: opts.neighborhood, priceBand: opts.priceBand,
    lat: 30.0622, lng: 31.2185, city: 'Cairo',
  });
  made.push(r.id);
  await prisma.$executeRaw`UPDATE restaurants SET timezone = 'UTC' WHERE id = ${r.id}::uuid`;

  await prisma.shift.create({
    data: {
      restaurantId: r.id, nameEn: 'Dinner', nameAr: 'العشاء',
      dayOfWeek: new Date(`${DATE}T12:00:00Z`).getUTCDay(),
      opensAt: new Date('1970-01-01T18:00:00.000Z'),
      closesAt: new Date('1970-01-01T23:00:00.000Z'),
      defaultTurnMinutes: { '1-2': 90, '3-4': 105, '5+': 120 },
    },
  });
  if (opts.withTable !== false) {
    await prisma.table.create({
      data: { restaurantId: r.id, name: 'S1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
    });
  }
  return r.id;
}

const activate = async (id: string): Promise<void> => {
  await prisma.$executeRaw`UPDATE restaurants SET status='pending_review' WHERE id=${id}::uuid`;
  await admin.approve({ actorId: adminUserId, actorRoles: ['admin'], restaurantId: id });
};

beforeAll(async () => {
  await prisma.$connect();
  if (!MEILI_UP) return;

  index = new MeiliSearchIndex(process.env.MEILISEARCH_HOST ?? 'http://localhost:7700', undefined, `restaurants-test-${Date.now()}`);
  await index.ensureIndex();
  search = new RestaurantSearchService(p, index, availability);
  admin = new AdminRestaurantsService(p, audit, index);

  const stamp = Date.now().toString().slice(-8);
  ownerUserId = randomUUID();
  adminUserId = randomUUID();
  await prisma.user.createMany({
    data: [
      { id: ownerUserId, phone: `+2020${stamp}`, fullName: 'Search Owner', status: 'active' },
      { id: adminUserId, phone: `+2021${stamp}`, fullName: 'Search Admin', status: 'active' },
    ],
  });
  const role = await prisma.role.upsert({ where: { name: 'admin' }, update: {}, create: { name: 'admin' } });
  await prisma.userRole.create({ data: { userId: adminUserId, roleId: role.id } });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Search Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;
}, 120_000);

afterAll(async () => {
  if (MEILI_UP && index) await index.dropIndex().catch(() => undefined);
  for (const id of made) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${id}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  await prisma.userRole.deleteMany({ where: { userId: adminUserId } }).catch(() => undefined);
  await prisma.user.deleteMany({
    where: { id: { in: [ownerUserId, adminUserId].filter(Boolean) } },
  }).catch(() => undefined);
  await prisma.$disconnect();
}, 120_000);

// ───────────────────────────────────────────── indexing on the write path ──

describeIf('index sync via admin decisions (doc 06 §5)', () => {
  it('a DRAFT restaurant is not searchable', async () => {
    const id = await makeVenue({
      nameEn: 'Hidden Draft Venue', nameAr: 'مطعم المسودة',
      cuisines: ['levantine'], neighborhood: 'Zamalek', priceBand: 3,
    });
    const res = await search.search({ q: 'Hidden Draft' });
    expect(res.results.map((r) => r.id)).not.toContain(id);
  }, 60_000);

  it('approving indexes it; rejecting removes it again', async () => {
    const id = await makeVenue({
      nameEn: 'Toggle Venue', nameAr: 'مطعم التبديل',
      cuisines: ['egyptian'], neighborhood: 'Downtown', priceBand: 2,
    });

    await activate(id);
    await index.waitForIdle();
    expect((await search.search({ q: 'Toggle' })).results.map((r) => r.id)).toContain(id);

    // Reject sends it back to draft — it must leave the index, or a venue that
    // is not live stays bookable from search.
    await prisma.$executeRaw`UPDATE restaurants SET status='pending_review' WHERE id=${id}::uuid`;
    await admin.reject({ actorId: adminUserId, actorRoles: ['admin'], restaurantId: id, reason: 'test' });
    await index.waitForIdle();
    expect((await search.search({ q: 'Toggle' })).results.map((r) => r.id)).not.toContain(id);
  }, 60_000);
});

// ────────────────────────────────────────────────── matching and filtering ──

describeIf('search matching (doc 06 §3)', () => {
  let sequoia: string;
  let zooba: string;

  beforeAll(async () => {
    sequoia = await makeVenue({
      nameEn: 'Sequoia Nile', nameAr: 'سيكويا النيل',
      cuisines: ['mediterranean', 'levantine'], neighborhood: 'Zamalek', priceBand: 4,
    });
    zooba = await makeVenue({
      nameEn: 'Zooba Street Food', nameAr: 'زوبا',
      cuisines: ['egyptian'], neighborhood: 'Downtown', priceBand: 2,
    });
    await activate(sequoia);
    await activate(zooba);
    await index.waitForIdle();
  }, 120_000);

  it('matches on the English name', async () => {
    const res = await search.search({ q: 'Sequoia' });
    expect(res.results.map((r) => r.id)).toContain(sequoia);
  }, 60_000);

  it('matches on the ARABIC name — bilingual by column, not by translation table', async () => {
    const res = await search.search({ q: 'زوبا' });
    expect(res.results.map((r) => r.id)).toContain(zooba);
  }, 60_000);

  it('filters by cuisine', async () => {
    const res = await search.search({ cuisine: 'egyptian' });
    const ids = res.results.map((r) => r.id);
    expect(ids).toContain(zooba);
    expect(ids).not.toContain(sequoia);
  }, 60_000);

  it('filters by neighborhood and price band', async () => {
    const res = await search.search({ neighborhood: 'Zamalek', priceBand: 4 });
    expect(res.results.map((r) => r.id)).toContain(sequoia);
    expect(res.results.map((r) => r.id)).not.toContain(zooba);
  }, 60_000);

  it('returns both locales on every result (CLAUDE.md: bilingual by column)', async () => {
    const res = await search.search({ q: 'Sequoia' });
    const row = res.results.find((r) => r.id === sequoia)!;
    expect(row.name_en).toBe('Sequoia Nile');
    expect(row.name_ar).toBe('سيكويا النيل');
  }, 60_000);

  it('renders display fields from POSTGRES, not from the indexed document', async () => {
    // The index decides WHICH venues match; the database decides WHAT is
    // shown. Renaming in Postgres without touching the index must surface the
    // new name — otherwise search serves stale data indefinitely.
    await prisma.$executeRaw`
      UPDATE restaurants SET name_en = 'Sequoia Renamed' WHERE id = ${sequoia}::uuid`;
    const res = await search.search({ q: 'Sequoia' });
    expect(res.results.find((r) => r.id === sequoia)!.name_en).toBe('Sequoia Renamed');
    await prisma.$executeRaw`
      UPDATE restaurants SET name_en = 'Sequoia Nile' WHERE id = ${sequoia}::uuid`;
  }, 60_000);
});

// ───────────────────────────────────────────── the availability post-filter ──

describeIf('availability post-filter (doc 06 §3)', () => {
  let withTables: string;
  let noTables: string;

  beforeAll(async () => {
    withTables = await makeVenue({
      nameEn: 'Postfilter Open', nameAr: 'مفتوح',
      cuisines: ['levantine'], neighborhood: 'Maadi', priceBand: 3,
    });
    noTables = await makeVenue({
      nameEn: 'Postfilter Full', nameAr: 'ممتلئ',
      cuisines: ['levantine'], neighborhood: 'Maadi', priceBand: 3, withTable: false,
    });
    await activate(withTables);
    await activate(noTables);
    await index.waitForIdle();
  }, 120_000);

  it('adds next_available from AvailabilityService when a window is asked for', async () => {
    const res = await search.search({
      q: 'Postfilter', date: DATE, partySize: 2,
    });
    const row = res.results.find((r) => r.id === withTables)!;
    expect(row).toBeDefined();
    expect(Array.isArray(row.next_available)).toBe(true);
    expect(row.next_available!.length).toBeGreaterThan(0);

    // Must equal what the booking path itself would offer — same service, so
    // search cannot advertise a slot the engine does not recognise.
    const truth = await availability.getSlots({ restaurantId: withTables, date: DATE, partySize: 2 });
    expect(row.next_available!.every((t) => truth.slots.some((s) => s.time === t))).toBe(true);
  }, 60_000);

  it('DROPS a venue with nothing bookable in the window', async () => {
    const res = await search.search({ q: 'Postfilter', date: DATE, partySize: 2 });
    const ids = res.results.map((r) => r.id);
    expect(ids).toContain(withTables);
    // A venue with no tables can never seat anyone — showing it is the exact
    // dead end this filter exists to prevent.
    expect(ids).not.toContain(noTables);
  }, 60_000);

  it('omits next_available entirely when no window was asked for', async () => {
    const res = await search.search({ q: 'Postfilter' });
    const row = res.results.find((r) => r.id === withTables)!;
    // Absent, never [] — an empty array reads as "no availability".
    expect(row.next_available).toBeUndefined();
  }, 60_000);

  it(`computes availability for at most one page (${SEARCH_PAGE_SIZE})`, async () => {
    const spy = jest.spyOn(availability, 'getSlots');
    spy.mockClear();
    await search.search({ q: 'Postfilter', date: DATE, partySize: 2 });
    expect(spy.mock.calls.length).toBeLessThanOrEqual(SEARCH_PAGE_SIZE);
    spy.mockRestore();
  }, 60_000);
});

// ─────────────────────────────── search must not PROMISE a table ──

describeIf('a slot shown in search is a hint, not a guarantee', () => {
  it('a stale next_available still fails safe at booking time', async () => {
    const id = await makeVenue({
      nameEn: 'Race Venue', nameAr: 'مطعم السباق',
      cuisines: ['levantine'], neighborhood: 'Heliopolis', priceBand: 3,
    });
    await activate(id);
    await index.waitForIdle();

    const res = await search.search({ q: 'Race Venue', date: DATE, partySize: 2 });
    const row = res.results.find((r) => r.id === id)!;
    const advertised = row.next_available![0];
    expect(advertised).toBeDefined();

    // Someone else books it between the search and the tap.
    await reservations.createHold({
      restaurantId: id, partySize: 2,
      startsAt: new Date(`${DATE}T${advertised}:00.000Z`),
      idempotencyKey: randomUUID(),
    });

    // The diner acts on what search told them. The engine re-validates and
    // says so plainly — never a silent failure, never a double booking.
    await expect(
      reservations.createHold({
        restaurantId: id, partySize: 2,
        startsAt: new Date(`${DATE}T${advertised}:00.000Z`),
        idempotencyKey: randomUUID(),
      }),
    ).rejects.toMatchObject({ response: { code: 'slot_taken' } });
  }, 120_000);
});

// ──────────────────────────────────────────────── the route actually resolves ──

describeIf('GET /restaurants/search (doc 06 §3)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
  }, 120_000);

  afterAll(async () => {
    if (app) await app.close();
  }, 60_000);

  /**
   * doc 06 §3 also specifies `/restaurants/:idOrSlug`. The moment that lands,
   * a bare `:param` route registered before this one swallows the literal
   * `search` segment and the endpoint starts answering "restaurant not found"
   * — a silent failure that no service-level test can see. This locks it.
   */
  it('resolves to search, not to a :idOrSlug lookup', async () => {
    const res = await request(app.getHttpServer()).get('/restaurants/search?q=zzz-no-such-venue');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.results)).toBe(true);
    expect(res.body).toHaveProperty('next_cursor');
  }, 60_000);

  it('rejects available_at without party_size rather than pretending to filter', async () => {
    const res = await request(app.getHttpServer()).get(`/restaurants/search?available_at=${DATE}`);
    expect(res.status).toBe(400);
    expect(res.body.code ?? res.body.message?.code).toBe('invalid_availability_filter');
  }, 60_000);

  it('validates query params', async () => {
    const res = await request(app.getHttpServer()).get('/restaurants/search?price_band=9');
    expect(res.status).toBe(400);
  }, 60_000);
});

describe('meilisearch availability', () => {
  it('states plainly whether the search suites ran', () => {
    // eslint-disable-next-line no-console
    console.log(
      MEILI_UP
        ? '  Search: EXERCISED against live Meilisearch'
        : '  Search: SKIPPED — Meilisearch unreachable',
    );
    expect(typeof MEILI_UP).toBe('boolean');
  });
});
