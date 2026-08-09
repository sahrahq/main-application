/**
 * EVERY TABLE HAS ROW LEVEL SECURITY. Asked of the database, not of the
 * migration files.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS EXISTS
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `20260801000000_lock_down_data_api` built two layers against Supabase's
 * auto-exposed PostgREST surface, and said in its own header why there were
 * two: "so re-granting one does not silently reopen access."
 *
 *   Layer 1  REVOKE + ALTER DEFAULT PRIVILEGES
 *   Layer 2  ENABLE ROW LEVEL SECURITY, no policies
 *
 * `ALTER DEFAULT PRIVILEGES` made layer 1 apply to tables created later,
 * automatically and invisibly. **There is no equivalent for RLS.** So every
 * table added after that migration had layer 1 and not layer 2, and nothing
 * anywhere could tell:
 *
 *   notifications, devices  (Group "notifications stage 1")
 *   images                  (Group B)
 *   favorites, waitlists    (Group C)
 *
 * Five tables, three batches, four weeks. Found in Group D by asking
 * `pg_class` instead of reading the migrations — and the reason it went
 * unnoticed is that the thing which was supposed to notice did not exist.
 *
 * ── WHY IT ASKS THE DATABASE ─────────────────────────────────────────────
 *
 * A test that listed the tables it expects would be a second copy of the
 * schema, and a new table would be missing from both the migration and the
 * list. This enumerates what is actually there and asserts a property of every
 * row. A table added tomorrow is in the result set on the day it is created,
 * whether or not anybody remembered this file.
 *
 * `spatial_ref_sys` is the single exemption and it is named, not pattern-
 * matched: it belongs to the PostGIS extension, is not ours to ALTER, and
 * holds public coordinate-system reference data with no SAHRA data in it.
 */
import { PrismaClient } from '@prisma/client';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

/** Not ours. See the header. */
const NOT_OURS = new Set(['spatial_ref_sys']);

interface TableRow {
  tablename: string;
  rls: boolean;
}

let tables: TableRow[] = [];

beforeAll(async () => {
  await prisma.$connect();
  tables = await prisma.$queryRaw<TableRow[]>`
    SELECT c.relname AS tablename, c.relrowsecurity AS rls
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'r'
     ORDER BY c.relname`;
}, 60_000);

afterAll(async () => {
  await prisma.$disconnect();
});

describe('row level security covers every table we own', () => {
  it('found the tables — census', () => {
    // An empty result would make the assertion below pass by having nothing to
    // check, which is the exact shape of the failure this file was written
    // after.
    expect(tables.length).toBeGreaterThanOrEqual(20);
  });

  it('the exemption is real — it exists and it is the only one', () => {
    // A named exemption that no longer matches a table is an exemption that has
    // outlived its reason, and it would sit here quietly widening the rule.
    for (const name of NOT_OURS) {
      expect(tables.map((t) => t.tablename)).toContain(name);
    }
  });

  it('every other table has RLS enabled', () => {
    const off = tables
      .filter((t) => !t.rls && !NOT_OURS.has(t.tablename))
      .map((t) => t.tablename);

    expect(off).toEqual([]);
  });

  it('and none of them has a policy, which is what makes it deny-by-default', () => {
    // RLS with a permissive policy is RLS that lets somebody in. The lockdown
    // migration deliberately created none: "with RLS on and zero policies,
    // every non-owner role is denied." A policy added later would turn this
    // whole mechanism off for that table while `relrowsecurity` still read
    // true — so the flag alone is not the property worth asserting.
    return prisma
      .$queryRaw<{ tablename: string; policyname: string }[]>`
        SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public'`
      .then((policies) => {
        expect(policies).toEqual([]);
      });
  });
});
