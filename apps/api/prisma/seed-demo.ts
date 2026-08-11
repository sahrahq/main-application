/**
 * DEMO CONTENT — so a handset shows the product rather than the empty state.
 *
 * Runs AFTER `pnpm seed`, which creates the five venues, their tables and
 * their shifts. This adds the things that make a card look like a restaurant:
 * photos, menus, reviews.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * PHOTOS GO THROUGH THE REAL UPLOAD ENDPOINT
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `POST /v1/admin/restaurants/:id/images`, multipart, with an admin token —
 * not `prisma.image.create`. Writing rows directly would produce a database
 * that looks seeded and an app that shows broken images, because the renditions
 * the client asks for would never have been generated. The upload path is the
 * thing being exercised: sharp resize, the size variants, the cover rule.
 *
 * It therefore NEEDS THE API RUNNING. That is deliberate — a seed that can
 * pretend to work without it would be the same defect one level up.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHERE THE PHOTOGRAPHY COMES FROM
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Unsplash, via `images.unsplash.com`, under the Unsplash Licence
 * (https://unsplash.com/license): free to use commercially, no permission
 * needed, no attribution required. Each URL is PINNED to a specific photo id
 * rather than a random-photo endpoint, so two runs produce the same venue
 * looking the same — a seed that shuffles its own images makes every golden
 * and every screenshot unreproducible.
 *
 * NOTHING BINARY IS COMMITTED. They are fetched at run time and posted
 * straight through; the repository gains no megabytes and no licence
 * questions.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHAT IS DELIBERATELY UGLY
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   · `el-fishawy-khan` is left COMPLETELY BARE — no photos, no menu, no
 *     reviews. The empty states are met on purpose rather than discovered by
 *     accident on the one venue that happened to fail.
 *   · One venue is Arabic-heavy in name, neighbourhood, menu and reviews.
 *     Arabic at real length is the thing most likely to break a layout, and a
 *     seed full of English names hides it.
 *   · One venue name and one menu item are DELIBERATELY LONG, so the layout
 *     meets that here rather than when a real restaurant does it.
 */
import { PrismaClient } from '@prisma/client';
import { JwtService } from '@nestjs/jwt';

const prisma = new PrismaClient();
const API = process.env.SEED_API_BASE ?? 'http://127.0.0.1:3000';
const ADMIN_PHONE = '+201000000009';

/** Unsplash Licence — commercial use, no attribution required. Pinned ids. */
const PHOTOS: Record<string, { cover: string; gallery: string[] }> = {
  'layali-lounge-zamalek': {
    cover: 'photo-1414235077428-338989a2e8c0',
    gallery: ['photo-1517248135467-4c7edcad34c4', 'photo-1552566626-52f8b828add9'],
  },
  'sequoia-zamalek': {
    cover: 'photo-1555396273-367ea4eb4db5',
    gallery: ['photo-1466978913421-dad2ebd01d17', 'photo-1424847651672-bf20a4b0982b'],
  },
  'zooba-downtown': {
    cover: 'photo-1555939594-58d7cb561ad1',
    gallery: ['photo-1540189549336-e6e99c3679fe', 'photo-1476224203421-9ac39bcb3327'],
  },
  'kazoku-maadi': {
    cover: 'photo-1579871494447-9811cf80d66c',
    gallery: ['photo-1553621042-f6e147245754', 'photo-1611143669185-af224c5e3252'],
  },
  // el-fishawy-khan: NONE, on purpose. See the header.
};

const url = (id: string) => `https://images.unsplash.com/${id}?w=1600&q=80&fm=jpg`;

