/**
 * Group D seed data — menus (R-2.3) and reviews (C-4.4).
 *
 * A separate file because `seed.ts` was already at the length where adding a
 * second subject makes both harder to read, not because this runs separately.
 * `seed.ts` calls it.
 *
 * ── CHOSEN TO MAKE THE SCREENS DIFFER ────────────────────────────────────
 *
 * Same principle the venue list already follows. Every venue having a tidy
 * four-item menu would mean the only state anyone ever looks at is the happy
 * one, and the empty states — which are the ones that ship broken — would
 * never be on screen:
 *
 *   Layali Lounge  two menus (food + drinks), so the selector has something
 *                  to select
 *   Sequoia        one long menu, four categories — the scrolling case
 *   Zooba          short, and the only one with dietary tags on most items
 *   El Fishawy     three items, one category — the barely-there case
 *   Kazoku         NO MENU AT ALL. Deliberate: the empty state is a screen we
 *                  ship and it needs somewhere to be seen.
 *
 * No `pdf_key` anywhere. The R-2.3 PDF fallback is real and the column is
 * there, but seeding a key with no object behind it would put a button in the
 * app that opens a 404 — "a control that opens nothing is worse than an absent
 * one". It is covered in `menus.e2e-spec.ts` instead, where the storage port
 * is a fake and the URL is meant to be synthetic.
 *
 * ── AND THE REVIEWS ARE REAL ROWS ────────────────────────────────────────
 *
 * Not `UPDATE restaurants SET rating_avg = 4.8`. Each one is a past
 * reservation, marked `completed`, belonging to a seeded diner, with a review
 * hanging off it — which is the only way a review can exist at all
 * (`reservation_id` is NOT NULL). The trigger then computes `rating_avg` and
 * `rating_count` from them.
 *
 * That means THE SEEDED RATINGS IN `seed.ts` GET OVERWRITTEN, on purpose. A
 * venue that claims 312 reviews and can show four is the kind of demo data
 * that hides a bug in the count. After this runs, the number on the card is
 * the number of reviews you can scroll.
 */
import { PrismaClient, ReviewStatus } from '@prisma/client';

interface SeedItem {
  nameEn: string;
  nameAr: string;
  price: string;
  tags?: string[];
}

interface SeedCategory {
  nameEn: string;
  nameAr: string;
  items: SeedItem[];
}

interface SeedMenu {
  nameEn: string;
  nameAr: string;
  kind: 'food' | 'drinks' | 'ramadan' | 'set';
  categories: SeedCategory[];
}

/**
 * Layali Lounge's food menu is `VenueDetailScreen.jsx` lines 13–14, verbatim —
 * the same four dishes at the same four prices in both languages. The reference
 * is where the copy comes from, per DESIGN-RULES §6; inventing different dishes
 * would mean the screen we build cannot be compared to the screen we were
 * given.
 */
