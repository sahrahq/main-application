/**
 * CANCEL-1 — a restaurant cancels a booking, end to end.
 *
 * WRITTEN BEFORE THE IMPLEMENTATION. `POST /owner/reservations/:id/cancel`
 * does not exist, and doc 06 §4 has no cancel row at all.
 *
 * WHY THIS FILE MATTERS MORE THAN ITS ASSERTION COUNT:
 *
 * The whole acknowledgement model — a migration, a partial index, a dedicated
 * endpoint, six tests — was built for `cancelled_by_restaurant`, a status
 * NOTHING COULD SET. It was correct machinery that had never once run from its
 * actual cause. That is the failure class this project keeps meeting: a guard
 * that has never been seen to fire, a test that passes without touching a
 * socket, an analyzer green over a hole.
 *
 * So the last describe here is one continuous journey rather than a set of
 * unit checks, and it is the point of the file: venue cancels → the table is
 * FREE AGAIN (proved against the availability endpoint, not by reading the
 * trigger) → the diner sees it marked cancelled-by-restaurant with the reason
 * → they acknowledge → it moves to past.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { PUSH_DELIVERY } from '../src/modules/notifications/notification.ports';
import { LoggingPushDelivery } from '../src/modules/notifications/delivery/logging-push.delivery';
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

/** The venue whose booking gets cancelled, and its owner. */
let venue = { id: '', ownerUserId: '', ownerId: '', token: '' };
/** A DIFFERENT venue with a different owner — the negative case. */
let other = { id: '', ownerUserId: '', ownerId: '', token: '' };
/** The diner. */
let diner = { id: '', token: '' };

let tableId = '';

/** Tomorrow at 19:00 Cairo = 16:00Z. One slot, one table, so it is provable. */
const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
})();
const SLOT_UTC = `${DATE}T16:00:00.000Z`;

const auth = (token: string): [string, string] => ['Authorization', `Bearer ${token}`];

async function signUp(phone: string, name: string): Promise<{ id: string; token: string }> {
  const reg = await request(http as never)
    .post('/v1/auth/register')
    .send({ phone, fullName: name })
    .expect(201);
  const code = delivery.sent.filter((m) => m.phone === phone).at(-1)!.code;
  // See the note in my-reservations.e2e-spec: challenge handle, discriminated
  // response.
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: reg.body.challengeId, code })
    .expect(200);
  return { id: reg.body.userId as string, token: pair.body.tokens.accessToken as string };
}

