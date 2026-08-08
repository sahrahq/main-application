/**
 * GROUP A — the three things a diner can do to something they already own:
 * change it, call it off, and correct their own name.
 *
 *   C-3.4  `PATCH /reservations/:id`        — modify time / party size
 *   C-3.5  `POST  /reservations/:id/cancel` — cancel, as the DINER
 *          `PATCH /auth/me`                 — profile edit
 *
 * WRITTEN BEFORE THE IMPLEMENTATION. None of the three routes exists.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY MODIFY IS THE DANGEROUS ONE, AND WHAT THIS FILE IS REALLY GUARDING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * A modify is a booking write. It goes through the same three layers as a new
 * hold (doc 05 §3) or it is a double-booking waiting to happen — and it has one
 * failure mode a new hold does not:
 *
 *   **A reservation can collide with itself.** Moving 19:00 → 20:00 with a
 *   90-minute turn means the new window overlaps the old one, on the same
 *   table, held by the same row. Release-then-reallocate inside the lock is the
 *   only order that works; anything else fails a move that should obviously
 *   succeed, and the EXCLUDE constraint is what says so.
 *
 * That case is `2.` below and it is the reason this file exists. It cannot be
 * caught by reading the code, because the code looks correct in either order.
 *
 * Everything here is proved against the AVAILABILITY endpoint rather than by
 * inspecting `reservation_tables` — same rule as CANCEL-1. A trigger that is
 * believed to fire and a trigger that is seen to fire are different things.
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
let ownerUserId = '';
let ownerId = '';
let tableId = '';

/** The diner who owns everything here. */
let mine = { id: '', token: '' };
/** Somebody else. Their token must open nothing of ours. */
let theirs = { id: '', token: '' };

/**
 * Tomorrow, Cairo. ONE table and a 90-minute turn, so every claim about
 * availability is unambiguous — there is nothing else it could have been.
 *
 * Cairo runs UTC+3 in August, so 19:00 local is 16:00Z.
 */
const dayAfter = (n: number): string => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};

const DATE = dayAfter(1);
const AT_19 = `${DATE}T16:00:00.000Z`;
const AT_20 = `${DATE}T17:00:00.000Z`;
const AT_22 = `${DATE}T19:00:00.000Z`;

/**
 * A SECOND DAY for the "target slot is somebody else's" case.
 *
 * With one table and a 90-minute turn, every hour on day one overlaps its
 * neighbour, so a blocker seeded near the reservation under test collides with
 * it before the test can run — the EXCLUDE constraint refuses the setup rather
 * than the subject. Giving that case its own day keeps the obstacle and the
 * subject from fighting over the same table for reasons the test is not about.
 */
const DATE2 = dayAfter(2);
const D2_AT_19 = `${DATE2}T16:00:00.000Z`;
const D2_AT_21 = `${DATE2}T18:00:00.000Z`;

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

/** Book the one table, through the real engine. Returns the reservation id. */
async function book(startsAt: string, partySize = 2): Promise<string> {
  const hold = await request(http as never)
    .post('/v1/reservations/holds')
    .set(...auth(mine.token))
    .set('idempotency-key', randomUUID())
    .send({ restaurantId: venueId, startsAt, partySize })
    .expect(201);

  const confirmed = await request(http as never)
    .post(`/v1/reservations/holds/${hold.body.id}/confirm`)
    .set(...auth(mine.token))
    .set('idempotency-key', randomUUID())
    .send({})
    .expect(200);

  return confirmed.body.id as string;
}

/**
 * Drop a reservation straight into the table, bypassing the engine.
 *
 * Only ever used to OCCUPY inventory for a negative case — never to set up
 * something the engine is then asked to prove. A seeded row that the engine
 * did not create is a fine obstacle and a terrible subject.
 */
