/**
 * `pnpm seed` — a bookable Cairo, for developing against.
 *
 * Not fixtures. This produces the state a diner would actually meet: venues in
 * three neighbourhoods, tables of mixed capacity, and shifts that are open at
 * the hours Cairo eats. Without it the customer app renders four correct
 * empty states and nothing else, and "the booking path works" cannot be
 * checked by anybody.
 *
 * Idempotent by slug: re-running updates rather than duplicating, so it can be
 * pointed at a database that already has data without wiping it. Reservations
 * are deliberately NOT touched — a seed that deletes bookings would erase the
 * thing you were mid-way through testing.
 *
 *   pnpm seed             # upsert venues, tables, shifts, then index
 *   pnpm seed --reset     # additionally delete THESE venues' reservations
 *
 * The one thing this cannot do is make search work on its own: search is
 * Meilisearch, so the index sync at the end needs MEILISEARCH_HOST. Without
 * it, seeding still succeeds and `/restaurants/search` still 503s — which is
 * correct behaviour and is what the outage test asserts.
 */
import { PrismaClient } from '@prisma/client';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { MeiliSearchIndex, DEFAULT_INDEX_UID } from '../src/modules/search/meili-search.index';
import { loadLiveRows, toSearchDoc } from '../src/modules/search/search-doc';
import { syncMenusAndReviews } from './seed-menus-reviews';

const prisma = new PrismaClient();

const OWNER_PHONE = '+201000000001';
const OWNER_BUSINESS = 'SAHRA Demo Group';

type Zone = 'indoor' | 'outdoor' | 'family' | 'bar' | 'private';

interface SeedTable {
  name: string;
  min: number;
  max: number;
  zone: Zone;
}

interface SeedShift {
  nameEn: string;
  nameAr: string;
  /** Weekdays this shift runs. 0 = Sunday. */
  days: number[];
  opens: string;
  closes: string;
  spansMidnight?: boolean;
}

interface SeedVenue {
  slug: string;
  nameEn: string;
  nameAr: string;
  descriptionEn: string;
  descriptionAr: string;
  cuisines: string[];
  neighborhood: string;
  addressEn: string;
  addressAr: string;
  phone: string;
  lat: number;
  lng: number;
  priceBand: number;
  rating: number;
  ratingCount: number;
  amenities: Record<string, boolean>;
  slotIntervalMin: number;
  tables: SeedTable[];
  shifts: SeedShift[];
}

/** Every day of the week. */
const ALL = [0, 1, 2, 3, 4, 5, 6];

/**
 * Five venues, chosen to make the SCREENS differ rather than to fill a list:
 * a small one that runs out of tables for a party of six, one that is closed
 * on a weekday, one that serves lunch and dinner as separate shifts, one that
 * runs past midnight, and one with a single two-top so `slot_taken` is easy to
 * provoke by hand.
 */
