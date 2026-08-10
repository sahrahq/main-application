/**
 * A diner's own reservations — doc 06 §3:
 *
 *   | `/reservations`     | GET | `?status=upcoming\|past` | 200 list |
 *   | `/reservations/:id` | GET |                          | 200      |
 *
 * WRITTEN BEFORE THE IMPLEMENTATION. Neither route exists.
 *
 * OWNERSHIP IS THE POINT OF THIS FILE. doc 06 puts staff reads on a separate
 * route (`/owner/restaurants/:id/reservations`), so these two are the DINER'S
 * and nobody else's. Another user's reservation must answer **404, not 403** —
 * the same reasoning applied at `/restaurants/:idOrSlug`: a 403 confirms the
 * row exists, which turns the endpoint into an oracle for "does reservation
 * X exist", and reservation ids are guessable in bulk in a way venue slugs are
 * not.
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

let ownerUserId: string;
let ownerId: string;
let restaurantId: string;
let tableId: string;

/** The diner these reservations belong to. */
let mine = { id: '', token: '' };
/** Somebody else, whose token must not open them. */
let theirs = { id: '', token: '' };

let upcomingId = '';
let pastId = '';
let cancelledId = '';
let heldId = '';

async function signUp(phone: string, name: string): Promise<{ id: string; token: string }> {
  const reg = await request(http as never)
    .post('/v1/auth/register')
    .send({ phone, fullName: name })
    .expect(201);

  const code = delivery.sent.filter((m) => m.phone === phone).at(-1)!.code;
  // The challenge HANDLE comes back from register — challenges are no longer
  // addressable by user id, which is what closed AUTH-3. And verify-otp is
  // discriminated now: this account already exists, so it signs in.
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: reg.body.challengeId, code })
    .expect(200);

  return { id: reg.body.userId as string, token: pair.body.tokens.accessToken as string };
}

/** Insert a reservation directly — this suite is about READING them. */
async function seedReservation(opts: {
  userId: string | null;
  startsAt: Date;
  status: string;
  code: string;
}): Promise<string> {
  const endsAt = new Date(opts.startsAt.getTime() + 90 * 60_000);
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (
      code, restaurant_id, user_id, party_size, starts_at, ends_at,
      status, source, created_at, updated_at
    ) VALUES (
      ${opts.code}, ${restaurantId}::uuid, ${opts.userId}::uuid, 2,
      ${opts.startsAt}, ${endsAt},
      ${opts.status}::reservation_status, 'app', now(), now()
    ) RETURNING id`;

  const id = rows[0].id;
  await prisma.$executeRaw`
    INSERT INTO reservation_tables (reservation_id, table_id, during)
    VALUES (${id}::uuid, ${tableId}::uuid,
            tstzrange(${opts.startsAt}, ${endsAt}, '[)'))`;
  return id;
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

  // A venue to hang the reservations on.
  ownerUserId = randomUUID();
  await prisma.user.create({
    data: { id: ownerUserId, phone: `+2091${suffix}`, fullName: 'Res Owner', status: 'active' },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Res Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const r = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             created_at, updated_at)
    VALUES (${ownerId}::uuid, ${'my-res-venue-' + suffix}, 'My Res Venue', 'مطعم حجوزاتي',
            ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', now(), now())
    RETURNING id`;
  restaurantId = r[0].id;

  const t = await prisma.table.create({
    data: { restaurantId, name: 'R1', minCapacity: 1, maxCapacity: 4 },
  });
  tableId = t.id;

  mine = await signUp(`+2092${suffix}`, 'Nour Hassan');
  theirs = await signUp(`+2093${suffix}`, 'Somebody Else');

  const soon = new Date(Date.now() + 2 * 86_400_000);
  const before = new Date(Date.now() - 3 * 86_400_000);

  upcomingId = await seedReservation({
    userId: mine.id, startsAt: soon, status: 'confirmed', code: `UPC${suffix.slice(-5)}`,
  });
  pastId = await seedReservation({
    userId: mine.id, startsAt: before, status: 'completed', code: `PST${suffix.slice(-5)}`,
  });
  cancelledId = await seedReservation({
    userId: mine.id,
    startsAt: new Date(Date.now() + 5 * 86_400_000),
    status: 'cancelled_by_user',
    code: `CAN${suffix.slice(-5)}`,
  });
  heldId = await seedReservation({
    userId: mine.id,
    startsAt: new Date(Date.now() + 7 * 86_400_000),
    status: 'held',
    code: `HLD${suffix.slice(-5)}`,
  });
}, 120_000);

