/**
 * C-3.6 — the NOTIFY half of the waitlist, and the assertion that pins what it
 * still does not do.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE LOAD-BEARING NEGATIVE: AN OFFER WITHHOLDS NOTHING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * doc 05 §5 says the freed slot is held back from public availability during
 * the offer window, "so the waiter's 10 minutes are real". It is not. An offer
 * is a notification and a queue position, and anybody may take that table in
 * the meantime — argued in `docs/decisions/2026-08-09-group-g-split.md` §3.1,
 * because withholding properly means creating a `held` reservation from a
 * background job, which is a booking write and needs its own concurrency test
 * (CLAUDE.md rule 1).
 *
 * That is exactly the shape of thing that gets forgotten: a gap nobody can trip
 * over. So it is an assertion — `GET /availability` still lists the freed slot
 * after an offer has been made. The day withholding lands, this fails, and
 * whoever implemented it has to come and read the terms and change the
 * notification copy in the same commit. The copy is the other half: it says
 * "first come, first served", not doc 11's "claim in 10 min", and one of those
 * two sentences is a lie depending on which way this test reads.
 *
 * ── AND THE ORDINARY ONE: A JOIN WITH NO OFFER IS STILL POSSIBLE ─────────
 *
 * Every assertion below about an offer would pass vacuously against a waitlist
 * that offered nothing, if the setup silently failed to create the entry. Each
 * one therefore reads the entry's status rather than only the notification, and
 * the census test at the top proves the entry exists as `waiting` first.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { WaitlistOfferService } from '../src/modules/favorites/waitlist-offer.service';
import { HoldExpiryService } from '../src/modules/reservations/expiry/hold-expiry.service';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;
let offers: WaitlistOfferService;

const suffix = Date.now().toString().slice(-9);

let venueId = '';
let ownerUserId = '';
let ownerId = '';
let tableId = '';

let first = { id: '', token: '' };
let second = { id: '', token: '' };
let booker = { id: '', token: '' };

/** Tomorrow at 19:00 UTC — the venue is pinned to UTC so wall clock == UTC. */
const DATE = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
const SLOT = new Date(`${DATE}T19:00:00.000Z`);

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

/** Join the queue for the whole evening, through the real endpoint. */
async function join(token: string, partySize: number): Promise<string> {
  const res = await request(http as never)
    .post('/v1/waitlists')
    .set(...auth(token))
    .send({
      restaurantId: venueId,
      desiredDate: DATE,
      windowStart: new Date(`${DATE}T18:00:00.000Z`).toISOString(),
      windowEnd: new Date(`${DATE}T22:00:00.000Z`).toISOString(),
      partySize,
    })
    .expect(201);
  return res.body.id as string;
}

async function notificationsFor(userId: string, type: string) {
  return prisma.notification.findMany({
    where: { userId, type },
    orderBy: { createdAt: 'desc' },
  });
}