const MENUS: Record<string, SeedMenu[]> = {
  'layali-lounge-zamalek': [
    {
      nameEn: 'Kitchen',
      nameAr: 'المطبخ',
      kind: 'food',
      categories: [
        {
          nameEn: 'Mezze',
          nameAr: 'مقبّلات',
          items: [
            {
              nameEn: 'Charred halloumi & date honey',
              nameAr: 'حلومي مشوي بعسل البلح',
              price: '320.00',
              tags: ['vegetarian'],
            },
            { nameEn: 'Muhammara, walnut', nameAr: 'محمرة بالجوز', price: '180.00', tags: ['vegan'] },
          ],
        },
        {
          nameEn: 'Charcoal',
          nameAr: 'فحم',
          items: [
            { nameEn: 'Mixed grill for two', nameAr: 'مشوي مشكل لفردين', price: '980.00' },
            { nameEn: 'Grilled sea bass', nameAr: 'قاروص مشوي', price: '620.00' },
          ],
        },
        {
          nameEn: 'Signature',
          nameAr: 'أطباق مميزة',
          items: [
            { nameEn: 'Freekeh-stuffed pigeon', nameAr: 'حمام محشي فريك', price: '540.00' },
          ],
        },
        {
          nameEn: 'Dessert',
          nameAr: 'حلو',
          items: [
            {
              nameEn: 'Umm Ali, pistachio crust',
              nameAr: 'أم علي بالفستق',
              price: '210.00',
              tags: ['vegetarian', 'nut_free'],
            },
          ],
        },
      ],
    },
    {
      nameEn: 'Bar',
      nameAr: 'البار',
      kind: 'drinks',
      categories: [
        {
          nameEn: 'Fresh',
          nameAr: 'طازة',
          items: [
            { nameEn: 'Mint lemonade', nameAr: 'ليمون بالنعناع', price: '85.00', tags: ['vegan'] },
            { nameEn: 'Hibiscus, cold', nameAr: 'كركديه بارد', price: '70.00', tags: ['vegan'] },
          ],
        },
        {
          nameEn: 'Evening',
          nameAr: 'السهرة',
          items: [
            {
              nameEn: 'Nile Sour',
              nameAr: 'نايل ساور',
              price: '240.00',
              tags: ['contains_alcohol'],
            },
          ],
        },
      ],
    },
  ],

  'sequoia-zamalek': [
    {
      nameEn: 'All day',
      nameAr: 'طول اليوم',
      kind: 'food',
      categories: [
        {
          nameEn: 'To start',
          nameAr: 'للبداية',
          items: [
            { nameEn: 'Hummus, lamb', nameAr: 'حمص باللحمة', price: '260.00' },
            { nameEn: 'Vine leaves', nameAr: 'ورق عنب', price: '190.00', tags: ['vegan'] },
            { nameEn: 'Fried calamari', nameAr: 'كاليماري مقلي', price: '340.00', tags: ['shellfish'] },
          ],
        },
        {
          nameEn: 'From the grill',
          nameAr: 'من الشواية',
          items: [
            { nameEn: 'Lamb chops', nameAr: 'ريش ضاني', price: '790.00' },
            { nameEn: 'Shish tawook', nameAr: 'شيش طاووق', price: '420.00' },
          ],
        },
        {
          nameEn: 'Sea',
          nameAr: 'بحري',
          items: [
            { nameEn: 'Prawns, garlic', nameAr: 'جمبري بالتوم', price: '680.00', tags: ['shellfish'] },
          ],
        },
        {
          nameEn: 'Sweet',
          nameAr: 'حلويات',
          items: [
            { nameEn: 'Basbousa', nameAr: 'بسبوسة', price: '150.00', tags: ['vegetarian'] },
          ],
        },
      ],
    },
  ],

  'zooba-downtown': [
    {
      nameEn: 'Street food',
      nameAr: 'أكل الشارع',
      kind: 'food',
      categories: [
        {
          nameEn: 'Sandwiches',
          nameAr: 'سندوتشات',
          items: [
            { nameEn: 'Taameya, herb', nameAr: 'طعمية بالخضرة', price: '55.00', tags: ['vegan'] },
            { nameEn: 'Hawawshi', nameAr: 'حواوشي', price: '95.00', tags: ['spicy'] },
            {
              nameEn: 'Feteer, cheese',
              nameAr: 'فطير بالجبنة',
              price: '120.00',
              tags: ['vegetarian'],
            },
          ],
        },
        {
          nameEn: 'Bowls',
          nameAr: 'أطباق',
          items: [
            { nameEn: 'Koshary', nameAr: 'كشري', price: '85.00', tags: ['vegan', 'nut_free'] },
          ],
        },
      ],
    },
  ],

  'el-fishawy-khan': [
    {
      nameEn: 'The café',
      nameAr: 'القهوة',
      kind: 'food',
      categories: [
        {
          nameEn: 'All of it',
          nameAr: 'كل حاجة',
          items: [
            { nameEn: 'Mint tea', nameAr: 'شاي بالنعناع', price: '40.00', tags: ['vegan'] },
            { nameEn: 'Turkish coffee', nameAr: 'قهوة تركي', price: '45.00', tags: ['vegan'] },
            { nameEn: 'Rice pudding', nameAr: 'أرز باللبن', price: '65.00', tags: ['vegetarian'] },
          ],
        },
      ],
    },
  ],

  // 'kazoku-maadi' — nothing. See the header.
};

