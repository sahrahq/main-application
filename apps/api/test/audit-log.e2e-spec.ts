/**
 * Audit logging for admin decisions (doc 06 §5, doc 04 §2 `audit_logs`).
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — AuditService does not exist yet, and
 * `audit_logs` is not in the schema.
 *
 * doc 04 §2 calls the table "(append-only)" and "No UPDATE/DELETE grants to
 * app role". That is the property worth testing hardest: an audit trail an
 * operator can quietly edit is not an audit trail. Because the API connects
 * as the table owner, GRANTs alone would not stop us — so the constraint has
 * to be enforced by something the owner is also subject to.
 */
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../src/shared/prisma/prisma.service';
import { AdminRestaurantsService } from '../src/modules/admin/admin-restaurants.service';
import { AuditService } from '../src/shared/audit/audit.service';
import { RestaurantsService } from '../src/modules/restaurants/restaurants.service';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });
const p = prisma as unknown as PrismaService;

const audit = new AuditService(p);
const admin = new AdminRestaurantsService(p, audit);
const restaurants = new RestaurantsService(p);

let ownerUserId: string;
let ownerId: string;
let adminUserId: string;
let restaurantId: string;

interface AuditRow {
  id: bigint;
  actor_id: string | null;
  actor_role: string | null;
  action: string;
  entity_type: string;
  entity_id: string;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  ip: string | null;
  user_agent: string | null;
}

const rowsFor = (entityId: string): Promise<AuditRow[]> =>
  prisma.$queryRaw<AuditRow[]>`
    SELECT * FROM audit_logs WHERE entity_id = ${entityId}::uuid ORDER BY id ASC`;

beforeAll(async () => {
  await prisma.$connect();
  const stamp = Date.now().toString().slice(-8);

  ownerUserId = randomUUID();
  adminUserId = randomUUID();
  await prisma.user.createMany({
    data: [
      { id: ownerUserId, phone: `+2016${stamp}`, fullName: 'Audit Owner', status: 'active' },
      { id: adminUserId, phone: `+2017${stamp}`, fullName: 'Audit Admin', status: 'active' },
    ],
  });

  const role = await prisma.role.upsert({
    where: { name: 'admin' }, update: {}, create: { name: 'admin' },
  });
  await prisma.userRole.create({ data: { userId: adminUserId, roleId: role.id } });

  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Audit Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const r = await restaurants.create(ownerId, {
    nameEn: 'Audit Test Venue', nameAr: 'مطعم التدقيق', lat: 30.0622, lng: 31.2185,
  });
  restaurantId = r.id;
}, 60_000);

