/**
 * GROUP D — menus (R-2.3) and reviews (C-4.4).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE ONE INVARIANT THE DATABASE CANNOT HOLD
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `reviews.reservation_id` is NOT NULL and UNIQUE, so the schema guarantees
 * "no review without a visit, one review per visit". It cannot guarantee that
 * the visit HAPPENED — a CHECK cannot read another table, and every mechanism
 * that can makes an unrelated later write fail.
 *
 * So `ReviewsService.assertEligible` holds it, and this file attempts a review
 * from EVERY non-eligible status rather than asserting the happy path twice.
 * A rule that lives in code is only as good as the test that attacks it, and
 * "the happy path works" is not an attack.
 *
 * Also here, because the schema was where they were argued:
 *   · the dietary vocabulary refuses a tag outside the list
 *   · the rating trigger recomputes rather than increments
 *   · a NUMERIC(12,2) price survives to the wire as a decimal STRING
 *   · a suspended venue's menu and reviews vanish with its profile
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;

const suffix = Date.now().toString().slice(-9);

let venueId = '';
let venueSlug = '';
let suspendedId = '';
let ownerUserId = '';
let ownerId = '';
let menuId = '';
let categoryId = '';

let mine = { id: '', token: '' };
let theirs = { id: '', token: '' };

const auth = (token: string): [string, string] => ['Authorization', `Bearer ${token}`];

async function signUp(phone: string, name: string): Promise<{ id: string; token: string }> {
  const reg = await request(http as never)
    .post('/v1/auth/register')
    .send({ phone, fullName: name })
    .expect(201);
  const code = delivery.sent.filter((m) => m.phone === phone).at(-1)!.code;
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: reg.body.challengeId, code })
    .expect(200);
  return { id: reg.body.userId as string, token: pair.body.tokens.accessToken as string };
}

async function makeVenue(label: string, status = 'active'): Promise<string> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             created_at, updated_at)
    VALUES (${ownerId}::uuid, ${`${label}-${suffix}`}, ${label}, 'مطعم',
            ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            ${status}::restaurant_status, 'Africa/Cairo', now(), now())
    RETURNING id`;
  return rows[0].id;
}

/**
 * A reservation in whatever state the test needs, written straight to the
 * table.
 *
 * Deliberately NOT through the booking endpoint. Getting a real reservation
 * into `no_show` needs the venue action that does not exist yet, and a test
 * that could only reach three of the nine statuses would leave six untested —
 * which is where the bug would be.
 */