/** A minted admin token. The upload endpoint is `@Roles('admin')`. */
async function adminToken(): Promise<string> {
  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) throw new Error('JWT_ACCESS_SECRET is not set — the API cannot boot without it either.');

  const user =
    (await prisma.user.findFirst({ where: { phone: ADMIN_PHONE } })) ??
    (await prisma.user.create({
      data: { phone: ADMIN_PHONE, fullName: 'SAHRA Demo Admin', locale: 'en', status: 'active' },
    }));

  const role =
    (await prisma.role.findFirst({ where: { name: 'admin' } })) ??
    (await prisma.role.create({ data: { name: 'admin' } }));
  const has = await prisma.userRole.findFirst({ where: { userId: user.id, roleId: role.id } });
  if (!has) await prisma.userRole.create({ data: { userId: user.id, roleId: role.id } });

  // The same claim shape `JwtStrategy` validates: { sub, roles, locale }.
  return new JwtService({}).signAsync(
    { sub: user.id, roles: ['admin'], locale: 'en' },
    { secret, expiresIn: '30m' },
  );
}

async function uploadPhotos(token: string): Promise<void> {
  for (const [slug, set] of Object.entries(PHOTOS)) {
    const venue = await prisma.restaurant.findFirst({ where: { slug }, select: { id: true } });
    if (!venue) {
      console.log(`  ${slug}: not found — run \`pnpm seed\` first`);
      continue;
    }
    // IDEMPOTENT: a venue that already has photos is left alone, so running
    // this twice does not give a restaurant six covers.
    const existing = await prisma.image.count({ where: { ownerType: 'restaurant', ownerId: venue.id } });
    if (existing > 0) {
      console.log(`  ${slug}: ${existing} image(s) already — skipped`);
      continue;
    }

    const wanted = [{ id: set.cover, cover: true }, ...set.gallery.map((id) => ({ id, cover: false }))];
    for (const w of wanted) {
      const res = await fetch(url(w.id));
      if (!res.ok) {
        console.log(`  ${slug}: download failed ${res.status} for ${w.id}`);
        continue;
      }
      const bytes = Buffer.from(await res.arrayBuffer());
      const form = new FormData();
      form.append('file', new Blob([bytes], { type: 'image/jpeg' }), `${w.id}.jpg`);

      const up = await fetch(
        `${API}/v1/admin/restaurants/${venue.id}/images${w.cover ? '?cover=true' : ''}`,
        { method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: form },
      );
      if (!up.ok) {
        throw new Error(
          `upload failed ${up.status} for ${slug}: ${(await up.text()).slice(0, 200)}\n` +
            `Is the API running at ${API}?  (cd apps/api && pnpm start:dev)`,
        );
      }
    }
    console.log(`  ${slug}: ${wanted.length} image(s) uploaded through the real path`);
  }
}

type Item = { en: string; ar: string; price: number; tags?: string[]; descEn?: string; descAr?: string };
type Cat = { en: string; ar: string; items: Item[] };