/** One review, written as the diner and the words rather than as a rating. */
interface SeedReview {
  /** Index into DINERS. */
  diner: number;
  rating: number;
  food?: number;
  service?: number;
  ambience?: number;
  body?: string;
  /** How many days ago the visit was. Ordering on the screen comes from this. */
  daysAgo: number;
  reply?: string;
}

const DINERS = [
  { phone: '+201000000101', name: 'Nour Hassan' },
  { phone: '+201000000102', name: 'Omar Abdelrahman' },
  { phone: '+201000000103', name: 'Laila Fahmy' },
  { phone: '+201000000104', name: 'Kareem' },
];

/**
 * Deliberately not five stars all the way down. A review list where every
 * entry agrees is a list nobody reads, and — more to the point here — it never
 * exercises the histogram, the shorter cards, or a body long enough to wrap.
 * One is stars-only, which is the nullable-body case.
 */
const REVIEWS: Record<string, SeedReview[]> = {
  'layali-lounge-zamalek': [
    {
      diner: 0,
      rating: 5,
      food: 5,
      service: 5,
      ambience: 5,
      daysAgo: 4,
      body: 'We sat on the terrace until the oud player finished. The mixed grill is enough for three, whatever the menu says.',
      reply: 'Thank you Nour — the oud is every night after ten. See you soon.',
    },
    { diner: 1, rating: 4, food: 5, service: 3, daysAgo: 11, body: 'Food was excellent. Service slowed once it filled up.' },
    { diner: 2, rating: 5, daysAgo: 19 },
    {
      diner: 3,
      rating: 3,
      food: 3,
      service: 4,
      ambience: 5,
      daysAgo: 33,
      body: 'Beautiful room, and the view is the reason to come. The pigeon was dry.',
    },
  ],
  'sequoia-zamalek': [
    { diner: 1, rating: 5, food: 5, ambience: 5, daysAgo: 6, body: 'Best table on the Nile at sunset. Book the far corner.' },
    { diner: 2, rating: 4, daysAgo: 14 },
    { diner: 0, rating: 4, food: 4, service: 4, daysAgo: 27, body: 'Reliable. Busy on a Thursday, so go early.' },
  ],
  'zooba-downtown': [
    { diner: 3, rating: 5, daysAgo: 2, body: 'The best taameya sandwich in Cairo and it is not close.' },
    { diner: 0, rating: 4, food: 5, service: 3, daysAgo: 9 },
  ],
  'el-fishawy-khan': [
    {
      diner: 2,
      rating: 4,
      ambience: 5,
      daysAgo: 8,
      body: 'You are not here for the tea. Two hundred years of people watching, and it shows.',
    },
  ],
};

/** Seeded reservations are marked in their code so re-running can find them. */
const SEED_CODE_PREFIX = 'SD-';

async function ensureDiners(prisma: PrismaClient): Promise<string[]> {
  const ids: string[] = [];
  for (const d of DINERS) {
    const existing = await prisma.user.findFirst({ where: { phone: d.phone } });
    if (existing) {
      ids.push(existing.id);
      continue;
    }
    const created = await prisma.user.create({
      data: {
        phone: d.phone,
        fullName: d.name,
        locale: 'ar',
        status: 'active',
        phoneVerifiedAt: new Date(),
      },
    });
    ids.push(created.id);
  }
  return ids;
}