afterAll(async () => {
  if (app) await app.close();
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id IN
      (SELECT id FROM reservations WHERE restaurant_id = ${restaurantId}::uuid)`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${restaurantId}::uuid`;
  }
  for (const id of [mine.id, theirs.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [mine.id, theirs.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM users WHERE id = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

const auth = (token: string): [string, string] => ['Authorization', `Bearer ${token}`];

describe('GET /v1/reservations', () => {
  it('requires an account', async () => {
    await request(http as never).get('/v1/reservations').expect(401);
  });

  it('returns the caller\'s upcoming bookings by default', async () => {
    const res = await request(http as never)
      .get('/v1/reservations')
      .set(...auth(mine.token))
      .expect(200);

    const ids = (res.body as { id: string }[]).map((r) => r.id);
    expect(ids).toContain(upcomingId);
    expect(ids).not.toContain(pastId);
  });

  it('EXCLUDES a held reservation — a 5-minute hold is not a booking', async () => {
    // It expires on its own and would vanish from the list while the diner
    // looked at it. Worse, it reads as a confirmed table that they do not have.
    const res = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);

    expect((res.body as { id: string }[]).map((r) => r.id)).not.toContain(heldId);
  });

  it('puts a CANCELLED future booking in past, not upcoming', async () => {
    // "Upcoming" answers "where am I going?", and the answer is not there.
    // It still belongs in history, because a diner looking for what happened
    // to a booking they cancelled should find it.
    const upcoming = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);
    expect((upcoming.body as { id: string }[]).map((r) => r.id)).not.toContain(cancelledId);

    const past = await request(http as never)
      .get('/v1/reservations?status=past')
      .set(...auth(mine.token))
      .expect(200);
    expect((past.body as { id: string }[]).map((r) => r.id)).toContain(cancelledId);
  });

  it('never leaks another diner\'s bookings', async () => {
    const res = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(theirs.token))
      .expect(200);

    expect(res.body).toEqual([]);
  });

  it('carries the venue and a venue-LOCAL time, so the client guesses nothing', async () => {
    const res = await request(http as never)
      .get('/v1/reservations')
      .set(...auth(mine.token))
      .expect(200);

    const row = (res.body as Record<string, unknown>[]).find((r) => r.id === upcomingId)!;
    expect(row.restaurant).toMatchObject({
      id: restaurantId,
      name_en: 'My Res Venue',
      name_ar: 'مطعم حجوزاتي',
      timezone: 'Africa/Cairo',
    });
    // `starts_at` is the absolute instant; `time` and `date` are the venue's
    // wall clock. A client that derived the second from the first plus a
    // guessed zone would be 2–3 hours out in Cairo.
    expect(row.starts_at).toMatch(/Z$/);
    expect(row.time).toMatch(/^\d{2}:\d{2}$/);
    expect(row.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('rejects a status it does not know, rather than silently defaulting', async () => {
    const res = await request(http as never)
      .get('/v1/reservations?status=whenever')
      .set(...auth(mine.token))
      .expect(400);
    expect(res.body.error.code).toBe('invalid_query_param');
  });

  it('orders upcoming soonest-first and past most-recent-first', async () => {
    const later = await seedReservation({
      userId: mine.id,
      startsAt: new Date(Date.now() + 9 * 86_400_000),
      status: 'confirmed',
      code: `LTR${suffix.slice(-5)}`,
    });

    const upcoming = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);
    const ids = (upcoming.body as { id: string }[]).map((r) => r.id);
    expect(ids.indexOf(upcomingId)).toBeLessThan(ids.indexOf(later));

    const past = await request(http as never)
      .get('/v1/reservations?status=past')
      .set(...auth(mine.token))
      .expect(200);
    const times = (past.body as { starts_at: string }[]).map((r) => Date.parse(r.starts_at));
    expect(times).toEqual([...times].sort((a, b) => b - a));
  });
});

describe('GET /v1/reservations/:id', () => {
  it('requires an account', async () => {
    await request(http as never).get(`/v1/reservations/${upcomingId}`).expect(401);
  });

  it('returns the diner\'s own reservation in full', async () => {
    const res = await request(http as never)
      .get(`/v1/reservations/${upcomingId}`)
      .set(...auth(mine.token))
      .expect(200);

    expect(res.body).toMatchObject({ id: upcomingId, status: 'confirmed', party_size: 2 });
    expect(res.body.code).toBeTruthy();
    expect(res.body.restaurant.name_ar).toBe('مطعم حجوزاتي');
  });

  // ── the negative case, which is the reason this file exists ────────────

  it('ANOTHER USER\'S RESERVATION IS 404, NOT 403', async () => {
    // 403 would confirm the row exists. Reservation ids are UUIDs, but the
    // difference between "no such reservation" and "not yours" is exactly what
    // an oracle needs — and unlike a venue slug there is no legitimate reason
    // for anyone to probe for one.
    const res = await request(http as never)
      .get(`/v1/reservations/${upcomingId}`)
      .set(...auth(theirs.token))
      .expect(404);

    expect(res.body.error.code).toBe('reservation_not_found');
  });

  it('and an id that exists for nobody answers identically', async () => {
    // The two must be indistinguishable, or the 404 is decorative: an
    // attacker who can tell "yours-but-404" from "nobody's-404" has the oracle
    // back.
    const notMine = await request(http as never)
      .get(`/v1/reservations/${upcomingId}`)
      .set(...auth(theirs.token))
      .expect(404);

    const nonexistent = await request(http as never)
      .get(`/v1/reservations/${randomUUID()}`)
      .set(...auth(theirs.token))
      .expect(404);

    expect(nonexistent.body.error.code).toBe(notMine.body.error.code);
    expect(Object.keys(nonexistent.body.error).sort())
      .toEqual(Object.keys(notMine.body.error).sort());
  });

  it('a malformed id is a 400, not a 500', async () => {
    await request(http as never)
      .get('/v1/reservations/not-a-uuid')
      .set(...auth(mine.token))
      .expect(400);
  });
});

// ────────────────────────────────── the cancellation the diner did not make ──

describe('a booking the RESTAURANT cancelled does not silently vanish', () => {
  /**
   * THE WORST EXPERIENCE THIS PRODUCT CAN PRODUCE.
   *
   * A diner who cancels knows they cancelled. A diner whose venue cancels does
   * not — and if the reservation simply leaves their upcoming list, they turn
   * up to a restaurant that is not expecting them, in front of their guests.
   * They blame SAHRA, and they are right to.
   *
   * It is produced by a `WHERE status IN ('confirmed', ...)` clause that looks
   * entirely reasonable, which is why it needs a test rather than care.
   */
  let venueCancelled = '';

  beforeAll(async () => {
    venueCancelled = await seedReservation({
      userId: mine.id,
      startsAt: new Date(Date.now() + 4 * 86_400_000),
      status: 'cancelled_by_restaurant',
      code: `VCX${suffix.slice(-5)}`,
    });
    await prisma.$executeRaw`
      UPDATE reservations
         SET cancelled_at = now(), cancel_reason = 'Kitchen flood'
       WHERE id = ${venueCancelled}::uuid`;
  });

  it('STAYS in upcoming, unlike one the diner cancelled', async () => {
    const res = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);

    const ids = (res.body as { id: string }[]).map((r) => r.id);
    expect(ids).toContain(venueCancelled);
    // The contrast is the whole point: same list, same date range, opposite
    // treatment, decided by WHO cancelled.
    expect(ids).not.toContain(cancelledId);
  });

  it('says who cancelled, when, and why — without the client parsing a status', async () => {
    const res = await request(http as never)
      .get(`/v1/reservations/${venueCancelled}`)
      .set(...auth(mine.token))
      .expect(200);

    expect(res.body.cancelled_by).toBe('restaurant');
    expect(res.body.cancel_reason).toBe('Kitchen flood');
    expect(res.body.cancelled_at).toMatch(/Z$/);
    expect(res.body.needs_acknowledgement).toBe(true);
  });

  it('a diner-cancelled one reports `user`, and needs no acknowledgement', async () => {
    const res = await request(http as never)
      .get(`/v1/reservations/${cancelledId}`)
      .set(...auth(mine.token))
      .expect(200);

    expect(res.body.cancelled_by).toBe('user');
    expect(res.body.needs_acknowledgement).toBe(false);
  });

  it('STAYS EVEN AFTER THE DATE PASSES — it leaves when seen, not when stale', async () => {
    // The diner who opens the app three days late is exactly the person who
    // most needs telling. A date comparison would have hidden it from them
    // precisely because they were slow.
    const past = new Date(Date.now() - 2 * 86_400_000);
    await prisma.$executeRaw`
      UPDATE reservations SET starts_at = ${past} WHERE id = ${venueCancelled}::uuid`;

    const res = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);

    expect((res.body as { id: string }[]).map((r) => r.id)).toContain(venueCancelled);
  });

  it('leaves upcoming once acknowledged, and appears in past', async () => {
    await request(http as never)
      .post(`/v1/reservations/${venueCancelled}/acknowledge-cancellation`)
      .set(...auth(mine.token))
      .expect(204);

    const upcoming = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);
    expect((upcoming.body as { id: string }[]).map((r) => r.id)).not.toContain(venueCancelled);

    const past = await request(http as never)
      .get('/v1/reservations?status=past')
      .set(...auth(mine.token))
      .expect(200);
    expect((past.body as { id: string }[]).map((r) => r.id)).toContain(venueCancelled);
  });

  it('acknowledging twice does not move the timestamp', async () => {
    const before = await prisma.$queryRaw<{ cancellation_seen_at: Date }[]>`
      SELECT cancellation_seen_at FROM reservations WHERE id = ${venueCancelled}::uuid`;

    await request(http as never)
      .post(`/v1/reservations/${venueCancelled}/acknowledge-cancellation`)
      .set(...auth(mine.token))
      .expect(204);

    const after = await prisma.$queryRaw<{ cancellation_seen_at: Date }[]>`
      SELECT cancellation_seen_at FROM reservations WHERE id = ${venueCancelled}::uuid`;

    expect(after[0].cancellation_seen_at.getTime())
      .toBe(before[0].cancellation_seen_at.getTime());
  });

  it('ANOTHER DINER CANNOT ACKNOWLEDGE IT AWAY', async () => {
    // Otherwise the notice could be cleared by anyone who guessed the id, and
    // the diner would never see it — the original failure, restored through a
    // new door.
    const other = await seedReservation({
      userId: mine.id,
      startsAt: new Date(Date.now() + 6 * 86_400_000),
      status: 'cancelled_by_restaurant',
      code: `VCY${suffix.slice(-5)}`,
    });

    const res = await request(http as never)
      .post(`/v1/reservations/${other}/acknowledge-cancellation`)
      .set(...auth(theirs.token))
      .expect(404);
    expect(res.body.error.code).toBe('reservation_not_found');

    // …and it is still waiting for the diner it belongs to.
    const mineList = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);
    expect((mineList.body as { id: string }[]).map((r) => r.id)).toContain(other);
  });
});