const VENUES: SeedVenue[] = [
  {
    slug: 'layali-lounge-zamalek',
    nameEn: 'Layali Lounge',
    nameAr: 'ليالي لاونج',
    descriptionEn:
      'A Nile-side terrace built for long evenings — mezze, charcoal grills and live oud after ten. '
      + 'Come for the sunset call to prayer, stay for the last table standing.',
    descriptionAr:
      'تراس على النيل متصمم للسهرات الطويلة — مقبّلات، مشويات على الفحم، وعود حي بعد العاشرة. '
      + 'تعالى لأذان المغرب، واقعد لآخر طاولة.',
    cuisines: ['levantine', 'egyptian'],
    neighborhood: 'Zamalek',
    addressEn: '26th of July St, Zamalek',
    addressAr: 'شارع 26 يوليو، الزمالك',
    phone: '+20 2 2735 0000',
    lat: 30.0622,
    lng: 31.2185,
    priceBand: 3,
    rating: 4.8,
    ratingCount: 312,
    amenities: { outdoor: true, shisha: true, nile_view: true, valet: true },
    slotIntervalMin: 30,
    tables: [
      { name: 'T1', min: 1, max: 2, zone: 'indoor' },
      { name: 'T2', min: 2, max: 2, zone: 'indoor' },
      { name: 'T3', min: 2, max: 4, zone: 'outdoor' },
      { name: 'T4', min: 2, max: 4, zone: 'outdoor' },
      { name: 'T5', min: 4, max: 6, zone: 'outdoor' },
      { name: 'T6', min: 6, max: 10, zone: 'family' },
    ],
    shifts: [
      { nameEn: 'Dinner', nameAr: 'العشاء', days: ALL, opens: '18:00', closes: '23:30' },
    ],
  },
  {
    slug: 'sequoia-zamalek',
    nameEn: 'Sequoia',
    nameAr: 'سيكويا',
    descriptionEn:
      'The tip of the island, open to the water on three sides. Mediterranean plates, long tables, '
      + 'and a breeze that makes August bearable.',
    descriptionAr:
      'طرف الجزيرة، مفتوح على المية من ٣ نواحي. أطباق متوسطية، ترابيزات طويلة، ونسمة بتخلي أغسطس محتمل.',
    cuisines: ['mediterranean', 'lebanese'],
    neighborhood: 'Zamalek',
    addressEn: '3 Abu El Feda St, Zamalek',
    addressAr: '٣ شارع أبو الفدا، الزمالك',
    phone: '+20 2 2735 0014',
    lat: 30.0742,
    lng: 31.2249,
    priceBand: 3,
    rating: 4.6,
    ratingCount: 540,
    amenities: { outdoor: true, nile_view: true, shisha: true, family_section: true },
    slotIntervalMin: 30,
    tables: [
      { name: 'A1', min: 2, max: 4, zone: 'outdoor' },
      { name: 'A2', min: 2, max: 4, zone: 'outdoor' },
      { name: 'A3', min: 2, max: 4, zone: 'outdoor' },
      { name: 'B1', min: 4, max: 8, zone: 'outdoor' },
      { name: 'B2', min: 6, max: 12, zone: 'family' },
      { name: 'C1', min: 1, max: 2, zone: 'bar' },
      { name: 'C2', min: 1, max: 2, zone: 'bar' },
    ],
    // Lunch and dinner as SEPARATE shifts on the same day — the case a
    // findFirst-shaped availability lookup silently drops.
    shifts: [
      { nameEn: 'Lunch', nameAr: 'الغداء', days: ALL, opens: '12:00', closes: '16:30' },
      { nameEn: 'Dinner', nameAr: 'العشاء', days: ALL, opens: '18:30', closes: '23:30' },
    ],
  },
  {
    slug: 'zooba-downtown',
    nameEn: 'Zooba',
    nameAr: 'زوبا',
    descriptionEn:
      'Egyptian street food, done properly and served fast. Hawawshi, taameya, and a koshary that '
      + 'has ended arguments.',
    descriptionAr: 'أكل شارع مصري، بس مظبوط وسريع. حواوشي، طعمية، وكشري بينهي أي خلاف.',
    cuisines: ['egyptian', 'street_food'],
    neighborhood: 'Downtown',
    addressEn: '12 Talaat Harb St, Downtown',
    addressAr: '١٢ شارع طلعت حرب، وسط البلد',
    phone: '+20 2 2390 0080',
    lat: 30.0489,
    lng: 31.2397,
    priceBand: 2,
    rating: 4.7,
    ratingCount: 1203,
    amenities: { family_section: true, alcohol_free: true },
    slotIntervalMin: 15,
    tables: [
      { name: '1', min: 1, max: 2, zone: 'indoor' },
      { name: '2', min: 2, max: 4, zone: 'indoor' },
      { name: '3', min: 2, max: 4, zone: 'indoor' },
      { name: '4', min: 4, max: 6, zone: 'family' },
    ],
    // Closed Mondays (day 1). A venue that is dark on a weekday is the reason
    // the date strip needs an empty state and not just a spinner.
    shifts: [
      { nameEn: 'All day', nameAr: 'طول اليوم', days: [0, 2, 3, 4, 5, 6], opens: '11:00', closes: '23:00' },
    ],
  },
  {
    slug: 'kazoku-maadi',
    nameEn: 'Kazoku',
    nameAr: 'كازوكو',
    descriptionEn:
      'A ten-seat counter and one chef. Omakase only, one sitting a night, and the fish lands the '
      + 'morning it is served.',
    descriptionAr: 'كاونتر بعشر كراسي وشيف واحد. أوماكاسي بس، جلسة واحدة في الليلة، والسمك بييجي الصبح.',
    cuisines: ['japanese', 'sushi'],
    neighborhood: 'Maadi',
    addressEn: 'Road 9, Maadi',
    addressAr: 'شارع ٩، المعادي',
    phone: '+20 2 2358 0099',
    lat: 29.9603,
    lng: 31.2578,
    priceBand: 4,
    rating: 4.9,
    ratingCount: 210,
    amenities: { alcohol_free: true },
    slotIntervalMin: 30,
    // ONE two-top. Book it and the next diner gets `slot_taken` — which is the
    // whole point: that path has to be reachable by hand, not only in a test.
    tables: [{ name: 'Counter', min: 1, max: 2, zone: 'bar' }],
    shifts: [
      { nameEn: 'Omakase', nameAr: 'أوماكاسي', days: [2, 3, 4, 5, 6], opens: '19:00', closes: '22:00' },
    ],
  },
  {
    slug: 'el-fishawy-khan',
    nameEn: 'El Fishawy',
    nameAr: 'الفيشاوي',
    descriptionEn:
      'Two hundred years of mint tea in an alley off the Khan. Mirrors, brass, and no reason to '
      + 'hurry — the kitchen is still going at three in the morning.',
    descriptionAr:
      'مية تلتين سنة شاي بنعناع في حارة جنب الخان. مرايات ونحاس ومفيش داعي للاستعجال — المطبخ شغال لحد ٣ الفجر.',
    cuisines: ['egyptian', 'cafe'],
    neighborhood: 'Khan el-Khalili',
    addressEn: 'Khan el-Khalili, El Gamaleya',
    addressAr: 'خان الخليلي، الجمالية',
    phone: '+20 2 2590 6755',
    lat: 30.0477,
    lng: 31.2622,
    priceBand: 1,
    rating: 4.5,
    ratingCount: 2841,
    amenities: { outdoor: true, shisha: true, alcohol_free: true },
    slotIntervalMin: 30,
    tables: [
      { name: 'S1', min: 1, max: 2, zone: 'outdoor' },
      { name: 'S2', min: 2, max: 4, zone: 'outdoor' },
      { name: 'S3', min: 2, max: 4, zone: 'outdoor' },
      { name: 'S4', min: 4, max: 6, zone: 'outdoor' },
      { name: 'S5', min: 4, max: 8, zone: 'indoor' },
    ],
    // Runs past midnight — the sohour case, and the one that breaks any code
    // treating a shift as a plain start < end comparison.
    shifts: [
      { nameEn: 'Evening', nameAr: 'المسا', days: ALL, opens: '17:00', closes: '02:00', spansMidnight: true },
    ],
  },
];