async function reservationIn(
  status: string,
  opts: { userId: string; hoursAgo?: number; restaurantId?: string },
): Promise<string> {
  const hoursAgo = opts.hoursAgo ?? 26;
  const startsAt = new Date(Date.now() - hoursAgo * 3_600_000);
  const endsAt = new Date(startsAt.getTime() + 90 * 60_000);
  const code = `T${Date.now().toString().slice(-6)}${Math.floor(Math.random() * 9)}`;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (code, restaurant_id, user_id, party_size,
                              starts_at, ends_at, status, source,
                              created_at, updated_at)
    VALUES (${code}, ${opts.restaurantId ?? venueId}::uuid, ${opts.userId}::uuid, 2,
            ${startsAt}, ${endsAt}, ${status}::reservation_status, 'app', now(), now())
    RETURNING id`;
  return rows[0].id;
}

beforeAll(async () => {
  await prisma.$connect();
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();

  const account = await signUp(`+2061${suffix}`, 'Group D Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Group D Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  venueId = await makeVenue('groupd-primary');
  venueSlug = `groupd-primary-${suffix}`;
  suspendedId = await makeVenue('groupd-suspended', 'suspended');

  mine = await signUp(`+2062${suffix}`, 'Nour Hassan');
  theirs = await signUp(`+2063${suffix}`, 'Somebody Else');

  const menu = await prisma.menu.create({
    data: { restaurantId: venueId, nameEn: 'Kitchen', nameAr: 'المطبخ', kind: 'food' },
  });
  menuId = menu.id;
  const category = await prisma.menuCategory.create({
    data: { menuId: menu.id, nameEn: 'Mezze', nameAr: 'مقبّلات', position: 0 },
  });
  categoryId = category.id;
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  for (const id of [venueId, suspendedId].filter(Boolean)) {
    await prisma.$executeRaw`
      DELETE FROM reviews WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`
      DELETE FROM reservation_tables WHERE reservation_id IN
        (SELECT id FROM reservations WHERE restaurant_id = ${id}::uuid)`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM menus        WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${id}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [mine.id, theirs.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

// ═══════════════════════════════════════════════════════════════════════════
//  MENUS — R-2.3, C-2.6
// ═══════════════════════════════════════════════════════════════════════════
describe('GET /v1/restaurants/:idOrSlug/menus', () => {
  it('is public — no token, and the route is not shadowed by the wildcard', async () => {
    // `GET /restaurants/:idOrSlug` is a one-segment wildcard registered after
    // this module. If the ordering in app.module.ts is ever changed, THIS is
    // what says so — the failure would otherwise be a 404 on a screen nobody
    // tests without a server.
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('resolves by slug as well as id', async () => {
    await request(http as never).get(`/v1/restaurants/${venueSlug}/menus`).expect(200);
  });

  it('a suspended venue 404s here exactly as it does on its profile', async () => {
    // Otherwise the platform publishes the prices of a restaurant it has taken
    // off the platform.
    await request(http as never).get(`/v1/restaurants/${suspendedId}/menus`).expect(404);
    await request(http as never).get(`/v1/restaurants/${suspendedId}`).expect(404);
  });

  it('an empty menu is not returned at all', async () => {
    // The menu row exists with a category and no items. A heading with nothing
    // under it reads as a screen that failed to load.
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);
    expect(res.body).toEqual([]);
  });

  it('a price arrives as a decimal STRING, with its scale intact', async () => {
    await prisma.menuItem.create({
      data: {
        categoryId,
        nameEn: 'Charred halloumi & date honey',
        nameAr: 'حلومي مشوي بعسل البلح',
        price: '320.00',
        dietaryTags: ['vegetarian'],
        position: 0,
      },
    });

    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);

    const item = res.body[0].categories[0].items[0];

    // THE WHOLE POINT. `320` would be what a JSON number does to NUMERIC(12,2),
    // and a menu that prints 320 where the kitchen prints 320.00 has lost the
    // scale CLAUDE.md rule 5 exists to keep.
    expect(item.price).toBe('320.00');
    expect(typeof item.price).toBe('string');
    expect(item.currency).toBe('EGP');
    expect(item.dietary_tags).toEqual(['vegetarian']);
  });

  it('an unavailable item is not sent, and its category goes with it if it was the only one', async () => {
    const gone = await prisma.menuItem.create({
      data: {
        categoryId,
        nameEn: 'Sea bass',
        nameAr: 'قاروص',
        price: '620.00',
        available: false,
        position: 1,
      },
    });

    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);

    const names = res.body[0].categories.flatMap((c: { items: { id: string }[] }) =>
      c.items.map((i) => i.id),
    );
    expect(names).not.toContain(gone.id);
  });

  it('the PDF fallback produces a URL, and only when a key is stored', async () => {
    // R-2.3: "many Cairo venues have only PDF/paper menus". The seed does not
    // create one — a key with no object behind it would put a button in the app
    // that opens a 404 — so this is where the fallback is actually exercised.
    const before = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);
    expect(before.body[0].pdf_url).toBeNull();

    await prisma.menu.update({
      where: { id: menuId },
      data: { pdfKey: `menus/${venueId}/carte.pdf` },
    });

    const after = await request(http as never)
      .get(`/v1/restaurants/${venueId}/menus`)
      .expect(200);
    expect(after.body[0].pdf_url).toContain(`menus/${venueId}/carte.pdf`);
    expect(after.body[0].pdf_url).toMatch(/^https?:\/\//);

    await prisma.menu.update({ where: { id: menuId }, data: { pdfKey: null } });
  });
});

describe('the dietary vocabulary is a schema fact, not a convention', () => {
  it('refuses a tag outside the list', async () => {
    // Without the CHECK, this row would insert and the tag would then vanish at
    // render time, because the client skips keys it has no copy for. A typo
    // that disappears is worse than one that fails.
    await expect(
      prisma.menuItem.create({
        data: {
          categoryId,
          nameEn: 'Mystery',
          nameAr: 'غامض',
          price: '1.00',
          dietaryTags: ['Gluten_Free'],
          position: 90,
        },
      }),
    ).rejects.toThrow(/menu_items_dietary_vocabulary/);
  });

  it('and there is deliberately no `halal` tag', async () => {
    // We mark the exception, never the default. In Cairo halal is the default,
    // and tagging it would imply the unmarked dishes are not.
    await expect(
      prisma.menuItem.create({
        data: {
          categoryId,
          nameEn: 'Anything',
          nameAr: 'أي حاجة',
          price: '1.00',
          dietaryTags: ['halal'],
          position: 91,
        },
      }),
    ).rejects.toThrow(/menu_items_dietary_vocabulary/);
  });

  it('accepts the two inverses that DO carry information', async () => {
    const ok = await prisma.menuItem.create({
      data: {
        categoryId,
        nameEn: 'Bacon thing',
        nameAr: 'حاجة بالبيكون',
        price: '1.00',
        dietaryTags: ['contains_pork', 'contains_alcohol', 'shellfish'],
        position: 92,
        available: false,
      },
    });
    expect(ok.dietaryTags).toContain('contains_pork');
    await prisma.menuItem.delete({ where: { id: ok.id } });
  });

  it('a negative price is refused', async () => {
    await expect(
      prisma.menuItem.create({
        data: { categoryId, nameEn: 'Owed', nameAr: 'مدين', price: '-1.00', position: 93 },
      }),
    ).rejects.toThrow(/menu_items_price_not_negative/);
  });

  it('but a free item is fine — bread, water, the mint tea with the bill', async () => {
    const free = await prisma.menuItem.create({
      data: { categoryId, nameEn: 'Bread', nameAr: 'عيش', price: '0.00', position: 94, available: false },
    });
    expect(free.price.toString()).toBe('0');
    await prisma.menuItem.delete({ where: { id: free.id } });
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  REVIEWS — C-4.4
// ═══════════════════════════════════════════════════════════════════════════
describe('POST /v1/reviews — the eligibility rule that lives in code', () => {
  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .post('/v1/reviews')
      .send({ reservationId: '00000000-0000-4000-8000-000000000000', rating: 5 })
      .expect(401);
  });

  /**
   * EVERY NON-ELIGIBLE STATUS, one case each.
   *
   * This is the list the database cannot enforce. `held`, `pending` and
   * `confirmed` are visits that have not happened; `no_show` is a table that
   * sat empty; both cancellations are meals nobody ate. A diner whose table the
   * VENUE cancelled has a real complaint, and it is still not a review — that
   * belongs in support, which is the honest answer rather than the convenient
   * one.
   */
  const ineligible = [
    'held',
    'pending',
    'confirmed',
    'no_show',
    'cancelled_by_user',
    'cancelled_by_restaurant',
    'expired',
  ];

  it.each(ineligible)('refuses a %s reservation with review_not_eligible', async (status) => {
    const id = await reservationIn(status, { userId: mine.id });
    const res = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(403);
    expect(res.body.error.code).toBe('review_not_eligible');
  });

  it('accepts a seated reservation whose table time is over', async () => {
    const id = await reservationIn('seated', { userId: mine.id });
    const res = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 4, foodRating: 5, body: '  Lovely.  ' })
      .expect(201);

    expect(res.body.rating).toBe(4);
    expect(res.body.food_rating).toBe(5);
    // Trimmed, because a body of spaces is the empty body it actually is.
    expect(res.body.body).toBe('Lovely.');
  });

  it('and a completed one', async () => {
    const id = await reservationIn('completed', { userId: mine.id });
    await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(201);
  });

  it('refuses a seated reservation that is STILL RUNNING', async () => {
    // The status alone would let somebody review the starter. doc 06 says
    // "completed" and C-4.4 says "seated"; accepting `seated` is what keeps the
    // feature reachable before the venue's `complete` action exists, and this
    // is what makes accepting it safe.
    const id = await reservationIn('seated', { userId: mine.id, hoursAgo: 0 });
    const res = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(403);
    expect(res.body.error.code).toBe('review_too_early');
  });

  it("another diner's reservation is a 404, not a 403", async () => {
    // A 403 would confirm the id exists, which turns this endpoint into a way
    // to test whether a reservation id is real.
    const id = await reservationIn('completed', { userId: theirs.id });
    const res = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(404);
    expect(res.body.error.code).toBe('reservation_not_found');
  });

  it('one review per visit — the second is a 409', async () => {
    const id = await reservationIn('completed', { userId: mine.id });
    await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(201);

    const res = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 1, body: 'Changed my mind' })
      .expect(409);
    expect(res.body.error.code).toBe('review_already_exists');
  });

  it('rejects `photo_ids` out loud rather than dropping it', async () => {
    // C-4.4 wants review photos; the multipart boundary forbids a diner-facing
    // upload path. Accepting the field and storing nothing would tell a client
    // its photos were attached.
    const id = await reservationIn('completed', { userId: mine.id });
    await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5, photo_ids: ['x'] })
      .expect(400);
  });

  it('a rating outside 1–5 is a 400 before it reaches the CHECK', async () => {
    const id = await reservationIn('completed', { userId: mine.id });
    await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 6 })
      .expect(400);
  });
});