const MENUS: Record<string, Cat[]> = {
  'layali-lounge-zamalek': [
    {
      en: 'Mezze', ar: 'مقبلات',
      items: [
        { en: 'Hummus with lamb', ar: 'حمص باللحمة', price: 145, tags: ['contains_nuts'] },
        { en: 'Muhammara', ar: 'محمرة', price: 120, tags: ['vegan', 'contains_nuts'] },
        { en: 'Warak enab', ar: 'ورق عنب', price: 135, tags: ['vegetarian'] },
      ],
    },
    {
      en: 'Grill', ar: 'مشويات',
      items: [
        { en: 'Mixed grill for two', ar: 'مشاوي مشكلة لاتنين', price: 640 },
        {
          // DELIBERATELY LONG — see the header.
          en: 'Slow-roasted lamb shoulder with freekeh, caramelised onion and toasted almonds',
          ar: 'كتف ضاني مشوي على نار هادية مع الفريك والبصل المكرمل واللوز المحمص',
          price: 780,
          tags: ['contains_nuts'],
          descEn: 'Serves two to three. Ordered at the table, forty minutes.',
          descAr: 'يكفي اتنين لتلاتة. بيتطلب على الترابيزة، أربعين دقيقة.',
        },
      ],
    },
  ],
  'sequoia-zamalek': [
    {
      en: 'Starters', ar: 'مقبلات',
      items: [
        { en: 'Burrata & tomato', ar: 'بوراتا وطماطم', price: 260, tags: ['vegetarian'] },
        { en: 'Calamari', ar: 'كاليماري', price: 295 },
      ],
    },
    {
      en: 'Mains', ar: 'أطباق رئيسية',
      items: [
        { en: 'Grilled sea bass', ar: 'قاروص مشوي', price: 520, tags: ['gluten_free'] },
        { en: 'Truffle risotto', ar: 'ريزوتو بالكمأة', price: 430, tags: ['vegetarian'] },
      ],
    },
  ],
  'zooba-downtown': [
    {
      en: 'Taameya & more', ar: 'طعمية وأكتر',
      items: [
        { en: 'Taameya sandwich', ar: 'ساندويتش طعمية', price: 55, tags: ['vegan'] },
        { en: 'Hawawshi', ar: 'حواوشي', price: 95 },
        { en: 'Koshary', ar: 'كشري', price: 75, tags: ['vegan'] },
      ],
    },
  ],
  'kazoku-maadi': [
    {
      en: 'Nigiri', ar: 'نيجيري',
      items: [
        { en: 'Salmon nigiri', ar: 'نيجيري سلمون', price: 180, tags: ['gluten_free'] },
        { en: 'Otoro nigiri', ar: 'نيجيري أوتورو', price: 340, tags: ['gluten_free'] },
      ],
    },
    {
      en: 'Rolls', ar: 'رولز',
      items: [
        { en: 'Spicy tuna roll', ar: 'رول تونة حار', price: 265 },
        { en: 'Vegetable roll', ar: 'رول خضار', price: 190, tags: ['vegan'] },
      ],
    },
  ],
};

async function seedMenus(): Promise<void> {
  for (const [slug, cats] of Object.entries(MENUS)) {
    const venue = await prisma.restaurant.findFirst({ where: { slug }, select: { id: true } });
    if (!venue) continue;
    const already = await prisma.menu.count({ where: { restaurantId: venue.id } });
    if (already > 0) {
      console.log(`  ${slug}: menu exists — skipped`);
      continue;
    }
    const menu = await prisma.menu.create({
      data: { restaurantId: venue.id, nameEn: 'Main menu', nameAr: 'المنيو', kind: 'food', position: 0 },
    });
    let cp = 0;
    for (const c of cats) {
      const cat = await prisma.menuCategory.create({
        data: { menuId: menu.id, nameEn: c.en, nameAr: c.ar, position: cp++ },
      });
      let ip = 0;
      for (const it of c.items) {
        await prisma.menuItem.create({
          data: {
            categoryId: cat.id,
            nameEn: it.en,
            nameAr: it.ar,
            descriptionEn: it.descEn ?? null,
            descriptionAr: it.descAr ?? null,
            price: it.price,
            currency: 'EGP',
            dietaryTags: it.tags ?? [],
            position: ip++,
          },
        });
      }
    }
    console.log(`  ${slug}: ${cats.length} categories, ${cats.reduce((n, c) => n + c.items.length, 0)} items`);
  }
}

/**
 * REVIEWS NEED RESERVATIONS. `Review.reservationId` is unique and required —
 * the schema will not let a review exist without a visit, which is the
 * eligibility rule expressed as a constraint rather than a check. So this
 * creates COMPLETED reservations in the past and reviews them.
 */