export async function syncMenusAndReviews(
  prisma: PrismaClient,
  venues: { slug: string; id: string }[],
): Promise<{ menus: number; reviews: number }> {
  const dinerIds = await ensureDiners(prisma);
  let menuCount = 0;
  let reviewCount = 0;

  for (const venue of venues) {
    // ── menus ────────────────────────────────────────────────────────────
    // Delete and rebuild rather than upsert. There is no natural key on a
    // menu row, and matching on `name_en` would silently orphan an item whose
    // dish got renamed. CASCADE takes the categories and items with it.
    await prisma.$executeRaw`DELETE FROM menus WHERE restaurant_id = ${venue.id}::uuid`;

    const menus = MENUS[venue.slug] ?? [];
    for (const [mi, m] of menus.entries()) {
      const menu = await prisma.menu.create({
        data: {
          restaurantId: venue.id,
          nameEn: m.nameEn,
          nameAr: m.nameAr,
          kind: m.kind,
          position: mi,
        },
      });
      menuCount++;

      for (const [ci, c] of m.categories.entries()) {
        const category = await prisma.menuCategory.create({
          data: { menuId: menu.id, nameEn: c.nameEn, nameAr: c.nameAr, position: ci },
        });
        for (const [ii, item] of c.items.entries()) {
          await prisma.menuItem.create({
            data: {
              categoryId: category.id,
              nameEn: item.nameEn,
              nameAr: item.nameAr,
              price: item.price,
              currency: 'EGP',
              dietaryTags: item.tags ?? [],
              position: ii,
            },
          });
        }
      }
    }

    // ── reviews ──────────────────────────────────────────────────────────
    // Reviews first, then their reservations: `reviews.reservation_id` is
    // ON DELETE RESTRICT, which is the point of it.
    await prisma.$executeRaw`
      DELETE FROM reviews
       WHERE reservation_id IN (
         SELECT id FROM reservations
          WHERE restaurant_id = ${venue.id}::uuid
            AND code LIKE ${SEED_CODE_PREFIX + '%'}
       )`;
    await prisma.$executeRaw`
      DELETE FROM reservations
       WHERE restaurant_id = ${venue.id}::uuid AND code LIKE ${SEED_CODE_PREFIX + '%'}`;

    const reviews = REVIEWS[venue.slug] ?? [];
    for (const [ri, r] of reviews.entries()) {
      const startsAt = new Date(Date.now() - r.daysAgo * 86_400_000);
      startsAt.setUTCHours(18, 0, 0, 0);
      const endsAt = new Date(startsAt.getTime() + 90 * 60_000);

      // A short, stable code so a re-run finds and replaces the same rows.
      // VARCHAR(8): 'SD-' + 2 slug chars + 3 digits.
      const code = `${SEED_CODE_PREFIX}${venue.slug.slice(0, 2).toUpperCase()}${String(ri).padStart(3, '0')}`;

      const reservation = await prisma.reservation.create({
        data: {
          code,
          restaurantId: venue.id,
          userId: dinerIds[r.diner],
          partySize: 2,
          startsAt,
          endsAt,
          // The eligibility rule this seed has to satisfy is the real one:
          // `ReviewsService.assertEligible` wants a seated-or-completed
          // reservation whose table time is over. A seed that wrote reviews
          // straight into the table would not have proved that path exists.
          status: 'completed',
          source: 'app',
        },
      });

      await prisma.review.create({
        data: {
          reservationId: reservation.id,
          userId: dinerIds[r.diner],
          restaurantId: venue.id,
          rating: r.rating,
          foodRating: r.food ?? null,
          serviceRating: r.service ?? null,
          ambienceRating: r.ambience ?? null,
          body: r.body ?? null,
          status: ReviewStatus.published,
          ownerReply: r.reply ?? null,
          ownerRepliedAt: r.reply ? new Date(startsAt.getTime() + 86_400_000) : null,
          createdAt: new Date(endsAt.getTime() + 3 * 3_600_000),
        },
      });
      reviewCount++;
    }

    // EVERY venue, including the ones with no reviews.
    //
    // The trigger only fires for venues that got a review, so Kazoku kept the
    // hand-picked "4.9 from 210 reviews" out of `seed.ts` while having none to
    // show — which is exactly the demo data this file's header complains
    // about, and it survived the first run of it. Calling the trigger's own
    // function directly settles all five to what the rows actually say, and
    // gives us one venue with no rating at all, which is a state the venue
    // card has to draw and nobody had seen.
    await prisma.$executeRaw`SELECT sahra_apply_restaurant_rating(${venue.id}::uuid)`;
  }

  return { menus: menuCount, reviews: reviewCount };
}