afterAll(async () => {
  if (restaurantId) {
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${restaurantId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  await prisma.userRole.deleteMany({ where: { userId: adminUserId } }).catch(() => undefined);
  await prisma.user.deleteMany({
    where: { id: { in: [ownerUserId, adminUserId].filter(Boolean) } },
  }).catch(() => undefined);
  await prisma.$disconnect();
}, 60_000);

describe('audit_logs — the record of who decided what (doc 04 §2)', () => {
  it('an approval writes exactly one audit row with the full transition', async () => {
    await restaurants.submitForReview(ownerId, restaurantId);

    await admin.approve({
      actorId: adminUserId,
      actorRoles: ['admin'],
      restaurantId,
      ip: '197.44.10.7',
      userAgent: 'SAHRA-Admin/1.0',
    });

    const rows = await rowsFor(restaurantId);
    expect(rows).toHaveLength(1);

    const row = rows[0];
    expect(row.action).toBe('restaurant.approve');
    expect(row.entity_type).toBe('restaurant');
    expect(row.entity_id).toBe(restaurantId);
    expect(row.actor_id).toBe(adminUserId);
    // WHICH role authorised it — 'admin' and 'support' are not interchangeable
    // when reconstructing a decision months later.
    expect(row.actor_role).toBe('admin');
    // The transition itself, both sides.
    expect(row.before).toMatchObject({ status: 'pending_review' });
    expect(row.after).toMatchObject({ status: 'active' });
    expect(row.ip).toBe('197.44.10.7');
    expect(row.user_agent).toBe('SAHRA-Admin/1.0');
  }, 60_000);

  it('a rejection records the reason the owner was given', async () => {
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'pending_review' WHERE id = ${restaurantId}::uuid`;

    await admin.reject({
      actorId: adminUserId,
      actorRoles: ['admin'],
      restaurantId,
      reason: 'Menu prices missing Arabic.',
    });

    const rows = await rowsFor(restaurantId);
    const rejection = rows.find((r) => r.action === 'restaurant.reject');
    expect(rejection).toBeDefined();
    expect(rejection!.after).toMatchObject({ status: 'draft', reason: 'Menu prices missing Arabic.' });
  }, 60_000);

  it('a DENIED attempt changes nothing and leaves no decision row', async () => {
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'pending_review' WHERE id = ${restaurantId}::uuid`;
    const before = await rowsFor(restaurantId);

    await expect(
      admin.approve({ actorId: adminUserId, actorRoles: ['moderator'], restaurantId }),
    ).rejects.toMatchObject({ response: { code: 'forbidden_role' } });

    // No approval row, and the venue is untouched.
    const after = await rowsFor(restaurantId);
    expect(after.filter((r) => r.action === 'restaurant.approve')).toHaveLength(
      before.filter((r) => r.action === 'restaurant.approve').length,
    );
    const venue = await prisma.restaurant.findUniqueOrThrow({ where: { id: restaurantId } });
    expect(venue.status).toBe('pending_review');
  }, 60_000);

  it('the decision and its audit row are ATOMIC — never one without the other', async () => {
    await prisma.$executeRaw`
      UPDATE restaurants SET status = 'pending_review' WHERE id = ${restaurantId}::uuid`;

    const countBefore = (await rowsFor(restaurantId)).length;
    await admin.approve({ actorId: adminUserId, actorRoles: ['admin'], restaurantId });

    const rows = await rowsFor(restaurantId);
    const venue = await prisma.restaurant.findUniqueOrThrow({ where: { id: restaurantId } });

    // Both moved together.
    expect(rows.length).toBe(countBefore + 1);
    expect(venue.status).toBe('active');
    expect(rows[rows.length - 1].after).toMatchObject({ status: 'active' });
  }, 60_000);
});

describe('audit_logs — append-only (doc 04 §2)', () => {
  it('rejects an UPDATE, even from the connection that wrote the row', async () => {
    const rows = await rowsFor(restaurantId);
    expect(rows.length).toBeGreaterThan(0);
    const id = rows[0].id;

    // GRANTs would not stop us here: the API connects as the table owner.
    // The prohibition has to bind the owner too.
    await expect(
      prisma.$executeRaw`UPDATE audit_logs SET action = 'tampered' WHERE id = ${id}`,
    ).rejects.toThrow();

    const after = await rowsFor(restaurantId);
    expect(after[0].action).not.toBe('tampered');
  }, 60_000);

  it('rejects a DELETE', async () => {
    const rows = await rowsFor(restaurantId);
    const id = rows[0].id;

    await expect(
      prisma.$executeRaw`DELETE FROM audit_logs WHERE id = ${id}`,
    ).rejects.toThrow();

    expect((await rowsFor(restaurantId)).length).toBe(rows.length);
  }, 60_000);

  it('rejects a blanket TRUNCATE', async () => {
    await expect(prisma.$executeRaw`TRUNCATE audit_logs`).rejects.toThrow();
  }, 60_000);

  it('still accepts INSERTs — append-only, not read-only', async () => {
    const entity = randomUUID();
    await audit.record({
      actorId: adminUserId,
      actorRole: 'admin',
      action: 'test.insert',
      entityType: 'test',
      entityId: entity,
      after: { ok: true },
    });
    expect(await rowsFor(entity)).toHaveLength(1);
  }, 60_000);
});

describe('audit_logs — schema shape (doc 04 §2)', () => {
  it('carries the indexes the doc specifies', async () => {
    const idx = await prisma.$queryRaw<{ indexname: string }[]>`
      SELECT indexname FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = 'audit_logs'`;
    const names = idx.map((i) => i.indexname);
    expect(names).toContain('idx_audit_entity');
    expect(names).toContain('idx_audit_actor_created');
  }, 60_000);

  it('allows a NULL actor for system-originated actions', async () => {
    const entity = randomUUID();
    await audit.record({
      actorId: null,
      actorRole: 'system',
      action: 'hold.expire',
      entityType: 'reservation',
      entityId: entity,
    });
    const rows = await rowsFor(entity);
    expect(rows[0].actor_id).toBeNull();
    expect(rows[0].actor_role).toBe('system');
  }, 60_000);
});