const REVIEWS: Record<string, { rating: number; en?: string; ar?: string; name: string; locale: string }[]> = {
  'layali-lounge-zamalek': [
    { rating: 5, ar: 'أحلى سهرة! الأكل ممتاز والخدمة سريعة والمكان هادي. هنكرر أكيد.', name: 'نور حسن', locale: 'ar' },
    { rating: 4, ar: 'الأكل كويس جداً بس الانتظار على الترابيزة كان طويل شوية.', name: 'أحمد فؤاد', locale: 'ar' },
    { rating: 5, en: 'Best mezze in Zamalek. The lamb shoulder is worth the forty minutes.', name: 'Sara Adel', locale: 'en' },
    { rating: 3, ar: 'المكان جميل بس الأسعار غالية شوية بالنسبة للكمية.', name: 'مريم سيد', locale: 'ar' },
    { rating: 2, en: 'Booked for 8, seated at 8:40. Food was fine once it arrived.', name: 'Omar Tarek', locale: 'en' },
  ],
  'sequoia-zamalek': [
    { rating: 5, en: 'The Nile view at sunset is the whole point. Book the terrace.', name: 'Laila Mostafa', locale: 'en' },
    { rating: 4, en: 'Lovely evening, service a little slow when it filled up.', name: 'Karim Zaki', locale: 'en' },
    { rating: 3, ar: 'المكان حلو بس الصوت عالي شوية.', name: 'هدى إبراهيم', locale: 'ar' },
  ],
  'zooba-downtown': [
    { rating: 5, ar: 'أحسن كشري في وسط البلد، بجد.', name: 'يوسف علي', locale: 'ar' },
    { rating: 4, en: 'Fast, cheap, exactly what it says it is.', name: 'Dina Farouk', locale: 'en' },
  ],
  'kazoku-maadi': [
    { rating: 5, en: 'The otoro is genuinely excellent. Small room, book ahead.', name: 'Youssef Nabil', locale: 'en' },
    { rating: 4, ar: 'السوشي طازة والخدمة محترمة. المكان صغير فاحجز بدري.', name: 'سلمى رشاد', locale: 'ar' },
    { rating: 2, en: 'Overpriced for the portion size on a weeknight.', name: 'Hana Wael', locale: 'en' },
  ],
};

async function seedReviews(): Promise<void> {
  for (const [slug, list] of Object.entries(REVIEWS)) {
    const venue = await prisma.restaurant.findFirst({ where: { slug }, select: { id: true } });
    if (!venue) continue;
    const already = await prisma.review.count({ where: { restaurantId: venue.id } });
    if (already > 0) {
      console.log(`  ${slug}: ${already} review(s) already — skipped`);
      continue;
    }
    const table = await prisma.table.findFirst({ where: { restaurantId: venue.id }, select: { id: true } });
    if (!table) continue;

    let n = 0;
    for (const r of list) {
      const phone = `+2011000${String(1000 + Math.abs(hash(slug + r.name)) % 9000)}`;
      const user =
        (await prisma.user.findFirst({ where: { phone } })) ??
        (await prisma.user.create({
          data: { phone, fullName: r.name, locale: r.locale, status: 'active' },
        }));

      // A visit in the past, completed. `starts_at` is spread so the review
      // list is not five identical timestamps.
      const when = new Date(Date.now() - (7 + n * 3) * 86_400_000);
      when.setUTCHours(18, 0, 0, 0);
      const ends = new Date(when.getTime() + 90 * 60_000);

      const resv = await prisma.reservation.create({
        data: {
          restaurantId: venue.id,
          userId: user.id,
          startsAt: when,
          endsAt: ends,
          partySize: 2,
          status: 'completed',
          source: 'app',
          // VarChar(8), so `SAH-` plus four. The demo codes are derived from
          // the slug and index rather than random, so a re-run collides
          // loudly on the unique index instead of silently adding duplicates.
          code: `SAH-${slug.slice(0, 2).toUpperCase()}${String(n).padStart(2, '0')}`,
        },
      });

      await prisma.review.create({
        data: {
          reservationId: resv.id,
          userId: user.id,
          restaurantId: venue.id,
          rating: r.rating,
          foodRating: r.rating,
          serviceRating: Math.max(1, r.rating - (n % 2)),
          ambienceRating: Math.min(5, r.rating + (n % 2)),
          body: r.ar ?? r.en ?? null,
          status: 'published',
        },
      });
      n++;
    }
    const avg = (list.reduce((s, r) => s + r.rating, 0) / list.length).toFixed(2);
    console.log(`  ${slug}: ${n} reviews, average ${avg}`);
  }
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return h;
}

/**
 * THE LONG NAME, applied to a venue that already exists.
 *
 * A real restaurant will eventually be called something like this, and the
 * card, the hero and the booking bar should all meet it here rather than then.
 */