const TURN_MINUTES = { '1-2': 90, '3-4': 105, '5+': 120 };

async function ensureOwner(): Promise<string> {
  const existing = await prisma.user.findFirst({ where: { phone: OWNER_PHONE } });
  const user =
    existing ??
    (await prisma.user.create({
      data: {
        phone: OWNER_PHONE,
        fullName: 'SAHRA Demo Owner',
        locale: 'ar',
        status: 'active',
      },
    }));

  const owner = await prisma.restaurantOwner.findFirst({ where: { userId: user.id } });
  if (owner) return owner.id;

  const created = await prisma.restaurantOwner.create({
    data: { userId: user.id, businessName: OWNER_BUSINESS, verificationStatus: 'verified' },
  });
  return created.id;
}

async function upsertVenue(ownerId: string, v: SeedVenue): Promise<string> {
  // `location` is PostGIS, which Prisma cannot type, so this is raw. Note the
  // argument order: ST_MakePoint is (lng, lat), and swapping them puts every
  // one of these venues in the Indian Ocean without any type complaining.
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, description_en, description_ar,
      cuisines, phone, address_en, address_ar, city, neighborhood, location,
      price_band, amenities, policies, booking_mode, slot_interval_min,
      rating_avg, rating_count, status, timezone, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${v.slug}, ${v.nameEn}, ${v.nameAr},
      ${v.descriptionEn}, ${v.descriptionAr},
      ${v.cuisines}, ${v.phone}, ${v.addressEn}, ${v.addressAr},
      'Cairo', ${v.neighborhood},
      ST_SetSRID(ST_MakePoint(${v.lng}, ${v.lat}), 4326)::geography,
      ${v.priceBand}, ${JSON.stringify(v.amenities)}::jsonb,
      '{"cancellation_hours":2,"deposit":false}'::jsonb,
      'instant', ${v.slotIntervalMin},
      ${v.rating}, ${v.ratingCount}, 'active', 'Africa/Cairo', now(), now()
    )
    ON CONFLICT (slug) DO UPDATE SET
      name_en = EXCLUDED.name_en, name_ar = EXCLUDED.name_ar,
      description_en = EXCLUDED.description_en, description_ar = EXCLUDED.description_ar,
      cuisines = EXCLUDED.cuisines, phone = EXCLUDED.phone,
      address_en = EXCLUDED.address_en, address_ar = EXCLUDED.address_ar,
      neighborhood = EXCLUDED.neighborhood, location = EXCLUDED.location,
      price_band = EXCLUDED.price_band, amenities = EXCLUDED.amenities,
      slot_interval_min = EXCLUDED.slot_interval_min,
      rating_avg = EXCLUDED.rating_avg, rating_count = EXCLUDED.rating_count,
      status = 'active', deleted_at = NULL, updated_at = now()
    RETURNING id`;
  return rows[0].id;
}

async function syncTables(restaurantId: string, tables: SeedTable[]): Promise<void> {
  for (const t of tables) {
    await prisma.table.upsert({
      where: { restaurantId_name: { restaurantId, name: t.name } },
      create: {
        restaurantId,
        name: t.name,
        minCapacity: t.min,
        maxCapacity: t.max,
        zone: t.zone,
        active: true,
      },
      update: { minCapacity: t.min, maxCapacity: t.max, zone: t.zone, active: true },
    });
  }
}

async function syncShifts(restaurantId: string, shifts: SeedShift[]): Promise<void> {
  // Shifts have no natural key, so they are replaced rather than upserted.
  // Safe: a shift carries no history — a reservation records its own times.
  await prisma.$executeRaw`DELETE FROM shifts WHERE restaurant_id = ${restaurantId}::uuid`;
  for (const s of shifts) {
    for (const day of s.days) {
      await prisma.$executeRaw`
        INSERT INTO shifts (restaurant_id, name_en, name_ar, day_of_week,
                            opens_at, closes_at, spans_midnight,
                            default_turn_minutes, is_ramadan, active,
                            created_at, updated_at)
        VALUES (${restaurantId}::uuid, ${s.nameEn}, ${s.nameAr}, ${day},
                ${s.opens}::time, ${s.closes}::time, ${s.spansMidnight ?? false},
                ${JSON.stringify(TURN_MINUTES)}::jsonb, false, true, now(), now())`;
    }
  }
}

async function reindex(ids: string[]): Promise<void> {
  const host = process.env.MEILISEARCH_HOST;
  if (!host) {
    console.warn(
      '\n! MEILISEARCH_HOST is not set. Venues are in Postgres but NOT searchable.\n'
      + '  /restaurants/search will answer 503 (which is the correct outage behaviour).\n'
      + '  Start it with `docker compose up -d meilisearch`, then re-run this seed.\n',
    );
    return;
  }
  const index = new MeiliSearchIndex(
    host,
    process.env.MEILISEARCH_API_KEY || process.env.MEILISEARCH_MASTER_KEY || undefined,
    process.env.MEILISEARCH_INDEX ?? DEFAULT_INDEX_UID,
  );
  await index.ensureIndex();
  const rows = await loadLiveRows(prisma as unknown as PrismaService, ids);
  await index.upsert([...rows.values()].map(toSearchDoc));
  await index.waitForIdle();
  console.log(`Indexed ${rows.size} venue(s) for search.`);
}

async function main(): Promise<void> {
  const reset = process.argv.includes('--reset');
  await prisma.$connect();

  const ownerId = await ensureOwner();
  const ids: string[] = [];
  const bySlug: { slug: string; id: string }[] = [];

  for (const v of VENUES) {
    const id = await upsertVenue(ownerId, v);
    ids.push(id);
    bySlug.push({ slug: v.slug, id });

    if (reset) {
      await prisma.$executeRaw`
        DELETE FROM reservations WHERE restaurant_id = ${id}::uuid`;
    }
    await syncTables(id, v.tables);
    await syncShifts(id, v.shifts);
    console.log(`  ${v.nameEn.padEnd(14)} ${v.tables.length} tables, ${v.shifts.length} shift(s)  ${id}`);
  }

  // AFTER the venue upsert, because the review trigger recomputes rating_avg
  // and rating_count from real rows — and `upsertVenue` writes the hand-picked
  // numbers from VENUES. Run the other way round and the seeded 4.8/312 would
  // win, which is the demo data that hides a bug in the count.
  const md = await syncMenusAndReviews(prisma, bySlug);
  console.log(`  ${md.menus} menu(s), ${md.reviews} review(s) — ratings recomputed by trigger`);

  // AFTER the reviews too: the search document carries rating and rating_count,
  // so indexing first would publish the pre-trigger numbers to Meilisearch and
  // leave the list disagreeing with the venue page it links to.
  await reindex(ids);

  console.log(`\n${VENUES.length} venues ready.${reset ? ' Reservations cleared.' : ''}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
