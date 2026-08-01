/**
 * The PRECISE half of hold expiry — the BullMQ delayed job (doc 05 §4).
 *
 * The sweeper suite proves the backstop. This proves the primary mechanism
 * actually fires, and that its at-least-once delivery cannot damage a booking
 * that was confirmed in the meantime.
 *
 * Skips itself when Redis is unreachable (decided in global-setup), so an
 * absent server produces `skipped`, never a misleading green tick.
 */
import { PrismaClient } from '@prisma/client';
import { Queue, Worker, Job } from 'bullmq';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { ReservationsService } from '../src/modules/reservations/reservations.service';
import { HoldExpiryService } from '../src/modules/reservations/expiry/hold-expiry.service';
import { HOLD_EXPIRY_QUEUE, EXPIRE_HOLD_JOB } from '../src/modules/reservations/expiry/hold-expiry.constants';

const REDIS_UP = process.env.REDIS_AVAILABLE === '1';
const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;
const reservations = new ReservationsService(p);
const expiry = new HoldExpiryService(p);

const QUEUE = `${HOLD_EXPIRY_QUEUE}-test`;
let queue: Queue | null = null;
let worker: Worker | null = null;

let ownerUserId: string;
let ownerId: string;
let restaurantId: string;

const DATE = (() => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 2); // +2 so it cannot collide with the sweeper suite
  return d.toISOString().slice(0, 10);
})();
const at = (hhmm: string) => new Date(`${DATE}T${hhmm}:00.000Z`);

const statusOf = async (id: string): Promise<string> =>
  (await prisma.reservation.findUniqueOrThrow({ where: { id }, select: { status: true } })).status;

/** Poll until the predicate holds — the worker is asynchronous. */
async function until(fn: () => Promise<boolean>, timeoutMs = 15_000): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await fn()) return true;
    await new Promise((r) => setTimeout(r, 250));
  }
  return false;
}

const describeIf = REDIS_UP ? describe : describe.skip;

beforeAll(async () => {
  await prisma.$connect();
  if (!REDIS_UP) return;

  const connection = { url: REDIS_URL, maxRetriesPerRequest: null };
  queue = new Queue(QUEUE, { connection });
  await queue.obliterate({ force: true }).catch(() => undefined);

  // Mirrors HoldExpiryProcessor: same guarded expireOne, same job name.
  worker = new Worker(
    QUEUE,
    async (job: Job<{ reservationId: string }>) => {
      if (job.name !== EXPIRE_HOLD_JOB) return;
      await expiry.expireOne(job.data.reservationId);
    },
    { connection },
  );
  await worker.waitUntilReady();

  const stamp = Date.now().toString().slice(-8);
  ownerUserId = randomUUID();
  await prisma.user.create({
    data: { id: ownerUserId, phone: `+2019${stamp}`, fullName: 'Queue Owner', status: 'active' },
  });
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Queue Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (
      owner_id, slug, name_en, name_ar, cuisines, location,
      status, city, timezone, slot_interval_min, created_at, updated_at
    ) VALUES (
      ${ownerId}::uuid, ${'queue-test-' + Date.now()}, 'Queue Test', 'اختبار الطابور',
      ARRAY['levantine']::text[],
      ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
      'active', 'Cairo', 'UTC', 30, now(), now()
    ) RETURNING id`;
  restaurantId = rows[0].id;

  await prisma.table.create({
    data: { restaurantId, name: 'Q1', minCapacity: 1, maxCapacity: 4, zone: 'indoor' },
  });
}, 60_000);

afterAll(async () => {
  if (worker) await worker.close();
  if (queue) {
    await queue.obliterate({ force: true }).catch(() => undefined);
    await queue.close();
  }
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM tables      WHERE restaurant_id = ${restaurantId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id            = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  if (ownerUserId) await prisma.user.delete({ where: { id: ownerUserId } }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

describeIf('BullMQ delayed job (doc 05 §4 primary)', () => {
  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM reservations WHERE restaurant_id = ${restaurantId}::uuid`;
  });

  it('expires the hold when the job fires', async () => {
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('19:00'), idempotencyKey: randomUUID(),
    });
    // Age it first: expireOne is guarded on hold_expires_at < now(), so a job
    // that fires early must legitimately do nothing.
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 second'
      WHERE id = ${hold.id}::uuid`;

    await queue!.add(EXPIRE_HOLD_JOB, { reservationId: hold.id }, { delay: 100 });

    expect(await until(async () => (await statusOf(hold.id)) === 'expired')).toBe(true);

    const live = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM reservation_tables
      WHERE reservation_id = ${hold.id}::uuid AND active`;
    expect(Number(live[0].n)).toBe(0);
  }, 60_000);

  it('a job that fires EARLY does not expire a hold that is still live', async () => {
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('20:00'), idempotencyKey: randomUUID(),
    });
    // hold_expires_at is five minutes out; the job runs now.
    await queue!.add(EXPIRE_HOLD_JOB, { reservationId: hold.id }, { delay: 100 });

    await new Promise((r) => setTimeout(r, 2000));
    expect(await statusOf(hold.id)).toBe('held');
  }, 60_000);

  it('at-least-once delivery is safe: a duplicate job cannot expire a CONFIRMED booking', async () => {
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('21:00'), idempotencyKey: randomUUID(),
    });
    await reservations.confirmHold({ holdId: hold.id, idempotencyKey: randomUUID() });

    // BullMQ guarantees at-least-once, so the same job may run twice — and a
    // late one may arrive after the diner confirmed. Neither may take the
    // table away from someone who is on their way to dinner.
    await queue!.add(EXPIRE_HOLD_JOB, { reservationId: hold.id }, { delay: 50 });
    await queue!.add(EXPIRE_HOLD_JOB, { reservationId: hold.id }, { delay: 100 });

    await new Promise((r) => setTimeout(r, 2500));
    expect(await statusOf(hold.id)).toBe('confirmed');
  }, 60_000);

  it('running the same job twice is idempotent', async () => {
    const hold = await reservations.createHold({
      restaurantId, partySize: 2, startsAt: at('22:00'), idempotencyKey: randomUUID(),
    });
    await prisma.$executeRaw`
      UPDATE reservations SET hold_expires_at = now() - interval '1 second'
      WHERE id = ${hold.id}::uuid`;

    expect(await expiry.expireOne(hold.id)).toBe(true);
    // Second run matches nothing — the guard already moved the row.
    expect(await expiry.expireOne(hold.id)).toBe(false);
    expect(await statusOf(hold.id)).toBe('expired');
  }, 60_000);
});

describe('queue availability', () => {
  it('states plainly whether the BullMQ half ran', () => {
    // eslint-disable-next-line no-console
    console.log(
      REDIS_UP
        ? '  BullMQ delayed job: EXERCISED against live Redis'
        : '  BullMQ delayed job: SKIPPED — sweeper coverage alone does not prove it',
    );
    expect(typeof REDIS_UP).toBe('boolean');
  });
});