async function makeVenue(
  label: string,
  phone: string,
): Promise<{ id: string; ownerUserId: string; ownerId: string; token: string }> {
  const account = await signUp(phone, `${label} Owner`);

  const owner = await prisma.restaurantOwner.create({
    data: { userId: account.id, businessName: `${label} Co`, verificationStatus: 'verified' },
  });

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             slot_interval_min, created_at, updated_at)
    VALUES (${owner.id}::uuid, ${`${label.toLowerCase()}-${suffix}`},
            ${`${label} Venue`}, 'مطعم', ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', 60, now(), now())
    RETURNING id`;

  return { id: rows[0].id, ownerUserId: account.id, ownerId: owner.id, token: account.token };
}

beforeAll(async () => {
  await prisma.$connect();
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    // ── THE STUB CARRIER, DELIBERATELY, AND THIS SUITE FOUND OUT WHY ──────
    //
    // On 2026-08-10 the FCM adapter was bound and this suite failed: "delivery
    // is attempted" registered a handset with a FAKE token, and real FCM
    // rejected it, so `sent_at` stayed null.
    //
    // The test was right to fail and its assertion was right to change — but
    // what it OWNS is `NotificationsService`'s bookkeeping: does a registered
    // handset cause a send, and is the outcome recorded? That does not need
    // Google. Left on the real adapter, this suite would make a network call to
    // FCM on every run, fail in CI with no egress, and start depending on a
    // credential to test a cancellation.
    //
    // Whether FCM itself works is proved where it belongs:
    // `fcm-push.delivery.spec.ts` for every branch, and a one-off probe against
    // the real project recorded in `2026-08-10-fcm-stage-2.md`.
    .overrideProvider(PUSH_DELIVERY)
    .useValue(new LoggingPushDelivery('test'))
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();

  venue = await makeVenue('Cancelling', `+2081${suffix}`);
  other = await makeVenue('Bystander', `+2082${suffix}`);
  diner = await signUp(`+2083${suffix}`, 'Nour Hassan');

  // ONE table, so "the slot is free again" is unambiguous.
  const t = await prisma.table.create({
    data: { restaurantId: venue.id, name: 'ONLY', minCapacity: 1, maxCapacity: 4 },
  });
  tableId = t.id;

  // Dinner every day, 18:00–23:00 Cairo.
  for (let day = 0; day < 7; day++) {
    await prisma.$executeRaw`
      INSERT INTO shifts (restaurant_id, name_en, name_ar, day_of_week,
                          opens_at, closes_at, spans_midnight,
                          default_turn_minutes, active, created_at, updated_at)
      VALUES (${venue.id}::uuid, 'Dinner', 'العشاء', ${day},
              '18:00'::time, '23:00'::time, false,
              '{"1-2":90}'::jsonb, true, now(), now())`;
  }
}, 150_000);

afterAll(async () => {
  if (app) await app.close();
  for (const id of [venue.id, other.id].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id IN
      (SELECT id FROM reservations WHERE restaurant_id = ${id}::uuid)`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${id}::uuid`;
  }
  for (const id of [venue.ownerId, other.ownerId].filter(Boolean)) {
    await prisma.restaurantOwner.delete({ where: { id } }).catch(() => undefined);
  }
  for (const id of [venue.ownerUserId, other.ownerUserId, diner.id].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

/** Book the one table at SLOT_UTC, as the diner. Returns the reservation id. */
async function bookTheOnlyTable(): Promise<string> {
  const hold = await request(http as never)
    .post('/v1/reservations/holds')
    .set(...auth(diner.token))
    .set('idempotency-key', randomUUID())
    .send({ restaurantId: venue.id, startsAt: SLOT_UTC, partySize: 2 })
    .expect(201);

  const confirmed = await request(http as never)
    .post(`/v1/reservations/holds/${hold.body.id}/confirm`)
    .set(...auth(diner.token))
    .set('idempotency-key', randomUUID())
    .send({})
    .expect(200);

  return confirmed.body.id as string;
}

/** Is SLOT_UTC offered by the availability endpoint right now? */
async function slotIsOffered(): Promise<boolean> {
  const res = await request(http as never)
    .get(`/v1/restaurants/${venue.id}/availability?date=${DATE}&party_size=2`)
    .expect(200);
  return (res.body.slots as { startsAt: string }[]).some((s) => s.startsAt === SLOT_UTC);
}

describe('who may cancel', () => {
  let reservationId = '';

  beforeAll(async () => {
    reservationId = await bookTheOnlyTable();
  });

  afterAll(async () => {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${reservationId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${reservationId}::uuid`;
  });

  it('an anonymous caller cannot', async () => {
    await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .send({ reason: 'Kitchen flood' })
      .expect(401);
  });

  it('THE DINER WHO HOLDS IT CANNOT — this is not the diner-cancel route', async () => {
    // Diner cancellation is C-3.5 with its own policy, refund rules and
    // no-show accounting. Letting it in here would record the wrong actor on
    // the row, and the whole acknowledgement model keys off that actor.
    const res = await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(diner.token))
      .send({ reason: 'Changed my mind' })
      .expect(403);
    expect(res.body.error.code).toBe('not_an_owner');
  });

  it("STAFF OF A DIFFERENT VENUE CANNOT, and get a stranger's answer", async () => {
    // The negative case that matters. An owner who could cancel by id would be
    // able to sabotage a competitor's book, and a DISTINGUISHABLE refusal would
    // let them enumerate the platform's reservations besides.
    const res = await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(other.token))
      .send({ reason: 'Not mine to cancel' })
      .expect(404);
    expect(res.body.error.code).toBe('reservation_not_found');
  });

  it('and an id that exists for nobody answers IDENTICALLY', async () => {
    // Without this the 404 above is theatre: an owner who can tell
    // "someone-else's-404" from "no-such-404" has the oracle back.
    const notMine = await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(other.token))
      .send({ reason: 'A valid reason, long enough to pass validation' })
      .expect(404);

    const nonexistent = await request(http as never)
      .post(`/v1/owner/reservations/${randomUUID()}/cancel`)
      .set(...auth(other.token))
      .send({ reason: 'A valid reason, long enough to pass validation' })
      .expect(404);

    expect(nonexistent.body.error.code).toBe(notMine.body.error.code);
    expect(Object.keys(nonexistent.body.error).sort())
      .toEqual(Object.keys(notMine.body.error).sort());
  });
});