async function seedBlocker(startsAt: string, userId: string): Promise<string> {
  const start = new Date(startsAt);
  const end = new Date(start.getTime() + 90 * 60_000);
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (code, restaurant_id, user_id, party_size,
                              starts_at, ends_at, status, source,
                              created_at, updated_at)
    VALUES (${'BLK' + suffix.slice(-5)}, ${venueId}::uuid, ${userId}::uuid, 2,
            ${start}, ${end}, 'confirmed'::reservation_status, 'app', now(), now())
    RETURNING id`;
  const id = rows[0].id;
  await prisma.$executeRaw`
    INSERT INTO reservation_tables (reservation_id, table_id, during)
    VALUES (${id}::uuid, ${tableId}::uuid, tstzrange(${start}, ${end}, '[)'))`;
  return id;
}

/** Is [slot] offered by the availability endpoint right now? */
async function slotIsOffered(slot: string, partySize = 2): Promise<boolean> {
  const date = slot.slice(0, 10);
  const res = await request(http as never)
    .get(`/v1/restaurants/${venueId}/availability?date=${date}&party_size=${partySize}`)
    .expect(200);
  return (res.body.slots as { startsAt: string }[]).some((s) => s.startsAt === slot);
}

/**
 * The error envelope minus its per-request id.
 *
 * `request_id` is unique by design — it is how a diner's screenshot is traced
 * to a log line — so two genuinely identical refusals differ in exactly one
 * field. Comparing the rest is the real assertion: what an attacker can learn
 * from the answer, rather than what a log correlator can.
 */
function refusal(body: { error: Record<string, unknown> }): Record<string, unknown> {
  const { request_id: _ignored, ...rest } = body.error;
  return rest;
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

  const account = await signUp(`+2071${suffix}`, 'Group A Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Group A Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             slot_interval_min, created_at, updated_at)
    VALUES (${ownerId}::uuid, ${'group-a-' + suffix}, 'Group A Venue', 'مطعم أ',
            ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', 60, now(), now())
    RETURNING id`;
  venueId = rows[0].id;

  const t = await prisma.table.create({
    data: { restaurantId: venueId, name: 'ONLY', minCapacity: 1, maxCapacity: 4 },
  });
  tableId = t.id;

  for (let day = 0; day < 7; day++) {
    await prisma.$executeRaw`
      INSERT INTO shifts (restaurant_id, name_en, name_ar, day_of_week,
                          opens_at, closes_at, spans_midnight,
                          default_turn_minutes, active, created_at, updated_at)
      VALUES (${venueId}::uuid, 'Dinner', 'العشاء', ${day},
              '18:00'::time, '23:30'::time, false,
              '{"1-2":90,"3-4":90}'::jsonb, true, now(), now())`;
  }

  mine = await signUp(`+2072${suffix}`, 'Nour Hassan');
  theirs = await signUp(`+2073${suffix}`, 'Somebody Else');
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  if (venueId) {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id IN
      (SELECT id FROM reservations WHERE restaurant_id = ${venueId}::uuid)`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${venueId}::uuid`;
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
//  MODIFY — one continuous journey, because the interesting failures are
//  transitions between states rather than states.
// ═══════════════════════════════════════════════════════════════════════════
describe('PATCH /v1/reservations/:id — the diner moves their own booking', () => {
  let id = '';

  beforeAll(async () => {
    id = await book(AT_19);
  });

  afterAll(async () => {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
  });

  it('0. an anonymous caller cannot', async () => {
    await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .send({ startsAt: AT_20 })
      .expect(401);
  });

  it("0b. ANOTHER DINER'S TOKEN GETS A STRANGER'S ANSWER — 404, never 403", async () => {
    // Identical to the answer for an id that exists for nobody. A 403 would
    // confirm the row exists, and reservation ids are guessable in bulk.
    const notMine = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(theirs.token))
      .send({ startsAt: AT_20 })
      .expect(404);

    const nothing = await request(http as never)
      .patch(`/v1/reservations/${randomUUID()}`)
      .set(...auth(theirs.token))
      .send({ startsAt: AT_20 })
      .expect(404);

    expect(refusal(notMine.body)).toEqual(refusal(nothing.body));
  });

  it('0c. a body that changes nothing is refused, not silently accepted', async () => {
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({})
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');
  });

  it('1. the starting position — 19:00 is taken, AND SO IS 20:00, by us', async () => {
    // One table, 90-minute turn: the 19:00 booking occupies 16:00–17:30Z, so
    // 20:00 (17:00–18:30Z) is refused to a stranger too. The only thing
    // standing in the way of 20:00 is the diner's own reservation.
    //
    // ASSERTED RATHER THAN GLOSSED OVER, because it is the setup for the next
    // test: the move in `2.` is into a slot that availability legitimately
    // says is unavailable, and it must still succeed.
    expect(await slotIsOffered(AT_19)).toBe(false);
    expect(await slotIsOffered(AT_20)).toBe(false);
  });

  it('2. MOVES ONTO ITS OWN OVERLAPPING WINDOW — 19:00 → 20:00, 90-minute turn', async () => {
    // THE CASE THIS FILE EXISTS FOR.
    //
    // 19:00 occupies 16:00–17:30Z. 20:00 wants 17:00–18:30Z. They overlap by
    // half an hour on the only table in the venue, and the row holding the
    // first one is the row being moved. Unless its allocation is released
    // BEFORE the re-check runs — inside the same lock — the reservation
    // collides with itself and the EXCLUDE constraint rejects a move that is
    // obviously legal.
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ startsAt: AT_20 })
      .expect(200);

    expect(res.body.starts_at).toBe(AT_20);
    expect(res.body.time).toBe('20:00');
    expect(res.body.status).toBe('confirmed');
  });

  it('3. and again, this time well clear of where it started', async () => {
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ startsAt: AT_22 })
      .expect(200);
    expect(res.body.starts_at).toBe(AT_22);
    expect(res.body.time).toBe('22:00');
  });

  it('4. THE ORIGINAL SLOT IS FREE AGAIN — proved against availability', async () => {
    // The one claim that cannot be made by reading the code. The old
    // allocation is gone from `reservation_tables`, so a different diner can
    // now book the table the first version of this reservation was holding.
    expect(await slotIsOffered(AT_19)).toBe(true);
  });

  it('5. and the new one is genuinely held', async () => {
    expect(await slotIsOffered(AT_22)).toBe(false);
  });

  it('6. REPLAYING THE IDENTICAL PATCH is a no-op, not a second move', async () => {
    // This is why the route carries no Idempotency-Key. A PATCH that names
    // absolute values is idempotent by construction: replaying it lands on the
    // same window, on the same terms. If that were ever to stop being true the
    // route would need a key and a column to store it in.
    const first = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);

    await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ startsAt: AT_22 })
      .expect(200);

    const after = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);

    expect(after.body.starts_at).toBe(first.body.starts_at);
    expect(after.body.party_size).toBe(first.body.party_size);
    expect(after.body.code).toBe(first.body.code);
  });

  it('7. changes the party size on the spot', async () => {
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 4 })
      .expect(200);

    expect(res.body.party_size).toBe(4);
    // Unchanged — a PATCH touches what it names and nothing else.
    expect(res.body.starts_at).toBe(AT_22);
  });

  it('8. a party the venue cannot seat is refused, and nothing changes', async () => {
    // The only table seats 4.
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 9 })
      .expect(409);
    expect(res.body.error.code).toBe('slot_taken');

    const after = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);
    // A REFUSED MOVE MUST NOT COST THE DINER THE BOOKING THEY HAD. If the
    // allocation were released before the new one was proven, a rejected
    // modify would leave a reservation with no table under it — confirmed on
    // paper, seated nowhere.
    expect(after.body.party_size).toBe(4);
    expect(after.body.starts_at).toBe(AT_22);
    expect(await slotIsOffered(AT_22)).toBe(false);
  });

  it('9. an out-of-range party size is a 400, not a 409', async () => {
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 99 })
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');
  });

});