describe('can_review on a reservation agrees with what POST /reviews actually does', () => {
  /**
   * THE TWO-COPIES FAILURE, TESTED FOR DIRECTLY.
   *
   * The bookings screen has to decide whether to draw a "write a review"
   * control before the diner taps anything, so it needs to PREDICT the
   * eligibility rule. Both sides call `review-eligibility.ts`, but a shared
   * function is only a guarantee while both sides keep calling it — and the
   * copy that would drift is the one nobody tests against a real `no_show`.
   *
   * So this asks the reservation what it thinks, then attempts the review, and
   * fails if they disagree. It would catch the rule being reimplemented on
   * either side, which is the actual risk.
   */
  const cases: [string, number][] = [
    ['completed', 26],
    ['seated', 26],
    ['seated', 0],
    ['no_show', 26],
    ['confirmed', 26],
    ['cancelled_by_user', 26],
  ];

  it.each(cases)('%s (%s hours ago)', async (status, hoursAgo) => {
    const id = await reservationIn(status, { userId: mine.id, hoursAgo });

    const detail = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);

    const attempt = await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 4 });

    const accepted = attempt.status === 201;
    expect(detail.body.can_review).toBe(accepted);
  });

  it('and flips to false once the review exists, without the status changing', async () => {
    const id = await reservationIn('completed', { userId: mine.id });

    const before = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);
    expect(before.body.can_review).toBe(true);
    expect(before.body.review_id).toBeNull();

    await request(http as never)
      .post('/v1/reviews')
      .set(...auth(mine.token))
      .send({ reservationId: id, rating: 5 })
      .expect(201);

    const after = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);
    expect(after.body.can_review).toBe(false);
    expect(after.body.review_id).not.toBeNull();
  });
});