async function makeOneNameLong(): Promise<void> {
  const long = {
    en: 'El Fishawy Coffeehouse & Oriental Sweets, Khan El Khalili — Est. 1797',
    ar: 'قهوة الفيشاوي والحلويات الشرقية، خان الخليلي — تأسست ١٧٩٧',
  };
  const v = await prisma.restaurant.findFirst({ where: { slug: 'el-fishawy-khan' }, select: { id: true, nameEn: true } });
  if (!v) return;
  if (v.nameEn === long.en) {
    console.log('  el-fishawy-khan: long name already applied — skipped');
    return;
  }
  await prisma.restaurant.update({ where: { id: v.id }, data: { nameEn: long.en, nameAr: long.ar } });
  console.log('  el-fishawy-khan: long name applied (and it stays otherwise BARE, on purpose)');
}

/**
 * MAKE THE BARE VENUE ACTUALLY BARE.
 *
 * `el-fishawy-khan` exists so the empty states are met deliberately rather
 * than discovered on whichever venue happened to fail. But the base seed and
 * every past e2e run leave rows behind, so it drifts into having a menu and a
 * review nobody intended — which is exactly what the first run of this script
 * found. Emptied on every run rather than assumed empty, and the assertion at
 * the end proves it worked.
 */
async function stripBareVenue(): Promise<void> {
  const v = await prisma.restaurant.findFirst({
    where: { slug: 'el-fishawy-khan' },
    select: { id: true },
  });
  if (!v) return;
  const reviews = await prisma.review.deleteMany({ where: { restaurantId: v.id } });
  const menus = await prisma.menu.deleteMany({ where: { restaurantId: v.id } });
  const images = await prisma.image.deleteMany({
    where: { ownerType: 'restaurant', ownerId: v.id },
  });
  if (reviews.count || menus.count || images.count) {
    console.log(
      `  el-fishawy-khan: stripped ${reviews.count} review(s), ${menus.count} menu(s), ` +
        `${images.count} image(s) so the empty states are genuine`,
    );
  }
}

async function main(): Promise<void> {
  console.log(`demo seed → API ${API}`);
  const venues = await prisma.restaurant.count();
  if (venues === 0) throw new Error('No venues. Run `pnpm seed` first.');

  console.log('menus:');
  await seedMenus();
  console.log('reviews (each needs a completed reservation — the schema requires one):');
  await seedReviews();
  console.log('long name:');
  await makeOneNameLong();
  console.log('photos, through POST /v1/admin/restaurants/:id/images:');
  await uploadPhotos(await adminToken());

  await stripBareVenue();

  const bare = await prisma.restaurant.findFirst({ where: { slug: 'el-fishawy-khan' }, select: { id: true } });
  if (bare) {
    const [img, menu, rev] = await Promise.all([
      prisma.image.count({ where: { ownerType: 'restaurant', ownerId: bare.id } }),
      prisma.menu.count({ where: { restaurantId: bare.id } }),
      prisma.review.count({ where: { restaurantId: bare.id } }),
    ]);
    // ASSERTED, NOT PRINTED. The first run reported `menus 1, reviews 1` and
    // carried on regardless — a check that observes a violated invariant and
    // does not fail on it is the shape this repo keeps finding. The base seed
    // and past e2e runs both leave rows behind, so "bare" has to be MADE bare
    // on every run and then proved.
    if (img !== 0 || menu !== 0 || rev !== 0) {
      throw new Error(
        'el-fishawy-khan is meant to be BARE so the empty states are met on ' +
          `purpose, but it has images ${img}, menus ${menu}, reviews ${rev}.`,
      );
    }
    console.log('\nel-fishawy-khan verified bare — images 0, menus 0, reviews 0');
  }
  console.log('\nDone. Availability comes from the weekly shifts `pnpm seed` created, so the');
  console.log('slot picker is populated for every day ahead without seeding dates.');
}

main()
  .catch((e) => {
    console.error(String(e instanceof Error ? e.message : e));
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