describe('PATCH /v1/reservations/:id — when the target slot is somebody else\'s', () => {
  let id = '';
  let blockerId = '';

  beforeAll(async () => {
    // Its own day, and its own reservation. See the note on DATE2.
    id = await book(D2_AT_19);
    blockerId = await seedBlocker(D2_AT_21, theirs.id);
  });

  afterAll(async () => {
    for (const r of [id, blockerId].filter(Boolean)) {
      await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${r}::uuid`;
      await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${r}::uuid`;
    }
  });

  it('moving into it is refused with slot_taken', async () => {
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ startsAt: D2_AT_21 })
      .expect(409);
    expect(res.body.error.code).toBe('slot_taken');
  });

  it("the other diner's booking is untouched", async () => {
    const rows = await prisma.$queryRaw<{ status: string; starts_at: Date }[]>`
      SELECT status::text AS status, starts_at FROM reservations WHERE id = ${blockerId}::uuid`;
    expect(rows[0].status).toBe('confirmed');
    expect(rows[0].starts_at.toISOString()).toBe(D2_AT_21);
  });

  it('AND THE REFUSED DINER STILL HAS THE TABLE THEY CAME IN WITH', async () => {
    // The rollback, observed from outside. `modifyOwn` deletes the old
    // allocation before it knows whether the new one is available, so a
    // refused move is only safe because the whole thing is one transaction.
    // If it were not, this diner would now hold a confirmed reservation with
    // no table under it — and nothing in the response would have said so.
    const after = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);
    expect(after.body.starts_at).toBe(D2_AT_19);
    expect(await slotIsOffered(D2_AT_19)).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  THE PICKER — without this, modify is a button that mostly refuses.
// ═══════════════════════════════════════════════════════════════════════════
describe('GET /v1/reservations/:id/available-slots', () => {
  let id = '';

  beforeAll(async () => {
    id = await book(AT_19);
  });

  afterAll(async () => {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
  });

  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .get(`/v1/reservations/${id}/available-slots?date=${DATE}`)
      .expect(401);
  });

  it("another diner gets a stranger's answer", async () => {
    await request(http as never)
      .get(`/v1/reservations/${id}/available-slots?date=${DATE}`)
      .set(...auth(theirs.token))
      .expect(404);
  });

  it('OFFERS THE SLOTS THE BOOKING ITSELF IS BLOCKING — the whole point', async () => {
    // The public grid hides 19:00 (this booking) and 20:00 (overlapped by it).
    // Both are legal destinations for a move, and `modifyOwn` proves it above
    // by making exactly that move. A picker built on the public grid would
    // offer neither, so the diner would find "change booking" opens a screen
    // with their own times missing from it.
    expect(await slotIsOffered(AT_19)).toBe(false);
    expect(await slotIsOffered(AT_20)).toBe(false);

    const res = await request(http as never)
      .get(`/v1/reservations/${id}/available-slots?date=${DATE}`)
      .set(...auth(mine.token))
      .expect(200);

    const offered = (res.body.slots as { startsAt: string }[]).map((s) => s.startsAt);
    expect(offered).toContain(AT_19);
    expect(offered).toContain(AT_20);
  });

  it('still hides what somebody ELSE is holding', async () => {
    // The exclusion is one reservation wide. A diner who could see through
    // every booking would have a live occupancy map of the restaurant.
    const blocker = await seedBlocker(D2_AT_21, theirs.id);
    try {
      const res = await request(http as never)
        .get(`/v1/reservations/${id}/available-slots?date=${DATE2}`)
        .set(...auth(mine.token))
        .expect(200);

      const offered = (res.body.slots as { startsAt: string }[]).map((s) => s.startsAt);
      expect(offered).not.toContain(D2_AT_21);
    } finally {
      await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${blocker}::uuid`;
      await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${blocker}::uuid`;
    }
  });

  it("defaults to the booking's own party size", async () => {
    const res = await request(http as never)
      .get(`/v1/reservations/${id}/available-slots?date=${DATE}`)
      .set(...auth(mine.token))
      .expect(200);
    expect(res.body.partySize).toBe(2);
  });

  it('refuses a malformed date', async () => {
    const res = await request(http as never)
      .get(`/v1/reservations/${id}/available-slots?date=nonsense`)
      .set(...auth(mine.token))
      .expect(400);
    expect(res.body.error.code).toBe('invalid_date');
  });
});