describe('GET /v1/restaurants/:idOrSlug/reviews', () => {
  it('is public, and shows the author as a first name and an initial', async () => {
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/reviews`)
      .expect(200);

    expect(res.body.results.length).toBeGreaterThan(0);
    // "Nour Hassan" — the name given at registration — must never be published
    // in full under a review of a place somebody was on a given evening.
    for (const r of res.body.results) {
      expect(r.author).toBe('Nour H.');
      expect(r.author).not.toContain('Hassan');
    }
  });

  it('the summary is computed from the reviews, and the breakdown always has five keys', async () => {
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}/reviews`)
      .expect(200);

    expect(Object.keys(res.body.summary.breakdown).sort()).toEqual(['1', '2', '3', '4', '5']);

    const summed = Object.values(res.body.summary.breakdown as Record<string, number>).reduce(
      (a, b) => a + b,
      0,
    );
    expect(summed).toBe(res.body.summary.rating_count);
  });

  it('a suspended venue 404s', async () => {
    await request(http as never).get(`/v1/restaurants/${suspendedId}/reviews`).expect(404);
  });

  it('paginates by keyset — page two does not repeat page one', async () => {
    const first = await request(http as never)
      .get(`/v1/restaurants/${venueId}/reviews?limit=1`)
      .expect(200);
    expect(first.body.next_cursor).not.toBeNull();

    const second = await request(http as never)
      .get(`/v1/restaurants/${venueId}/reviews?limit=1&cursor=${encodeURIComponent(first.body.next_cursor)}`)
      .expect(200);

    expect(second.body.results[0].id).not.toBe(first.body.results[0].id);
  });
});