describe('the reason is required', () => {
  let reservationId = '';

  beforeAll(async () => {
    reservationId = await bookTheOnlyTable();
  });

  afterAll(async () => {
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${reservationId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${reservationId}::uuid`;
  });

  it('rejects a cancellation with no reason', async () => {
    // A cancellation with no explanation is what the diner ends up staring at,
    // and "cancelled" on its own is worse than a phone call. doc 06 §4 has no
    // cancel row at all, so there is nothing to contradict.
    const res = await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(venue.token))
      .send({})
      .expect(400);
    expect(res.body.error.code).toBe('validation_failed');
  });

  it('rejects a blank or whitespace reason', async () => {
    await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: '   ' })
      .expect(400);
  });
});

describe('cancelling twice, or cancelling something settled', () => {
  it('a second cancel does not double-apply', async () => {
    const id = await bookTheOnlyTable();

    const first = await request(http as never)
      .post(`/v1/owner/reservations/${id}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Kitchen flood' })
      .expect(200);

    const second = await request(http as never)
      .post(`/v1/owner/reservations/${id}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Kitchen flood again' })
      .expect(409);
    expect(second.body.error.code).toBe('invalid_status_transition');

    // The first cancellation's record is untouched — a failed second attempt
    // must not overwrite the reason the diner is about to read.
    const row = await prisma.reservation.findUniqueOrThrow({ where: { id } });
    expect(row.cancelReason).toBe('Kitchen flood');
    expect(row.cancelledAt?.toISOString()).toBe(first.body.cancelled_at);

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
  });

  it('a COMPLETED reservation cannot be cancelled', async () => {
    const id = await bookTheOnlyTable();
    await prisma.$executeRaw`
      UPDATE reservations SET status = 'completed' WHERE id = ${id}::uuid`;

    const res = await request(http as never)
      .post(`/v1/owner/reservations/${id}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Too late' })
      .expect(409);
    expect(res.body.error.code).toBe('invalid_status_transition');

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${id}::uuid`;
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// THE JOURNEY. The first time this feature runs from its actual cause.
// ─────────────────────────────────────────────────────────────────────────────

describe('venue cancels → table freed → diner told → diner acknowledges', () => {
  let reservationId = '';

  afterAll(async () => {
    if (!reservationId) return;
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${reservationId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${reservationId}::uuid`;
  });

  it('1. the slot is free, and the diner books the only table', async () => {
    expect(await slotIsOffered()).toBe(true);
    reservationId = await bookTheOnlyTable();
  });

  it('2. the slot is now GONE from availability — one table, one booking', async () => {
    // Establishes the baseline the release is measured against. Without this,
    // step 5 could pass because the slot was never blocked in the first place.
    expect(await slotIsOffered()).toBe(false);
  });

  it("3. it is in the venue's book", async () => {
    const book = await request(http as never)
      .get(`/v1/owner/restaurants/${venue.id}/reservations?date=${DATE}`)
      .set(...auth(venue.token))
      .expect(200);

    expect((book.body.reservations as { id: string }[]).map((r) => r.id)).toContain(reservationId);
  });

  it('4. the venue cancels it, with a reason', async () => {
    const res = await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Burst pipe in the kitchen' })
      .expect(200);

    expect(res.body.status).toBe('cancelled_by_restaurant');
    expect(res.body.cancel_reason).toBe('Burst pipe in the kitchen');
  });

  it('5. THE TABLE IS FREE AGAIN — proved against the availability endpoint', async () => {
    // NOT by reading the trigger. `sahra_resv_propagate` flips
    // reservation_tables.active off for any status outside
    // held|pending|confirmed|seated, which SHOULD release the exclusion slot —
    // but "should" is what this whole exercise is about. The availability
    // endpoint is what a diner actually asks, so it is what gets asked here.
    expect(await slotIsOffered()).toBe(true);
  });

  it('6. and somebody else can really book it', async () => {
    // The strongest form of "free": not just offered, but takeable. An
    // EXCLUDE-constraint row left behind would let step 5 pass and this fail.
    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(diner.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venue.id, startsAt: SLOT_UTC, partySize: 2 })
      .expect(201);

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${hold.body.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${hold.body.id}::uuid`;
  });

  it("7. it has LEFT the venue's book", async () => {
    const book = await request(http as never)
      .get(`/v1/owner/restaurants/${venue.id}/reservations?date=${DATE}`)
      .set(...auth(venue.token))
      .expect(200);

    const rows = book.body.reservations as { id: string; status: string }[];
    const still = rows.find((r) => r.id === reservationId);
    // Either absent, or present and plainly marked — never present as live.
    if (still) expect(still.status).toBe('cancelled_by_restaurant');
  });

  it('8. THE DINER SEES IT, in upcoming, with who cancelled and why', async () => {
    const res = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(diner.token))
      .expect(200);

    const row = (res.body as Record<string, unknown>[]).find((r) => r.id === reservationId);
    expect(row).toBeDefined();
    expect(row!.cancelled_by).toBe('restaurant');
    expect(row!.cancel_reason).toBe('Burst pipe in the kitchen');
    expect(row!.needs_acknowledgement).toBe(true);
  });

  it('9. the diner acknowledges', async () => {
    await request(http as never)
      .post(`/v1/reservations/${reservationId}/acknowledge-cancellation`)
      .set(...auth(diner.token))
      .expect(204);
  });

  it('10. and it moves to past', async () => {
    const upcoming = await request(http as never)
      .get('/v1/reservations?status=upcoming')
      .set(...auth(diner.token))
      .expect(200);
    expect((upcoming.body as { id: string }[]).map((r) => r.id)).not.toContain(reservationId);

    const past = await request(http as never)
      .get('/v1/reservations?status=past')
      .set(...auth(diner.token))
      .expect(200);
    const row = (past.body as Record<string, unknown>[]).find((r) => r.id === reservationId);
    expect(row).toBeDefined();
    expect(row!.needs_acknowledgement).toBe(false);
    // The reason survives acknowledgement — a diner looking back at what
    // happened should still find it.
    expect(row!.cancel_reason).toBe('Burst pipe in the kitchen');
  });
});

// ─────────────────────────────────────────────── NOTIFY-1 Stage 1, end to end ──

describe('a cancellation produces a notification record', () => {
  /**
   * THE FIRST REAL TRIGGER. NOTIFY-1 Stage 1 exists so that this event has
   * somewhere to go — and it is wired to CANCEL-1 rather than to a synthetic
   * event precisely because the acknowledgement model already made the mistake
   * of shipping machinery for a cause that could not occur.
   *
   * Delivery is the logging stub for now (Stage 2 swaps in FCM), so what is
   * asserted here is the RECORD: we owed this diner this message. That claim
   * has to survive every delivery failure, which is why the two are separate
   * tables and separate steps.
   */
  let reservationId = '';

  afterAll(async () => {
    if (!reservationId) return;
    await prisma.$executeRaw`DELETE FROM notifications WHERE user_id = ${diner.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM devices WHERE user_id = ${diner.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${reservationId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${reservationId}::uuid`;
  });

  it('records one, addressed to the diner, carrying who and why', async () => {
    reservationId = await bookTheOnlyTable();

    await request(http as never)
      .post(`/v1/owner/reservations/${reservationId}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Power cut on the whole street' })
      .expect(200);

    const rows = await prisma.notification.findMany({
      where: { userId: diner.id, type: 'reservation_cancelled_by_venue' },
      orderBy: { createdAt: 'desc' },
    });

    expect(rows.length).toBeGreaterThanOrEqual(1);
    const data = rows[0].data as Record<string, string>;
    // `reservation_id`, not `reservationId`.
    //
    // This was the only notification type in the system, so its payload could
    // spell things however it liked. Group G gave the client a renderer that
    // routes on one key across six types, and snake_case won — it is what every
    // other payload in this API uses. This assertion is what caught the rename
    // reaching a caller that had not been updated.
    expect(data.reservation_id).toBe(reservationId);
    expect(data.reservationId).toBeUndefined();
    expect(data.reason).toBe('Power cut on the whole street');
    expect(data.venue).toBe('Cancelling Venue');
    // Venue wall clock, so a lock screen never shows a UTC hour.
    expect(data.time).toMatch(/^\d{2}:\d{2}$/);
  }, 90_000);

  it('says WHY it could not be delivered, rather than leaving a silent gap', async () => {
    // The diner has no registered handset. That is not an error — it is the
    // case the in-app centre exists for — but "we never sent this, and here is
    // the reason" is a very different record from an empty `sent_at` nobody
    // can explain six weeks later.
    const row = await prisma.notification.findFirstOrThrow({
      where: { userId: diner.id, type: 'reservation_cancelled_by_venue' },
      orderBy: { createdAt: 'desc' },
    });
    expect(row.sentAt).toBeNull();
    expect(row.deliveryError).toBe('no_registered_device');
  }, 60_000);

  it('and once a handset is registered, delivery is attempted', async () => {
    await request(http as never)
      .post('/v1/devices')
      .set(...auth(diner.token))
      .send({ token: `tok-${suffix}-a`, platform: 'android', locale: 'ar' })
      .expect(201);

    const second = await bookTheOnlyTable();
    await request(http as never)
      .post(`/v1/owner/reservations/${second}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Private event booked the room' })
      .expect(200);

    const row = await prisma.notification.findFirstOrThrow({
      where: { userId: diner.id },
      orderBy: { createdAt: 'desc' },
    });
    // `sent_at` means "at least one device was reached". With a stub carrier
    // that is unconditionally true, which is exactly as much as this assertion
    // claims: the SERVICE looked up the handset, called the carrier, and
    // recorded the outcome.
    expect(row.sentAt).not.toBeNull();
    expect(row.deliveryError).toBeNull();

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${second}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${second}::uuid`;
  }, 90_000);

  it('A SIGNED-OUT HANDSET STOPS RECEIVING — the privacy case', async () => {
    // A push token left attached to a signed-out user sends that person's
    // reservations to whoever holds the handset next. On a shared or resold
    // phone that is a privacy incident, not an annoyance.
    await request(http as never)
      .delete('/v1/devices')
      .set(...auth(diner.token))
      .send({ token: `tok-${suffix}-a` })
      .expect(204);

    const third = await bookTheOnlyTable();
    await request(http as never)
      .post(`/v1/owner/reservations/${third}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'Chef is unwell' })
      .expect(200);

    const row = await prisma.notification.findFirstOrThrow({
      where: { userId: diner.id },
      orderBy: { createdAt: 'desc' },
    });
    // The RECORD is still written — they are still owed the message.
    expect(row.data).toMatchObject({ reason: 'Chef is unwell' });
    // Nothing was pushed, because there is nowhere live to push to.
    expect(row.deliveryError).toBe('no_registered_device');

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${third}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${third}::uuid`;
  }, 90_000);

  it('a WALK-IN cancellation notifies nobody, and does not fail trying', async () => {
    // No account, so there is nobody to tell — the venue took that booking at
    // the podium and can say so at the podium. What matters is that the
    // cancellation still succeeds.
    const before = await prisma.notification.count();

    const walkIn = await request(http as never)
      .post(`/v1/owner/restaurants/${venue.id}/reservations`)
      .set(...auth(venue.token))
      .set('idempotency-key', randomUUID())
      .send({ partySize: 2, guestName: 'Podium Guest' })
      .expect(201);

    await request(http as never)
      .post(`/v1/owner/reservations/${walkIn.body.id}/cancel`)
      .set(...auth(venue.token))
      .send({ reason: 'They left before being seated' })
      .expect(200);

    expect(await prisma.notification.count()).toBe(before);

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${walkIn.body.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE id = ${walkIn.body.id}::uuid`;
  }, 90_000);
});