describe('PATCH /v1/reservations/:id — what cannot be moved', () => {
  const ids: string[] = [];

  afterAll(async () => {
    for (const id of ids) {
      await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
      await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
    }
  });

  /** A row in an arbitrary state, seeded because the engine cannot produce it. */
  async function seedMine(status: string, startsAt: Date): Promise<string> {
    const end = new Date(startsAt.getTime() + 90 * 60_000);
    const rows = await prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO reservations (code, restaurant_id, user_id, party_size,
                                starts_at, ends_at, status, source,
                                created_at, updated_at)
      VALUES (${'ST' + Math.random().toString(36).slice(2, 8).toUpperCase()},
              ${venueId}::uuid, ${mine.id}::uuid, 2, ${startsAt}, ${end},
              ${status}::reservation_status, 'app', now(), now())
      RETURNING id`;
    ids.push(rows[0].id);
    return rows[0].id;
  }

  it('a cancelled booking cannot be moved', async () => {
    const id = await seedMine('cancelled_by_user', new Date(Date.now() + 3 * 86_400_000));
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 3 })
      .expect(409);
    expect(res.body.error.code).toBe('invalid_status_transition');
  });

  it('a HOLD cannot be moved — it is not a booking yet', async () => {
    const id = await seedMine('held', new Date(Date.now() + 3 * 86_400_000));
    await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 3 })
      .expect(409);
  });

  it('a booking whose time has already passed cannot be moved', async () => {
    const id = await seedMine('confirmed', new Date(Date.now() - 3 * 86_400_000));
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ partySize: 3 })
      .expect(409);
    expect(res.body.error.code).toBe('reservation_not_modifiable');
  });

  it('a booking cannot be moved into the past', async () => {
    const id = await seedMine('confirmed', new Date(Date.now() + 3 * 86_400_000));
    const res = await request(http as never)
      .patch(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .send({ startsAt: new Date(Date.now() - 86_400_000).toISOString() })
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  CANCEL — the diner's own door, and a different actor from the venue's.
// ═══════════════════════════════════════════════════════════════════════════
describe('POST /v1/reservations/:id/cancel — the diner calls it off', () => {
  let id = '';

  beforeAll(async () => {
    id = await book(AT_19);
  });

  afterAll(async () => {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
  });

  it('0. an anonymous caller cannot', async () => {
    await request(http as never)
      .post(`/v1/reservations/${id}/cancel`)
      .send({})
      .expect(401);
  });

  it("0b. another diner gets a stranger's answer", async () => {
    const notMine = await request(http as never)
      .post(`/v1/reservations/${id}/cancel`)
      .set(...auth(theirs.token))
      .send({})
      .expect(404);
    const nothing = await request(http as never)
      .post(`/v1/reservations/${randomUUID()}/cancel`)
      .set(...auth(theirs.token))
      .send({})
      .expect(404);
    expect(refusal(notMine.body)).toEqual(refusal(nothing.body));
  });

  it('1. the slot is taken before we start', async () => {
    expect(await slotIsOffered(AT_19)).toBe(false);
  });

  it('2. A REASON IS OPTIONAL — unlike the venue, the diner owes no explanation', async () => {
    // The venue MUST give a reason: the diner is about to read it, and "your
    // table is gone" with no cause is the message that loses the customer.
    // Nobody reads the diner's reason with the same stakes, and demanding one
    // to release a table would make cancelling harder than not showing up.
    const res = await request(http as never)
      .post(`/v1/reservations/${id}/cancel`)
      .set(...auth(mine.token))
      .send({})
      .expect(200);

    expect(res.body.status).toBe('cancelled_by_user');
    expect(res.body.cancelled_by).toBe('user');
    expect(res.body.cancelled_at).not.toBeNull();
  });

  it('3. THE TABLE IS FREE AGAIN — proved against availability', async () => {
    expect(await slotIsOffered(AT_19)).toBe(true);
  });

  it('4. it does NOT need acknowledging — the diner did this themselves', async () => {
    // `needs_acknowledgement` exists so a diner cannot miss a cancellation the
    // RESTAURANT made. Raising it for their own tap would put a notice in
    // front of somebody about a thing they just did.
    const res = await request(http as never)
      .get(`/v1/reservations/${id}`)
      .set(...auth(mine.token))
      .expect(200);
    expect(res.body.needs_acknowledgement).toBe(false);
    expect(res.body.cancelled_by).toBe('user');
  });

  it('5. cancelling twice is a 409, not a second cancellation', async () => {
    const res = await request(http as never)
      .post(`/v1/reservations/${id}/cancel`)
      .set(...auth(mine.token))
      .send({})
      .expect(409);
    expect(res.body.error.code).toBe('invalid_status_transition');
  });

  it('6. it moves to the past list', async () => {
    const res = await request(http as never)
      .get('/v1/reservations?status=past')
      .set(...auth(mine.token))
      .expect(200);
    expect((res.body as { id: string }[]).map((r) => r.id)).toContain(id);
  });

  it('7. a reason IS recorded when one is given', async () => {
    const second = await book(AT_20);
    const res = await request(http as never)
      .post(`/v1/reservations/${second}/cancel`)
      .set(...auth(mine.token))
      .send({ reason: 'Plans changed' })
      .expect(200);
    expect(res.body.cancel_reason).toBe('Plans changed');

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${second}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${second}::uuid`;
  });

  it('8. THE VENUE ROUTE STILL REFUSES THE DINER — the two doors stay separate', async () => {
    // Guarded in `venue-cancellation.e2e-spec` too. Repeated here because the
    // temptation once a diner-cancel exists is to collapse them into one
    // handler with a role branch, and the actor recorded on the row is what
    // the entire acknowledgement model keys off.
    const third = await book(AT_22);
    const res = await request(http as never)
      .post(`/v1/owner/reservations/${third}/cancel`)
      .set(...auth(mine.token))
      .send({ reason: 'Changed my mind' })
      .expect(403);
    expect(res.body.error.code).toBe('not_an_owner');

    await request(http as never)
      .post(`/v1/reservations/${third}/cancel`)
      .set(...auth(mine.token))
      .send({})
      .expect(200);

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${third}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${third}::uuid`;
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  PROFILE — and the field that is deliberately NOT here.
// ═══════════════════════════════════════════════════════════════════════════
describe('PATCH /v1/auth/me — the diner corrects their own name', () => {
  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .patch('/v1/auth/me')
      .send({ fullName: 'Anyone' })
      .expect(401);
  });

  it('changes the name, and GET /auth/me agrees immediately', async () => {
    const res = await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({ fullName: 'Nour H. Hassan' })
      .expect(200);
    expect(res.body.fullName).toBe('Nour H. Hassan');

    const me = await request(http as never)
      .get('/v1/auth/me')
      .set(...auth(mine.token))
      .expect(200);
    expect(me.body.fullName).toBe('Nour H. Hassan');
  });

  it('changes the locale', async () => {
    const res = await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({ locale: 'en' })
      .expect(200);
    expect(res.body.locale).toBe('en');
  });

  it('REFUSES AN EMAIL — 400, and does not quietly drop it', async () => {
    // `users.email` is reachable from here the moment this endpoint accepts
    // one, and step 3 of the email chain — the verification flow that decides
    // what an unverified address may be used for — is PAUSED. Writing an
    // unverified address now would be the Decision 6 hole in a new place:
    // I could type your address on my account, and any confirmation you were
    // ever sent would arrive at a stranger's inbox.
    //
    // Refused rather than ignored, deliberately, and the same shape as
    // `complete-registration` refusing an extra `phone`. A field that is
    // accepted and discarded looks exactly like a field that works.
    const res = await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({ fullName: 'Nour H. Hassan', email: 'nour@example.com' })
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');

    const me = await request(http as never)
      .get('/v1/auth/me')
      .set(...auth(mine.token))
      .expect(200);
    expect(me.body.email).toBeNull();
  });

  it('refuses a phone — the number is proved by OTP, never typed into a profile', async () => {
    await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({ phone: '+201111111111' })
      .expect(400);
  });

  it('refuses a body that changes nothing', async () => {
    const res = await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({})
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');
  });

  it('refuses a name that is not a name', async () => {
    await request(http as never)
      .patch('/v1/auth/me')
      .set(...auth(mine.token))
      .send({ fullName: 'N' })
      .expect(400);
  });

  it('CANNOT reach another account — there is no id in the route at all', async () => {
    // The safest shape available: the subject is the token, so there is no
    // parameter to tamper with. Asserted so nobody later "generalises" it to
    // `PATCH /users/:id` and reintroduces the question.
    const me = await request(http as never)
      .get('/v1/auth/me')
      .set(...auth(theirs.token))
      .expect(200);
    expect(me.body.fullName).toBe('Somebody Else');
  });
});