describe('a booking made through the API belongs to the diner who made it', () => {
  /**
   * FOUND BY AN END-TO-END JOURNEY, and nothing else could have found it.
   *
   * `ReservationsService.createHold` has always accepted and stored a
   * `userId`, and `confirmHold` has always checked it. The CONTROLLER never
   * passed one. So every reservation ever created through the HTTP API had
   * `user_id = NULL`, and a diner's own booking would never appear here — the
   * "my bookings" screen would be permanently empty for real bookings while
   * every unit test around it passed.
   *
   * The confirmation screen hid it, because that renders the response body
   * rather than looking the reservation up.
   */
  let venueId = '';
  let bookedId = '';

  beforeAll(async () => {
    venueId = restaurantId;
    await prisma.$executeRaw`
      INSERT INTO shifts (restaurant_id, name_en, name_ar, day_of_week,
                          opens_at, closes_at, spans_midnight,
                          default_turn_minutes, active, created_at, updated_at)
      SELECT ${venueId}::uuid, 'Dinner', 'العشاء', d,
             '18:00'::time, '23:00'::time, false,
             '{"1-2":90}'::jsonb, true, now(), now()
        FROM generate_series(0, 6) AS d`;
  });

  afterAll(async () => {
    if (bookedId) {
      await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${bookedId}::uuid`;
      await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${bookedId}::uuid`;
    }
    await prisma.$executeRaw`DELETE FROM shifts WHERE restaurant_id = ${venueId}::uuid`;
  });

  it('appears in the diner\'s own upcoming list', async () => {
    const date = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
    const slots = await request(http as never)
      .get(`/v1/restaurants/${venueId}/availability?date=${date}&party_size=2`)
      .expect(200);
    expect(slots.body.slots.length).toBeGreaterThan(0);

    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(mine.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, startsAt: slots.body.slots[0].startsAt, partySize: 2 })
      .expect(201);

    const confirmed = await request(http as never)
      .post(`/v1/reservations/holds/${hold.body.id}/confirm`)
      .set(...auth(mine.token))
      .set('idempotency-key', randomUUID())
      .send({})
      .expect(200);

    bookedId = confirmed.body.id as string;
    expect(confirmed.body.userId).toBe(mine.id);

    const list = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(mine.token))
      .expect(200);

    expect((list.body as { id: string }[]).map((r) => r.id)).toContain(bookedId);
  }, 60_000);

  it('and a GUEST CANNOT BOOK AT ALL — C-1.6', async () => {
    // Browsing is open; the wall is at the booking action. Asserted on the
    // AVAILABILITY call too, because a wall placed one step too early would
    // stop a guest seeing whether it is even worth signing up.
    const date = new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10);
    const slots = await request(http as never)
      .get(`/v1/restaurants/${venueId}/availability?date=${date}&party_size=2`)
      .expect(200); // ← no token, and that is correct

    await request(http as never)
      .post('/v1/reservations/holds')
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, startsAt: slots.body.slots[0].startsAt, partySize: 2 })
      .expect(401);
  }, 60_000);

  it('a guest cannot confirm either — a guessed hold id commits nothing', async () => {
    await request(http as never)
      .post(`/v1/reservations/holds/${randomUUID()}/confirm`)
      .set('idempotency-key', randomUUID())
      .send({})
      .expect(401);
  }, 60_000);

  it('and browsing stays open — search and venue detail need no token', async () => {
    // The half of C-1.6 that must NOT change. A guest has to be able to see
    // what they would be signing up for.
    await request(http as never).get(`/v1/restaurants/${venueId}`).expect(200);
    await request(http as never).get('/v1/restaurants/search?q=my').expect((r) => {
      if (r.status === 401) throw new Error('search now requires a token — the wall moved');
    });
  }, 60_000);
});