/** The public grid, exactly as a diner who never joined the list would see it. */
async function publicSlots(): Promise<string[]> {
  const res = await request(http as never)
    .get(`/v1/restaurants/${venueId}/availability`)
    .query({ date: DATE, party_size: 2 })
    .expect(200);
  return (res.body.slots as { startsAt: string }[]).map((s) => s.startsAt);
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
  offers = app.get(WaitlistOfferService);

  const account = await signUp(`+2074${suffix}`, 'Offer Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Offer Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  // UTC, so "19:00" means one thing throughout.
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone, created_at, updated_at)
    VALUES (${ownerId}::uuid, ${`offer-venue-${suffix}`}, 'Offer Venue', 'مطعم العرض',
            ARRAY['egyptian'], 'Cairo', 'Maadi',
            ST_SetSRID(ST_MakePoint(31.2585, 29.9602), 4326)::geography,
            'active', 'UTC', now(), now())
    RETURNING id`;
  venueId = rows[0].id;

  // ONE table, so the venue can actually be full — which is the situation a
  // waitlist exists for. A test that offers a table at a venue with spare
  // capacity is not testing the waitlist.
  const table = await prisma.table.create({
    data: {
      restaurantId: venueId,
      name: 'T1',
      zone: 'indoor',
      minCapacity: 1,
      maxCapacity: 4,
      priority: 1,
      active: true,
    },
  });
  tableId = table.id;

  await prisma.shift.create({
    data: {
      restaurantId: venueId,
      nameEn: 'Dinner',
      nameAr: 'العشاء',
      dayOfWeek: SLOT.getUTCDay(),
      opensAt: new Date('1970-01-01T17:00:00.000Z'),
      closesAt: new Date('1970-01-01T23:30:00.000Z'),
      defaultTurnMinutes: { '1-2': 90, '3-4': 105, '5+': 120 },
    },
  });

  first = await signUp(`+2075${suffix}`, 'Salma Waiting');
  second = await signUp(`+2076${suffix}`, 'Karim Waiting');
  booker = await signUp(`+2077${suffix}`, 'Hana Booking');
}, 240_000);

afterAll(async () => {
  if (app) await app.close();
  if (venueId) {
    await prisma.$executeRaw`DELETE FROM waitlists    WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables       WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM shifts       WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${venueId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [first.id, second.id, booker.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM notifications  WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('a freed table finds the person waiting for it', () => {
  let entryId = '';

  it('the setup produced a waiting entry — census', async () => {
    entryId = await join(first.token, 2);
    const row = await prisma.waitlist.findUnique({ where: { id: entryId } });
    expect(row?.status).toBe('waiting');
    expect(row?.offerExpiresAt).toBeNull();
  });

  it('offers it to the only match, and tells them', async () => {
    const offered = await offers.onSlotFreed({
      restaurantId: venueId,
      startsAt: SLOT,
      partySize: 4,
    });
    expect(offered).toBe(entryId);

    const row = await prisma.waitlist.findUnique({ where: { id: entryId } });
    expect(row?.status).toBe('offered');
    // The CHECK constraint ties these two together; asserting both is what
    // proves the write went through the intended state rather than only that
    // the status changed.
    expect(row?.offerExpiresAt).not.toBeNull();

    const notes = await notificationsFor(first.id, 'waitlist_offer');
    expect(notes).toHaveLength(1);
    const data = notes[0].data as Record<string, string>;
    expect(data.waitlist_id).toBe(entryId);
    expect(data.venue).toBe('Offer Venue');
    expect(data.time).toBe('19:00');
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE LOAD-BEARING NEGATIVE.
  //  Do not "fix" this by changing the expectation. Read
  //  `docs/decisions/2026-08-09-group-g-split.md` §3.1 first.
  // ══════════════════════════════════════════════════════════════════════
  it('AN OFFER WITHHOLDS NOTHING — the slot is still publicly bookable', async () => {
    const row = await prisma.waitlist.findUnique({ where: { id: entryId } });
    expect(row?.status).toBe('offered'); // not vacuous: there IS a live offer

    expect(await publicSlots()).toContain(SLOT.toISOString());
  });

  it('and somebody who never joined the list can take it', async () => {
    // The consequence of the line above, played out. This is the behaviour the
    // notification copy describes — "first come, first served" — and the reason
    // it must not say "claim in 10 min".
    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, partySize: 2, startsAt: SLOT.toISOString() })
      .expect(201);
    expect(hold.body.id).toBeTruthy();

    // Now it is genuinely gone, which is what makes the previous assertion a
    // statement about the OFFER rather than about an empty restaurant.
    expect(await publicSlots()).not.toContain(SLOT.toISOString());

    await prisma.$executeRaw`DELETE FROM reservation_tables WHERE reservation_id = ${hold.body.id}::uuid`;
    await prisma.$executeRaw`DELETE FROM reservations       WHERE id = ${hold.body.id}::uuid`;
  });

  it('does not offer the same entry twice while it is still offered', async () => {
    // `status = 'waiting'` in the picker is what prevents it. Without this, a
    // busy evening would overwrite one diner's offer with another and reset
    // their window silently.
    const again = await offers.onSlotFreed({
      restaurantId: venueId,
      startsAt: SLOT,
      partySize: 4,
    });
    expect(again).toBeNull();
    expect(await notificationsFor(first.id, 'waitlist_offer')).toHaveLength(1);
  });
});

describe('the match is a match, not a broadcast', () => {
  it('a party too large for the freed table is skipped', async () => {
    const big = await join(second.token, 4);
    const offered = await offers.onSlotFreed({
      restaurantId: venueId,
      startsAt: SLOT,
      // A table for two freed. The party of four cannot sit at it.
      partySize: 2,
    });
    expect(offered).toBeNull();
    expect(await notificationsFor(second.id, 'waitlist_offer')).toHaveLength(0);

    const row = await prisma.waitlist.findUnique({ where: { id: big } });
    expect(row?.status).toBe('waiting');
  });

  it('a time outside the diner\'s window is skipped', async () => {
    // They said 18:00–22:00. 23:00 is not an offer, it is a nuisance — and a
    // nuisance teaches them to ignore the next one, which is the real cost.
    const offered = await offers.onSlotFreed({
      restaurantId: venueId,
      startsAt: new Date(`${DATE}T23:30:00.000Z`),
      partySize: 4,
    });
    expect(offered).toBeNull();
  });
});

describe('a lapsed offer', () => {
  it('the sweeper does nothing when no offer has lapsed', async () => {
    // The zero that makes the next assertion mean something. Without it, a
    // sweeper that expired everything unconditionally would look identical.
    expect(await offers.expireLapsedOffers()).toBe(0);
  });

  it('returns the entry to the queue and says so', async () => {
    const entry = await prisma.waitlist.findFirst({
      where: { userId: first.id, status: 'offered' },
    });
    expect(entry).not.toBeNull();

    // Wind the window back rather than waiting ten minutes. The predicate is
    // `offer_expires_at < now()`, evaluated by Postgres, so this exercises the
    // real comparison.
    await prisma.$executeRaw`
      UPDATE waitlists SET offer_expires_at = now() - interval '1 minute'
       WHERE id = ${entry!.id}::uuid`;

    expect(await offers.expireLapsedOffers()).toBe(1);

    const after = await prisma.waitlist.findUnique({ where: { id: entry!.id } });
    // `waiting`, NOT `expired` — doc 05 §5 says expired, and that is right for
    // an EXCLUSIVE offer. Losing a race for a table nobody held is not
    // declining an offer, so the entry keeps its place. See
    // `WaitlistOfferService`'s docblock, point 2.
    expect(after?.status).toBe('waiting');
    expect(after?.offerExpiresAt).toBeNull();

    const notes = await notificationsFor(first.id, 'waitlist_offer_expired');
    expect(notes).toHaveLength(1);
  });

  it('a second sweep tells them nothing, because there is nothing new', async () => {
    expect(await offers.expireLapsedOffers()).toBe(0);
    expect(await notificationsFor(first.id, 'waitlist_offer_expired')).toHaveLength(1);
  });

  it('and the entry can be offered again — with a SECOND expiry notification', async () => {
    // The reason the dedupe key carries the offer's own timestamp rather than
    // only the entry id. Keyed on the entry alone, this diner would be told
    // once, ever, and every later lapse would be silent.
    const offered = await offers.onSlotFreed({
      restaurantId: venueId,
      startsAt: SLOT,
      partySize: 4,
    });
    expect(offered).not.toBeNull();

    await prisma.$executeRaw`
      UPDATE waitlists SET offer_expires_at = now() - interval '1 minute'
       WHERE id = ${offered}::uuid`;
    expect(await offers.expireLapsedOffers()).toBe(1);

    expect(await notificationsFor(first.id, 'waitlist_offer_expired')).toHaveLength(2);
  });
});

describe('the three paths that free a table all call it', () => {
  // Each of these is a path doc 05 marks "check waitlist", and each was silent
  // before Group G. Asserted through the real endpoints, because a hook that is
  // only ever called by a test is the defect this project keeps finding.

  it('a diner cancelling their own booking offers the table on', async () => {
    // Somebody is waiting for the whole evening.
    const waiter = await prisma.waitlist.findFirst({
      where: { userId: first.id, status: 'waiting' },
    });
    expect(waiter).not.toBeNull();

    const at = new Date(`${DATE}T20:00:00.000Z`);
    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, partySize: 2, startsAt: at.toISOString() })
      .expect(201);
    await request(http as never)
      .post(`/v1/reservations/holds/${hold.body.id}/confirm`)
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({})
      .expect(200);

    const before = (await notificationsFor(first.id, 'waitlist_offer')).length;

    await request(http as never)
      .post(`/v1/reservations/${hold.body.id}/cancel`)
      .set(...auth(booker.token))
      .send({ reason: 'Something came up' })
      .expect(200);

    expect((await notificationsFor(first.id, 'waitlist_offer')).length).toBe(before + 1);
    const after = await prisma.waitlist.findUnique({ where: { id: waiter!.id } });
    expect(after?.status).toBe('offered');
  });

  it('a venue cancelling a booking offers the table on', async () => {
    // Put the waiter back in the queue first.
    await prisma.$executeRaw`
      UPDATE waitlists SET status = 'waiting', offer_expires_at = NULL
       WHERE user_id = ${first.id}::uuid AND status = 'offered'`;

    const at = new Date(`${DATE}T21:00:00.000Z`);
    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, partySize: 2, startsAt: at.toISOString() })
      .expect(201);
    await request(http as never)
      .post(`/v1/reservations/holds/${hold.body.id}/confirm`)
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({})
      .expect(200);

    const before = (await notificationsFor(first.id, 'waitlist_offer')).length;

    await request(http as never)
      .post(`/v1/owner/reservations/${hold.body.id}/cancel`)
      .set(...auth(await ownerToken()))
      .send({ reason: 'Kitchen fire' })
      .expect(200);

    expect((await notificationsFor(first.id, 'waitlist_offer')).length).toBe(before + 1);
  });

  it('an expired hold offers the table on', async () => {
    await prisma.$executeRaw`
      UPDATE waitlists SET status = 'waiting', offer_expires_at = NULL
       WHERE user_id = ${first.id}::uuid AND status = 'offered'`;

    const at = new Date(`${DATE}T18:30:00.000Z`);
    const hold = await request(http as never)
      .post('/v1/reservations/holds')
      .set(...auth(booker.token))
      .set('idempotency-key', randomUUID())
      .send({ restaurantId: venueId, partySize: 2, startsAt: at.toISOString() })
      .expect(201);

    // Age the hold past its window, then run the real sweeper through the app's
    // own instance — not a hand-built one, so the wiring is what is tested.
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 minute'
       WHERE id = ${hold.body.id}::uuid`;

    const before = (await notificationsFor(first.id, 'waitlist_offer')).length;

    await app.get(HoldExpiryService).sweep();

    expect((await notificationsFor(first.id, 'waitlist_offer')).length).toBe(before + 1);
  });
});

/** The owner's access token, minted on demand — the owner signed up in setup. */
let cachedOwnerToken = '';
async function ownerToken(): Promise<string> {
  if (cachedOwnerToken) return cachedOwnerToken;
  const phone = `+2074${suffix}`;
  // `request-otp`, not `login` — signing in by phone alone is C-1.2, and
  // `/auth/login` is the password route this account has never had one for.
  const req = await request(http as never)
    .post('/v1/auth/request-otp')
    .send({ phone })
    .expect(202);
  const code = delivery.sent.filter((m) => m.phone === phone).at(-1)!.code;
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: req.body.challengeId, code })
    .expect(200);
  cachedOwnerToken = pair.body.tokens.accessToken as string;
  return cachedOwnerToken;
}