describe('rating_avg is RECOMPUTED, never incremented', () => {
  const ratingOf = async (): Promise<{ avg: number; count: number }> => {
    const rows = await prisma.$queryRaw<{ rating_avg: string; rating_count: number }[]>`
      SELECT rating_avg, rating_count FROM restaurants WHERE id = ${venueId}::uuid`;
    return { avg: Number(rows[0].rating_avg), count: Number(rows[0].rating_count) };
  };

  it('the venue rating matches its published reviews exactly', async () => {
    const cached = await ratingOf();
    const rows = await prisma.$queryRaw<{ avg: string | null; n: bigint }[]>`
      SELECT ROUND(AVG(rating), 2) AS avg, COUNT(*) AS n
        FROM reviews WHERE restaurant_id = ${venueId}::uuid AND status = 'published'`;

    expect(cached.count).toBe(Number(rows[0].n));
    expect(cached.avg).toBeCloseTo(Number(rows[0].avg ?? 0), 2);
  });

  it('moderating a review OUT takes it back out of the average', async () => {
    // A trigger on INSERT alone would leave a removed review still counted, and
    // moderation that does not move the rating has not moderated anything.
    const before = await ratingOf();

    const one = await prisma.review.findFirst({
      where: { restaurantId: venueId, status: 'published' },
      orderBy: { createdAt: 'asc' },
    });
    await prisma.review.update({ where: { id: one!.id }, data: { status: 'removed' } });

    const after = await ratingOf();
    expect(after.count).toBe(before.count - 1);

    await prisma.review.update({ where: { id: one!.id }, data: { status: 'published' } });
    expect((await ratingOf()).count).toBe(before.count);
  });

  it('deleting every review returns the venue to zero, not to a stale average', async () => {
    // The increment version of this passes the two tests above and fails here:
    // an increment has no way back to 0, and a venue whose last review is
    // removed would keep advertising a rating it no longer has.
    const kept = await prisma.review.findMany({ where: { restaurantId: venueId } });
    await prisma.$executeRaw`DELETE FROM reviews WHERE restaurant_id = ${venueId}::uuid`;

    const empty = await ratingOf();
    expect(empty.count).toBe(0);
    expect(empty.avg).toBe(0);

    for (const r of kept) {
      await prisma.review.create({
        data: {
          id: r.id,
          reservationId: r.reservationId,
          userId: r.userId,
          restaurantId: r.restaurantId,
          rating: r.rating,
          foodRating: r.foodRating,
          serviceRating: r.serviceRating,
          ambienceRating: r.ambienceRating,
          body: r.body,
          status: r.status,
          createdAt: r.createdAt,
        },
      });
    }
    expect((await ratingOf()).count).toBe(kept.length);
  });
});

describe('the reply pair cannot come apart', () => {
  it('a timestamp with no reply is refused', async () => {
    const one = await prisma.review.findFirst({ where: { restaurantId: venueId } });
    await expect(
      prisma.review.update({
        where: { id: one!.id },
        data: { ownerRepliedAt: new Date() },
      }),
    ).rejects.toThrow(/reviews_reply_has_timestamp/);
  });

  it('and a reply with no timestamp is too', async () => {
    const one = await prisma.review.findFirst({ where: { restaurantId: venueId } });
    await expect(
      prisma.review.update({
        where: { id: one!.id },
        data: { ownerReply: 'Thank you' },
      }),
    ).rejects.toThrow(/reviews_reply_has_timestamp/);
  });

  it('a review cannot be deleted out from under a reservation', async () => {
    // ON DELETE RESTRICT. A reservation with a review attached is not a row
    // anything should be able to quietly remove.
    const one = await prisma.review.findFirst({ where: { restaurantId: venueId } });
    await expect(
      prisma.$executeRaw`DELETE FROM reservations WHERE id = ${one!.reservationId}::uuid`,
    ).rejects.toThrow();
  });
});
