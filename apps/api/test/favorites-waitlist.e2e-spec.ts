/**
 * GROUP C — saved places (C-2.7) and the waitlist (C-3.6).
 *
 * WRITTEN BEFORE EITHER CONTROLLER EXISTS.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE TWO PROPERTIES THAT MATTER, AND WHY THEY ARE HARD TO SEE
 * ─────────────────────────────────────────────────────────────────────────
 *
 * **Saving is idempotent.** A double tap on a Cairo mobile connection must not
 * put a venue in the list twice — and if it did, the second row would be
 * invisible to the diner and undeletable through a UI that only knows about
 * one. That is enforced by a unique index, so the assertion here is that the
 * API turns the collision into a normal answer rather than a 500.
 *
 * **A waitlist entry cannot be joined twice for the same venue and day, but a
 * CANCELLED one must stop blocking.** doc 04 says UNIQUE(restaurant_id,
 * user_id, desired_date) flatly; taken literally, a diner who joins, cancels
 * and changes their mind an hour later is refused forever. The index is
 * therefore partial on the live statuses, and both halves of that are asserted
 * — the refusal AND the re-join.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
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
let otherVenueId = '';
let ownerUserId = '';
let ownerId = '';

let mine = { id: '', token: '' };
let theirs = { id: '', token: '' };

const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 3);
  return d.toISOString().slice(0, 10);
})();

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

async function makeVenue(label: string): Promise<string> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             created_at, updated_at)
    VALUES (${ownerId}::uuid, ${`${label}-${suffix}`}, ${label}, 'مطعم',
            ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', now(), now())
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

  const account = await signUp(`+2051${suffix}`, 'Group C Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Group C Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  venueId = await makeVenue('groupc-primary');
  otherVenueId = await makeVenue('groupc-second');

  mine = await signUp(`+2052${suffix}`, 'Nour Hassan');
  theirs = await signUp(`+2053${suffix}`, 'Somebody Else');
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  for (const id of [venueId, otherVenueId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM favorites  WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM waitlists  WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${id}::uuid`;
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
//  SAVED PLACES — C-2.7
// ═══════════════════════════════════════════════════════════════════════════
describe('POST /v1/saved — save a venue', () => {
  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .post('/v1/saved')
      .send({ restaurantId: venueId })
      .expect(401);
  });

  it('saves it, and the list comes back', async () => {
    await request(http as never)
      .post('/v1/saved')
      .set(...auth(mine.token))
      .send({ restaurantId: venueId })
      .expect(201);

    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(mine.token))
      .expect(200);

    expect(res.body.map((r: { id: string }) => r.id)).toContain(venueId);
  });

  it('SAVING TWICE IS SAVING ONCE — 200, not a duplicate and not a 500', async () => {
    // A double tap on a bad connection. The unique index makes the second
    // INSERT fail at the database; the API has to turn that into the answer
    // the diner expects, which is "yes, it is saved".
    await request(http as never)
      .post('/v1/saved')
      .set(...auth(mine.token))
      .send({ restaurantId: venueId })
      .expect(200);

    const rows = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*)::bigint AS n FROM favorites
       WHERE user_id = ${mine.id}::uuid AND restaurant_id = ${venueId}::uuid`;
    expect(Number(rows[0].n)).toBe(1);
  });

  it('a venue that does not exist is a 404', async () => {
    await request(http as never)
      .post('/v1/saved')
      .set(...auth(mine.token))
      .send({ restaurantId: randomUUID() })
      .expect(404);
  });

  it("ANOTHER DINER'S LIST IS THEIR OWN", async () => {
    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(theirs.token))
      .expect(200);
    expect(res.body).toEqual([]);
  });

  it('the list is newest first', async () => {
    await request(http as never)
      .post('/v1/saved')
      .set(...auth(mine.token))
      .send({ restaurantId: otherVenueId })
      .expect(201);

    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(mine.token))
      .expect(200);

    expect(res.body[0].id).toBe(otherVenueId);
  });

  it('and each entry carries what a card needs to render', async () => {
    // The saved screen draws venue cards. A list of ids would mean one request
    // per row — twenty round trips over a Cairo mobile connection before the
    // first screenful.
    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(mine.token))
      .expect(200);

    const first = res.body[0];
    expect(first.name_en).toBeTruthy();
    expect(first.name_ar).toBeTruthy();
    expect(first.slug).toBeTruthy();
    expect(first.cuisines).toBeInstanceOf(Array);
    expect(first).toHaveProperty('cover');
  });
});

describe('DELETE /v1/saved/:restaurantId — unsave', () => {
  it('removes it', async () => {
    await request(http as never)
      .delete(`/v1/saved/${otherVenueId}`)
      .set(...auth(mine.token))
      .expect(204);

    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(mine.token))
      .expect(200);
    expect(res.body.map((r: { id: string }) => r.id)).not.toContain(otherVenueId);
  });

  it('UNSAVING SOMETHING NOT SAVED IS 204, NOT 404', async () => {
    // The button is a toggle. A diner who taps it twice, or whose first tap
    // succeeded and whose response was lost, must not be shown an error for
    // arriving at the state they wanted.
    await request(http as never)
      .delete(`/v1/saved/${otherVenueId}`)
      .set(...auth(mine.token))
      .expect(204);
  });

  it("cannot remove from somebody else's list", async () => {
    await request(http as never)
      .post('/v1/saved')
      .set(...auth(theirs.token))
      .send({ restaurantId: venueId })
      .expect(201);

    await request(http as never)
      .delete(`/v1/saved/${venueId}`)
      .set(...auth(mine.token))
      .expect(204);

    // Theirs survives — the delete was scoped to the caller.
    const res = await request(http as never)
      .get('/v1/saved')
      .set(...auth(theirs.token))
      .expect(200);
    expect(res.body.map((r: { id: string }) => r.id)).toContain(venueId);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  WAITLIST — C-3.6
// ═══════════════════════════════════════════════════════════════════════════
describe('POST /v1/waitlists — join when the venue is full', () => {
  const body = () => ({
    restaurantId: venueId,
    desiredDate: DATE,
    windowStart: `${DATE}T16:00:00.000Z`,
    windowEnd: `${DATE}T19:00:00.000Z`,
    partySize: 2,
  });

  it('an anonymous caller cannot', async () => {
    await request(http as never).post('/v1/waitlists').send(body()).expect(401);
  });

  it('joins, and comes back in the caller\'s list', async () => {
    const res = await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send(body())
      .expect(201);

    expect(res.body.status).toBe('waiting');
    expect(res.body.party_size).toBe(2);

    const list = await request(http as never)
      .get('/v1/waitlists')
      .set(...auth(mine.token))
      .expect(200);
    expect(list.body.map((w: { id: string }) => w.id)).toContain(res.body.id);
  });

  it('JOINING THE SAME VENUE AND DAY TWICE IS REFUSED', async () => {
    const res = await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send(body())
      .expect(409);
    expect(res.body.error.code).toBe('already_on_waitlist');
  });

  it('a window that ends before it starts is a 400', async () => {
    await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send({
        ...body(),
        desiredDate: '2027-01-01',
        windowStart: '2027-01-01T19:00:00.000Z',
        windowEnd: '2027-01-01T16:00:00.000Z',
      })
      .expect(400);
  });

  it('a date in the past is a 400', async () => {
    await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send({ ...body(), desiredDate: '2020-01-01' })
      .expect(400);
  });

  it('a venue that does not exist is a 404', async () => {
    await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send({ ...body(), restaurantId: randomUUID() })
      .expect(404);
  });
});

describe('DELETE /v1/waitlists/:id — leave', () => {
  it("cannot leave somebody else's", async () => {
    const list = await request(http as never)
      .get('/v1/waitlists')
      .set(...auth(mine.token))
      .expect(200);
    const id = list.body[0].id;

    await request(http as never)
      .delete(`/v1/waitlists/${id}`)
      .set(...auth(theirs.token))
      .expect(404);
  });

  it('leaves, and it drops out of the list', async () => {
    const list = await request(http as never)
      .get('/v1/waitlists')
      .set(...auth(mine.token))
      .expect(200);
    const id = list.body[0].id;

    await request(http as never)
      .delete(`/v1/waitlists/${id}`)
      .set(...auth(mine.token))
      .expect(204);

    const after = await request(http as never)
      .get('/v1/waitlists')
      .set(...auth(mine.token))
      .expect(200);
    expect(after.body.map((w: { id: string }) => w.id)).not.toContain(id);
  });

  it('AND A CANCELLED ENTRY STOPS BLOCKING A NEW ONE', async () => {
    // The reason the unique index is PARTIAL. doc 04 says
    // UNIQUE(restaurant_id, user_id, desired_date) flatly; taken literally, a
    // diner who joins, cancels, then changes their mind is refused forever for
    // that venue on that date. The deviation is recorded in the migration.
    const res = await request(http as never)
      .post('/v1/waitlists')
      .set(...auth(mine.token))
      .send({
        restaurantId: venueId,
        desiredDate: DATE,
        windowStart: `${DATE}T16:00:00.000Z`,
        windowEnd: `${DATE}T19:00:00.000Z`,
        partySize: 2,
      })
      .expect(201);

    expect(res.body.status).toBe('waiting');
  });

  it('the cancelled row is still there, not deleted', async () => {
    // History, and the venue's view of demand. A leave that removed the row
    // would erase the evidence that somebody wanted a table that night.
    const rows = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*)::bigint AS n FROM waitlists
       WHERE user_id = ${mine.id}::uuid AND status = 'cancelled'`;
    expect(Number(rows[0].n)).toBeGreaterThanOrEqual(1);
  });
});

describe('what the venue reads', () => {
  it('the waitlist entry records the window, not just the date', async () => {
    // A notification offering 22:30 to somebody who said 19:00–20:00 is worse
    // than no notification: it teaches them to ignore the next one.
    const rows = await prisma.$queryRaw<
      { window_start: Date; window_end: Date; priority: number }[]
    >`SELECT window_start, window_end, priority FROM waitlists
       WHERE user_id = ${mine.id}::uuid AND status = 'waiting' LIMIT 1`;

    expect(rows[0].window_start.toISOString()).toBe(`${DATE}T16:00:00.000Z`);
    expect(rows[0].window_end.toISOString()).toBe(`${DATE}T19:00:00.000Z`);
    // doc 04's loyalty boost, zero for everyone today.
    expect(rows[0].priority).toBe(0);
  });

  it('POSTGRES REFUSES AN OFFER WITH NO EXPIRY', async () => {
    // The claim window IS the feature (C-3.6, 10 minutes). An offer nothing
    // can reclaim would sit at the head of the queue forever.
    const rows = await prisma.$queryRaw<{ id: string }[]>`
      SELECT id FROM waitlists WHERE user_id = ${mine.id}::uuid
        AND status = 'waiting' LIMIT 1`;

    await expect(
      prisma.$executeRaw`UPDATE waitlists SET status = 'offered' WHERE id = ${rows[0].id}::uuid`,
    ).rejects.toThrow();
  });
});
