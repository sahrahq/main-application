/**
 * C-4.7 — the in-app notification centre, and C-3.9's reminder records.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHAT THIS FILE IS REALLY GUARDING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `read_at` had existed for a week with nothing reading it, and
 * `idx_notif_user_unread` was deliberately not built until something did. This
 * is that something, so three of the assertions below are about properties the
 * column exists FOR rather than about the endpoint:
 *
 *   - a second read does not RE-STAMP `read_at`. The column answers "when did
 *     they first see this?", which is the input to the whole cancellation
 *     acknowledgement model. Re-stamping on every open would leave it answering
 *     "when did they last scroll past it", and nothing would ever fail.
 *   - the unread count is of the HISTORY, not of the page. A count taken over
 *     `items` reads zero for a diner with more notifications than one page,
 *     which is the diner most likely to have unread ones.
 *   - marking read is scoped to the caller IN THE UPDATE, so a diner cannot
 *     silence a stranger's badge with a guessed id.
 *
 * ── AND THE DEDUPE INDEX, PROVED RATHER THAN ASSUMED ─────────────────────
 *
 * Group G's sweepers are at-least-once by construction. `idx_notifications_dedupe`
 * is what makes that safe, and a partial unique index that quietly stopped
 * being unique would show up as diners told the same thing three times — in
 * production, months later. So it is exercised directly: the same key twice,
 * one row.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { ReservationReminderService } from '../src/modules/reservations/reminders/reservation-reminder.service';
import { NOTIFICATION_TYPES } from '../src/modules/notifications/notification.ports';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;
let notifications: NotificationsService;
let reminders: ReservationReminderService;

const suffix = Date.now().toString().slice(-9);

let venueId = '';
let ownerUserId = '';
let ownerId = '';

let me = { id: '', token: '' };
let other = { id: '', token: '' };

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

/** A confirmed booking [hours] from now, written straight to the table. */
async function bookingIn(userId: string, hours: number): Promise<string> {
  const startsAt = new Date(Date.now() + hours * 3_600_000);
  const endsAt = new Date(startsAt.getTime() + 90 * 60_000);
  const code = `N${Date.now().toString().slice(-6)}${Math.floor(Math.random() * 9)}`;
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO reservations (code, restaurant_id, user_id, party_size,
                              starts_at, ends_at, status, source, created_at, updated_at)
    VALUES (${code}, ${venueId}::uuid, ${userId}::uuid, 2,
            ${startsAt}, ${endsAt}, 'confirmed'::reservation_status, 'app', now(), now())
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
  notifications = app.get(NotificationsService);
  reminders = app.get(ReservationReminderService);

  const account = await signUp(`+2081${suffix}`, 'Centre Owner');
  ownerUserId = account.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Centre Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone, created_at, updated_at)
    VALUES (${ownerId}::uuid, ${`centre-venue-${suffix}`}, 'Centre Venue', 'مطعم المركز',
            ARRAY['egyptian'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', now(), now())
    RETURNING id`;
  venueId = rows[0].id;

  me = await signUp(`+2082${suffix}`, 'Yara Diner');
  other = await signUp(`+2083${suffix}`, 'Tarek Diner');
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  if (venueId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants  WHERE id            = ${venueId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [me.id, other.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM notifications  WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('GET /v1/notifications', () => {
  it('an anonymous caller cannot', async () => {
    await request(http as never).get('/v1/notifications').expect(401);
  });

  it('a diner with none gets an empty list and a zero — not a 404', async () => {
    // The empty state is a real state, and the app draws a screen for it. An
    // error here would make "you have no notifications" indistinguishable from
    // "something broke".
    const res = await request(http as never)
      .get('/v1/notifications')
      .set(...auth(me.token))
      .expect(200);
    expect(res.body.items).toEqual([]);
    expect(res.body.unread_count).toBe(0);
  });

  it('lists what the diner is owed, newest first', async () => {
    await notifications.notify({
      userId: me.id,
      type: 'reservation_confirmed',
      data: { reservation_id: randomUUID(), venue: 'Centre Venue', code: 'ABC123' },
    });
    await notifications.notify({
      userId: me.id,
      type: 'reservation_cancelled_by_venue',
      data: { reservation_id: randomUUID(), venue: 'Centre Venue', reason: 'Burst pipe' },
    });

    const res = await request(http as never)
      .get('/v1/notifications')
      .set(...auth(me.token))
      .expect(200);

    expect(res.body.items).toHaveLength(2);
    expect(res.body.items[0].type).toBe('reservation_cancelled_by_venue');
    expect(res.body.items[0].read_at).toBeNull();
    expect(res.body.unread_count).toBe(2);
  });

  it('shows nobody else\'s', async () => {
    await notifications.notify({
      userId: other.id,
      type: 'reservation_confirmed',
      data: { reservation_id: randomUUID() },
    });
    const res = await request(http as never)
      .get('/v1/notifications')
      .set(...auth(me.token))
      .expect(200);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.unread_count).toBe(2);
  });

  it('carries the deep-link target the client routes on', async () => {
    const res = await request(http as never)
      .get('/v1/notifications')
      .set(...auth(me.token))
      .expect(200);
    for (const item of res.body.items as { data: Record<string, string> }[]) {
      expect(item.data.reservation_id).toBeTruthy();
      // snake_case, everywhere. It was `reservationId` on the one type that
      // existed before Group G, and the centre routes on one spelling.
      expect(Object.keys(item.data).every((k) => !/[A-Z]/.test(k))).toBe(true);
    }
  });
});

describe('POST /v1/notifications/read', () => {
  it('marks everything, and the badge clears', async () => {
    const res = await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({})
      .expect(200);
    expect(res.body.marked).toBe(2);
    expect(res.body.unread_count).toBe(0);
  });

  it('a replay changes nothing and reports zero', async () => {
    // Idempotent by construction — `read_at IS NULL` is in the predicate. This
    // is the argument recorded in `idempotency-contract.spec.ts` for why the
    // route carries no Idempotency-Key.
    const res = await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({})
      .expect(200);
    expect(res.body.marked).toBe(0);
    expect(res.body.unread_count).toBe(0);
  });

  it('DOES NOT RE-STAMP read_at on a later read', async () => {
    // The property the column exists for. Wind it back a day, mark again, and
    // it must not move — otherwise "when did they first see the cancellation?"
    // silently becomes "when did they last open the app".
    const before = new Date(Date.now() - 86_400_000);
    await prisma.$executeRaw`
      UPDATE notifications SET read_at = ${before} WHERE user_id = ${me.id}::uuid`;

    await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({})
      .expect(200);

    const rows = await prisma.notification.findMany({ where: { userId: me.id } });
    expect(rows).not.toHaveLength(0);
    for (const row of rows) {
      expect(row.readAt!.getTime()).toBeCloseTo(before.getTime(), -3);
    }
  });

  it('cannot mark somebody else\'s read', async () => {
    // `userId` is in the WHERE clause, not checked before it. Without it, a
    // guessed id would silence a stranger's badge — and they would never know,
    // because the notification would simply look read.
    const theirs = await prisma.notification.findFirst({ where: { userId: other.id } });
    expect(theirs).not.toBeNull();

    const res = await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({ ids: [theirs!.id] })
      .expect(200);
    expect(res.body.marked).toBe(0);

    const after = await prisma.notification.findUnique({ where: { id: theirs!.id } });
    expect(after?.readAt).toBeNull();
  });

  it('marks a named subset and leaves the rest', async () => {
    await prisma.$executeRaw`
      UPDATE notifications SET read_at = NULL WHERE user_id = ${me.id}::uuid`;
    const mine = await prisma.notification.findMany({
      where: { userId: me.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(mine.length).toBeGreaterThanOrEqual(2);

    const res = await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({ ids: [mine[0].id] })
      .expect(200);

    expect(res.body.marked).toBe(1);
    expect(res.body.unread_count).toBe(mine.length - 1);
  });

  it('refuses ids that are not uuids', async () => {
    await request(http as never)
      .post('/v1/notifications/read')
      .set(...auth(me.token))
      .send({ ids: ['not-a-uuid'] })
      .expect(400);
  });
});

describe('the unread count is of the history, not of the page', () => {
  it('a diner with more notifications than one page still sees them all counted', async () => {
    // The page cap is 50. A count taken over `items` would read 50 here, and
    // the badge would be wrong for exactly the diner most likely to look at it.
    await prisma.$executeRaw`
      UPDATE notifications SET read_at = NULL WHERE user_id = ${me.id}::uuid`;
    const already = await prisma.notification.count({ where: { userId: me.id } });

    const rows = Array.from({ length: 55 }, () => ({
      userId: me.id,
      type: 'reservation_confirmed',
      data: { reservation_id: randomUUID() },
    }));
    await prisma.notification.createMany({ data: rows });

    const res = await request(http as never)
      .get('/v1/notifications')
      .set(...auth(me.token))
      .expect(200);

    expect(res.body.items).toHaveLength(50);
    expect(res.body.unread_count).toBe(already + 55);
  });
});

describe('idx_notifications_dedupe', () => {
  it('the same key twice writes one row, and the second call is silent', async () => {
    const key = `test_dedupe:${randomUUID()}`;
    const firstId = await notifications.notify({
      userId: other.id,
      type: 'reservation_reminder_24h',
      data: { reservation_id: randomUUID() },
      dedupeKey: key,
    });
    const secondId = await notifications.notify({
      userId: other.id,
      type: 'reservation_reminder_24h',
      data: { reservation_id: randomUUID() },
      dedupeKey: key,
    });

    expect(firstId).toBeTruthy();
    // Null, not an error, and not a second row. A sweeper that ran twice must
    // not look like a failure to its caller.
    expect(secondId).toBeNull();
    expect(await prisma.notification.count({ where: { dedupeKey: key } })).toBe(1);
  });

  it('AND IT IS PARTIAL — two key-less notifications both land', async () => {
    // The whole reason the index has a WHERE clause. A total unique index on a
    // nullable column behaves differently per database, and if this one ever
    // became total, every event-driven notification after the first would be
    // silently dropped for the entire platform.
    const before = await prisma.notification.count({ where: { userId: other.id } });
    await notifications.notify({
      userId: other.id,
      type: 'reservation_cancelled_by_venue',
      data: { reservation_id: randomUUID(), reason: 'one' },
    });
    await notifications.notify({
      userId: other.id,
      type: 'reservation_cancelled_by_venue',
      data: { reservation_id: randomUUID(), reason: 'two' },
    });
    expect(await prisma.notification.count({ where: { userId: other.id } })).toBe(before + 2);
  });
});

describe('C-3.9 reminders — the record half', () => {
  /**
   * COUNTED PER DINER, NOT FROM `sweep()`'s RETURN VALUE.
   *
   * The sweeper is global by design — it reminds everybody, which is the whole
   * point — and these suites run against a shared database alongside other
   * fixtures. `expect(await reminders.sweep()).toBe(0)` failed here with a 4:
   * four reservations belonging to other suites happened to sit inside the 23h
   * window. That was the test being wrong, not the sweeper.
   *
   * So the integer that has to read zero is a count of THIS diner's reminders.
   * It is still an integer and it still has to be exact.
   */
  const remindersFor = (userId: string) =>
    prisma.notification.count({
      where: { userId, type: { in: ['reservation_reminder_24h', 'reservation_reminder_2h'] } },
    });

  it('records nothing for a booking that is not yet due one', async () => {
    // The zero that stops every assertion below from passing on a sweeper that
    // reminds everybody about everything.
    const before = await remindersFor(other.id);
    await bookingIn(other.id, 40);
    await reminders.sweep();
    expect(await remindersFor(other.id)).toBe(before);
  });

  it('records the 24h reminder inside its window', async () => {
    const before = await remindersFor(other.id);
    const id = await bookingIn(other.id, 23.5);
    await reminders.sweep();
    expect(await remindersFor(other.id)).toBe(before + 1);

    const note = await prisma.notification.findFirst({
      where: { dedupeKey: `reminder_24h:${id}` },
    });
    expect(note).not.toBeNull();
    expect(note!.type).toBe('reservation_reminder_24h');
    expect((note!.data as Record<string, string>).reservation_id).toBe(id);
  });

  it('and does not record it twice, however often the sweeper runs', async () => {
    const before = await remindersFor(other.id);
    await reminders.sweep();
    await reminders.sweep();
    expect(await remindersFor(other.id)).toBe(before);
  });

  it('AND THE SECOND SWEEP DOES NOT EVEN ATTEMPT THE INSERT', async () => {
    // The `NOT EXISTS` predicate, asserted rather than assumed. Without it the
    // index still holds the guarantee, but every tick inside the hour-wide
    // window raises a unique violation that Prisma logs as an ERROR — sixty an
    // hour per booking, all of them describing correct behaviour. An operator
    // who learns to ignore those stops seeing the real ones.
    //
    // `sweep()` counts only rows it WROTE, so a dedupe hit and a filtered row
    // both report zero. The difference is observable here instead: a filtered
    // row leaves `notify` uncalled.
    const spy = jest.spyOn(notifications, 'notify');
    await reminders.sweep();
    const attemptedOurs = spy.mock.calls.filter(
      (c) => (c[0].dedupeKey ?? '').startsWith('reminder_'),
    );
    spy.mockRestore();
    expect(attemptedOurs).toEqual([]);
  });

  it('records the 2h reminder as a separate notification', async () => {
    const id = await bookingIn(other.id, 1.5);
    await reminders.sweep();
    const note = await prisma.notification.findFirst({
      where: { dedupeKey: `reminder_2h:${id}` },
    });
    expect(note?.type).toBe('reservation_reminder_2h');
  });

  it("says the time on the VENUE'S clock, not UTC", async () => {
    // Cairo is UTC+2/+3. A reminder that renders the instant in UTC tells a
    // diner their 21:00 table is at 19:00, and they arrive two hours early.
    const id = await bookingIn(other.id, 23.5);
    await reminders.sweep();
    const note = await prisma.notification.findFirst({
      where: { dedupeKey: `reminder_24h:${id}` },
    });
    const data = note!.data as Record<string, string>;
    const utcHour = new Date(data.starts_at).getUTCHours();
    const localHour = Number(data.time.slice(0, 2));
    // Not asserting a fixed offset — DST moves it. Asserting they DIFFER is the
    // property: a bug here renders UTC, and UTC never differs from itself.
    expect((localHour - utcHour + 24) % 24).toBeGreaterThanOrEqual(2);
  });

  it('never reminds a cancelled booking', async () => {
    const id = await bookingIn(other.id, 23.5);
    await prisma.$executeRaw`
      UPDATE reservations SET status = 'cancelled_by_user', cancelled_at = now()
       WHERE id = ${id}::uuid`;
    await reminders.sweep();
    expect(
      await prisma.notification.findFirst({ where: { dedupeKey: `reminder_24h:${id}` } }),
    ).toBeNull();
  });

  it('never reminds a walk-in, which has no account to remind', async () => {
    const startsAt = new Date(Date.now() + 23.5 * 3_600_000);
    const code = `W${Date.now().toString().slice(-6)}1`;
    const rows = await prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO reservations (code, restaurant_id, user_id, guest_name, party_size,
                                starts_at, ends_at, status, source, created_at, updated_at)
      VALUES (${code}, ${venueId}::uuid, NULL, 'Podium Guest', 2,
              ${startsAt}, ${new Date(startsAt.getTime() + 5_400_000)},
              'confirmed'::reservation_status, 'walk_in', now(), now())
      RETURNING id`;
    // Without `user_id IS NOT NULL` in the query this throws a foreign-key
    // violation once per sweep, forever, and every later reminder in the batch
    // is lost with it.
    await expect(reminders.sweep()).resolves.toBeGreaterThanOrEqual(0);
    expect(
      await prisma.notification.findFirst({ where: { dedupeKey: `reminder_24h:${rows[0].id}` } }),
    ).toBeNull();
  });
});

describe('every notification type can actually be produced', () => {
  // A type with copy and no emitter is a string in a switch statement. This
  // does not prove each one is EMITTED — `waitlist-offer.e2e-spec.ts` and the
  // booking suites do that — but it proves each can be recorded and read back,
  // so a type that breaks the insert cannot sit undetected behind a channel
  // nobody has turned on yet.
  it.each(NOTIFICATION_TYPES)('%s records and lists', async (type) => {
    const id = await notifications.notify({
      userId: other.id,
      type,
      data: { reservation_id: randomUUID(), venue: 'Centre Venue' },
    });
    expect(id).toBeTruthy();
    const row = await prisma.notification.findUnique({ where: { id: id! } });
    expect(row?.type).toBe(type);
    // No device is registered anywhere in this suite, which is the state of the
    // whole system until Firebase exists. Recorded as a fact, not as an error.
    expect(row?.deliveryError).toBe('no_registered_device');
    expect(row?.sentAt).toBeNull();
  });
});
