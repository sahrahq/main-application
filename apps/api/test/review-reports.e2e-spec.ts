/**
 * C-4.4's report flow — and the assertion that carries the file is a NEGATIVE
 * one.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * A REPORT MUST NOT CHANGE THE REVIEW
 * ─────────────────────────────────────────────────────────────────────────
 *
 * The Group D schema doc said `pending_moderation` was "a state a REPORT moves
 * a review into". Building it showed that is wrong, and dangerously so.
 *
 * The venue page reads `status = 'published'`, and the rating trigger averages
 * the same set. So a report that moved a review to `pending_moderation` would
 * remove it from the venue's page AND from its rating — meaning **one account
 * could silence any review**, with no moderator to release it. That is the
 * brigading `idx_review_reports_unique` exists to prevent, achieved through the
 * front door.
 *
 * Negative properties are normally unprovable and end up as a promise in prose.
 * This one is provable because all three consequences are observable: the
 * review's status, its presence on the public list, and the venue's
 * `rating_count`. All three are read before and after.
 *
 * ── AND THE OTHER NEGATIVE: NOTHING READS A REPORT ───────────────────────
 *
 * The queue is A-3 and is not built. There is no endpoint that lists reports,
 * so the assertion is on the SPEC: no path matching `/report` exists other than
 * the one that files one. If somebody adds a reader, this fails and they have to
 * come and read the terms it was accepted under.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { readFileSync } from 'fs';
import { join } from 'path';
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
let ownerUserId = '';
let ownerId = '';

let author = { id: '', token: '' };
let reader = { id: '', token: '' };

let reviewId = '';

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

/** A completed visit, written straight to the table — see menus-reviews spec. */
async function pastVisit(userId: string): Promise<string> {
  const startsAt = new Date(Date.now() - 26 * 3_600_000);
  const endsAt = new Date(startsAt.getTime() + 90 * 60_000);
  const code = `R${Date.now().toString().slice(-6)}${Math.floor(Math.random() * 9)}`;
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (code, restaurant_id, user_id, party_size,
                              starts_at, ends_at, status, source, created_at, updated_at)
    VALUES (${code}, ${venueId}::uuid, ${userId}::uuid, 2,
            ${startsAt}, ${endsAt}, 'completed'::reservation_status, 'app', now(), now())
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

  const account = await signUp(`+2071${suffix}`, 'Reports Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Reports Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  venueSlug = `reports-venue-${suffix}`;
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone, created_at, updated_at)
    VALUES (${ownerId}::uuid, ${venueSlug}, 'Reports Venue', 'مطعم', ARRAY['levantine'],
            'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', now(), now())
    RETURNING id`;
  venueId = rows[0].id;

  author = await signUp(`+2072${suffix}`, 'Nour Hassan');
  reader = await signUp(`+2073${suffix}`, 'Omar Abdelrahman');

  // A real review, through the real endpoint.
  const visit = await pastVisit(author.id);
  const posted = await request(http as never)
    .post('/v1/reviews')
    .set(...auth(author.token))
    .send({ reservationId: visit, rating: 5, body: 'Lovely evening.' })
    .expect(201);
  reviewId = posted.body.id as string;
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  if (venueId) {
    await prisma.$executeRaw`
      DELETE FROM review_reports WHERE review_id IN
        (SELECT id FROM reviews WHERE restaurant_id = ${venueId}::uuid)`;
    await prisma.$executeRaw`DELETE FROM reviews      WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${venueId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [author.id, reader.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('POST /v1/reviews/:id/report', () => {
  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .send({ reason: 'spam' })
      .expect(401);
  });

  it('the setup produced a real, published review — census', async () => {
    // Every assertion below is about a review. Without this they could all be
    // about nothing.
    const row = await prisma.review.findUnique({ where: { id: reviewId } });
    expect(row?.status).toBe('published');
  });

  it('files one, and a second press is the same report', async () => {
    await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(reader.token))
      .send({ reason: 'spam', note: '  Same text three times.  ' })
      .expect(201);

    // 200, not 409. A second press means the same thing as the first, and the
    // first response may simply have been lost.
    await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(reader.token))
      .send({ reason: 'abusive' })
      .expect(200);

    // ONE ROW. This is the anti-brigading guarantee, and it is the index rather
    // than the endpoint that provides it.
    const count = await prisma.reviewReport.count({ where: { reviewId } });
    expect(count).toBe(1);

    // And the note was trimmed, not stored with its whitespace.
    const row = await prisma.reviewReport.findFirst({ where: { reviewId } });
    expect(row?.note).toBe('Same text three times.');
    expect(row?.status).toBe('open');
    expect(row?.resolvedAt).toBeNull();
  });

  it('refuses your own review, because you meant something else', async () => {
    const res = await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(author.token))
      .send({ reason: 'other' })
      .expect(400);
    expect(res.body.error.code).toBe('cannot_report_own_review');
  });

  it('a reason outside the set is a 400', async () => {
    await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(reader.token))
      .send({ reason: 'i_just_do_not_like_it' })
      .expect(400);
  });

  it('a review that is not published is a 404, same as one that does not exist', async () => {
    await prisma.review.update({ where: { id: reviewId }, data: { status: 'removed' } });

    const hidden = await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(reader.token))
      .send({ reason: 'spam' })
      .expect(404);

    const missing = await request(http as never)
      .post('/v1/reviews/00000000-0000-4000-8000-000000000000/report')
      .set(...auth(reader.token))
      .send({ reason: 'spam' })
      .expect(404);

    // BYTE-IDENTICAL but for the request id. A different answer for "hidden"
    // and "never existed" tells a prober which ids are real.
    expect(hidden.body.error.code).toBe(missing.body.error.code);

    await prisma.review.update({ where: { id: reviewId }, data: { status: 'published' } });
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  THE NEGATIVE PROPERTY
// ═══════════════════════════════════════════════════════════════════════════
describe('a report changes NOTHING about the review', () => {
  it('not its status, not its place on the venue page, not the rating', async () => {
    const before = await prisma.review.findUnique({ where: { id: reviewId } });
    const ratingBefore = await prisma.$queryRaw<{ avg: string; n: number }[]>`
      SELECT rating_avg AS avg, rating_count AS n FROM restaurants WHERE id = ${venueId}::uuid`;

    const listBefore = await request(http as never)
      .get(`/v1/restaurants/${venueSlug}/reviews`)
      .expect(200);
    expect(listBefore.body.results.map((r: { id: string }) => r.id)).toContain(reviewId);

    // Report it — from a diner who has not already, so the write really happens.
    const third = await signUp(`+2074${suffix}`, 'Laila Fahmy');
    await request(http as never)
      .post(`/v1/reviews/${reviewId}/report`)
      .set(...auth(third.token))
      .send({ reason: 'abusive' })
      .expect(201);

    // 1. STATUS UNCHANGED. If a report moved it to `pending_moderation`, one
    //    account could silence any review and no moderator exists to undo it.
    const after = await prisma.review.findUnique({ where: { id: reviewId } });
    expect(after!.status).toBe(before!.status);

    // 2. STILL ON THE VENUE PAGE. The consequence a diner would see.
    const listAfter = await request(http as never)
      .get(`/v1/restaurants/${venueSlug}/reviews`)
      .expect(200);
    expect(listAfter.body.results.map((r: { id: string }) => r.id)).toContain(reviewId);
    expect(listAfter.body.summary.rating_count).toBe(listBefore.body.summary.rating_count);

    // 3. AND THE VENUE'S RATING. The consequence the venue would see.
    const ratingAfter = await prisma.$queryRaw<{ avg: string; n: number }[]>`
      SELECT rating_avg AS avg, rating_count AS n FROM restaurants WHERE id = ${venueId}::uuid`;
    expect(Number(ratingAfter[0].avg)).toBe(Number(ratingBefore[0].avg));
    expect(Number(ratingAfter[0].n)).toBe(Number(ratingBefore[0].n));

    // 4. AND THE REPORT REALLY WAS WRITTEN. Without this the three assertions
    //    above pass on a report that never happened, which is the same
    //    vacuous-pass shape as a scanner pointed at an empty directory.
    expect(await prisma.reviewReport.count({ where: { reviewId } })).toBe(2);

    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${third.id}::uuid`;
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  AND THE OTHER NEGATIVE: NOTHING READS A REPORT
// ═══════════════════════════════════════════════════════════════════════════
describe('the queue is A-3, and it is not built', () => {
  const spec = JSON.parse(
    readFileSync(join(__dirname, '..', 'openapi.json'), 'utf8'),
  ) as { paths: Record<string, Record<string, unknown>> };

  it('the spec was read — census', () => {
    expect(Object.keys(spec.paths).length).toBeGreaterThanOrEqual(40);
  });

  it('exactly ONE endpoint mentions a report, and it is the one that files one', () => {
    /**
     * "Recording with no reader, deliberately" is a decision, and this is what
     * makes it a checkable one. A reader added later fails here, and whoever
     * adds it has to come and read the terms the recording half was accepted
     * under — rather than discovering months on that reports have been
     * accumulating unseen.
     *
     * When A-3 arrives it adds `/admin/moderation/queue` and this list grows to
     * two, deliberately, in the same commit that builds the queue.
     */
    const reportPaths = Object.entries(spec.paths)
      .flatMap(([path, item]) =>
        Object.keys(item).map((method) => `${method.toUpperCase()} ${path}`),
      )
      .filter((id) => id.toLowerCase().includes('report') || id.includes('moderation'))
      .sort();

    expect(reportPaths).toEqual(['POST /v1/reviews/{id}/report']);
  });
});
