/**
 * THE INVARIANTS THAT WERE ONLY EVER CONVENTIONS. Asked of the database.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS FILE EXISTS
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Group D found that `ENABLE ROW LEVEL SECURITY` had become opt-in without
 * anybody deciding it should. `ALTER DEFAULT PRIVILEGES` carried layer 1 of the
 * Data API lockdown forward to new tables automatically; RLS has no equivalent,
 * so layer 2 silently stopped applying and five tables shipped with one layer.
 *
 * The lesson is not about RLS. It is that **a guarantee applied by hand decays
 * at exactly the rate people forget**, and nothing in the system was positioned
 * to notice. So every other blanket promise in this schema was swept for, and
 * each one now either cannot be forgotten (a trigger) or is asked about here.
 *
 * ── THE RULE FOR ADDING TO THIS FILE ─────────────────────────────────────
 *
 * Every check reads the CATALOG. Not the migration files, not a list of tables
 * written down next to the check — the catalog. A test that is handed the list
 * of things to verify only ever verifies the things somebody remembered, which
 * is the failure it is here to prevent, one level up.
 *
 * Exemptions are named individually, with a reason, and every one of them is
 * itself asserted to still be real. A stale exemption quietly widens the rule.
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { PrismaClient } from '@prisma/client';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

/** PostGIS's own objects. Not ours to ALTER; they hold no SAHRA data. */
const POSTGIS = new Set(['spatial_ref_sys', 'geometry_columns', 'geography_columns']);

interface Col {
  table_name: string;
  column_name: string;
  data_type: string;
  numeric_precision: number | null;
  numeric_scale: number | null;
}

let tables: string[] = [];
let columns: Col[] = [];

beforeAll(async () => {
  await prisma.$connect();

  tables = (
    await prisma.$queryRaw<{ t: string }[]>`
      SELECT c.relname AS t FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' ORDER BY c.relname`
  ).map((r) => r.t);

  columns = await prisma.$queryRaw<Col[]>`
    SELECT table_name, column_name, data_type, numeric_precision, numeric_scale
      FROM information_schema.columns
     WHERE table_schema = 'public'
     ORDER BY table_name, column_name`;
}, 60_000);

afterAll(async () => {
  await prisma.$disconnect();
});

const ours = (t: string): boolean => !POSTGIS.has(t) && t !== '_prisma_migrations';

it('the catalog was actually read — census', () => {
  // Every assertion below is "this list is empty". So is every assertion made
  // against a database nobody connected to.
  expect(tables.length).toBeGreaterThanOrEqual(20);
  expect(columns.length).toBeGreaterThanOrEqual(150);
});

// ═══════════════════════════════════════════════════════════════════════════
//  updated_at — the one that was actually wrong
// ═══════════════════════════════════════════════════════════════════════════
describe('updated_at is maintained by the DATABASE, not by whoever wrote the UPDATE', () => {
  /**
   * It used to be a convention in two places, neither of them the database:
   * Prisma's `@updatedAt` (application-level, and blind to raw SQL) and a
   * hand-written `updated_at = now()` in each `$executeRaw`.
   *
   * Eight raw UPDATEs touch `reservations`. TWO of them forgot — including the
   * venue cancelling a booking, which left the column reading from before the
   * cancellation. Nothing failed, and nothing could: no test reads the column
   * and the value it held was perfectly plausible.
   */
  let withColumn: string[] = [];
  let triggered: string[] = [];

  beforeAll(async () => {
    withColumn = columns
      .filter((c) => c.column_name === 'updated_at' && ours(c.table_name))
      .map((c) => c.table_name);

    triggered = (
      await prisma.$queryRaw<{ t: string }[]>`
        SELECT c.relname AS t FROM pg_trigger tg
          JOIN pg_class c ON c.oid = tg.tgrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public'
           AND NOT tg.tgisinternal
           AND tg.tgname = 'trg_touch_updated_at'`
    ).map((r) => r.t);
  });

  it('there are tables with the column at all — census', () => {
    expect(withColumn.length).toBeGreaterThanOrEqual(10);
  });

  it('EVERY table with an updated_at column has the touch trigger', () => {
    const missing = withColumn.filter((t) => !triggered.includes(t)).sort();
    expect(missing).toEqual([]);
  });

  it('and the trigger is not attached to a table that has no such column', () => {
    // The other direction, because a BEFORE UPDATE trigger assigning to a
    // column that does not exist fails every UPDATE on that table at runtime —
    // loudly, but only once somebody tries to write.
    const stray = triggered.filter((t) => !withColumn.includes(t)).sort();
    expect(stray).toEqual([]);
  });

  it('the trigger actually changes the value, on a real row', async () => {
    // The claim that matters. The three above prove the trigger is ATTACHED;
    // this proves it does something — a `RETURN NEW` with the assignment
    // deleted would pass all of them.
    //
    // Deliberately through raw SQL that does NOT mention updated_at, because
    // that is the exact shape of the two statements that forgot.
    const rows = await prisma.$queryRaw<{ id: string; updated_at: Date }[]>`
      SELECT id, updated_at FROM restaurants ORDER BY created_at LIMIT 1`;
    if (rows.length === 0) return; // an empty database has nothing to prove

    const before = rows[0].updated_at;
    await new Promise((r) => setTimeout(r, 5));
    await prisma.$executeRaw`
      UPDATE restaurants SET city = city WHERE id = ${rows[0].id}::uuid`;

    const after = await prisma.$queryRaw<{ updated_at: Date }[]>`
      SELECT updated_at FROM restaurants WHERE id = ${rows[0].id}::uuid`;

    expect(after[0].updated_at.getTime()).toBeGreaterThan(before.getTime());
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  functions
// ═══════════════════════════════════════════════════════════════════════════
describe('every function we own pins its search_path', () => {
  /**
   * The advisor fix in `20260801000000_lock_down_data_api` set
   * `SET search_path = ''` on the two trigger functions that existed then, and
   * explained why: without it, a role able to create objects in an earlier
   * schema could shadow a table name and hijack the trigger.
   *
   * Three more functions have been added since, and each one happened to
   * remember. Nothing checked. This is the check.
   */
  let fns: { proname: string; proconfig: string[] | null }[] = [];

  beforeAll(async () => {
    fns = await prisma.$queryRaw<{ proname: string; proconfig: string[] | null }[]>`
      SELECT p.proname, p.proconfig
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public'
         -- Ours = not owned by an installed extension. PostGIS contributes
         -- several hundred functions and none of them is our business.
         AND NOT EXISTS (
           SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
       ORDER BY p.proname`;
  });

  it('found our functions — census', () => {
    expect(fns.length).toBeGreaterThanOrEqual(5);
    // Named, so the census cannot be satisfied by five PostGIS leftovers.
    expect(fns.map((f) => f.proname)).toContain('sahra_touch_updated_at');
  });

  it('none of them leaves search_path mutable', () => {
    const unpinned = fns
      .filter((f) => !(f.proconfig ?? []).some((c) => c.startsWith('search_path=')))
      .map((f) => f.proname);
    expect(unpinned).toEqual([]);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  column types — doc 04's own conventions, as assertions
// ═══════════════════════════════════════════════════════════════════════════
describe('the type conventions doc 04 states in its header', () => {
  it('no money is a float, anywhere', () => {
    // CLAUDE.md rule 5: "money is NUMERIC(12,2) + currency, never floats." A
    // `double precision` column would be the rule broken in the one way that
    // cannot be undone later — the rounding has already happened.
    const floats = columns
      .filter(
        (c) =>
          ours(c.table_name) &&
          ['double precision', 'real', 'money'].includes(c.data_type),
      )
      .map((c) => `${c.table_name}.${c.column_name} (${c.data_type})`);
    expect(floats).toEqual([]);
  });

  it('every numeric column is (12,2), or is named as not being money', () => {
    /**
     * `NUMERIC(12,2)` is the precedent, recorded in doc 04 §menu_items after
     * `menu_items.price` became the first money column in the database. The
     * exemption is not money at all.
     */
    const notMoney = new Map<string, string>([
      [
        'restaurants.rating_avg',
        '(3,2) — a rating between 0 and 5, recomputed by trigger from `reviews`. ' +
          'Widening it to (12,2) would say a venue could be rated 9,999,999,999.',
      ],
    ]);

    const numerics = columns.filter((c) => ours(c.table_name) && c.data_type === 'numeric');
    expect(numerics.length).toBeGreaterThanOrEqual(2);

    const wrong = numerics
      .filter((c) => {
        const key = `${c.table_name}.${c.column_name}`;
        if (notMoney.has(key)) return false;
        return c.numeric_precision !== 12 || c.numeric_scale !== 2;
      })
      .map((c) => `${c.table_name}.${c.column_name} is (${c.numeric_precision},${c.numeric_scale})`);

    expect(wrong).toEqual([]);

    // And every exemption is still a real column, so the list cannot outlive
    // its reasons.
    for (const key of notMoney.keys()) {
      const [t, col] = key.split('.');
      const stillThere = columns.some(
        (c) => c.table_name === t && c.column_name === col,
      );
      // `${key} is exempted from the money rule but no longer exists`
      expect(stillThere).toBe(true);
    }
  });

  it('every timestamp carries its zone', () => {
    // A `timestamp without time zone` in a product that computes availability
    // across Africa/Cairo and its DST changes is a bug waiting for a specific
    // fortnight in the year. doc 04's header says TIMESTAMPTZ; this says it in
    // a way that fails.
    const naive = columns
      .filter((c) => ours(c.table_name) && c.data_type === 'timestamp without time zone')
      .map((c) => `${c.table_name}.${c.column_name}`);
    expect(naive).toEqual([]);
  });

  it("created_at/updated_at is NOT on every table, and the exceptions are the ones we chose", () => {
    /**
     * doc 04's header claims `created_at/updated_at … on every table`. It is
     * false for seven of them, and every one is deliberate — so the doc now
     * says so and this pins the list. An eighth has to be a decision.
     */
    const noUpdatedAt = new Map<string, string>([
      ['audit_logs', 'append-only; a trigger rejects every UPDATE, so the column could never change'],
      ['roles', 'a fixed lookup, seeded once and never written again'],
      ['reservation_tables', 'a join row whose only mutable columns are set by trigger from its parent'],
      ['user_roles', 'granted once; a revoke is a DELETE'],
      ['favorites', 'created or deleted, never updated — there is nothing to change about a save'],
      ['refresh_tokens', 'rotated, not edited; `revoked_at` already records the one mutation'],
      ['notifications', '`read_at` and `sent_at` ARE the timestamps that matter here'],
    ]);

    const actual = tables
      .filter(ours)
      .filter((t) => !columns.some((c) => c.table_name === t && c.column_name === 'updated_at'))
      .sort();

    expect(actual).toEqual([...noUpdatedAt.keys()].sort());
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  ownership and grants — the half of layer 1 that cannot be applied by us
// ═══════════════════════════════════════════════════════════════════════════
describe('the Data API lockdown, verified rather than assumed', () => {
  /**
   * ╔═══════════════════════════════════════════════════════════════════════╗
   * ║  THE LOAD-BEARING CHECK.                                              ║
   * ║                                                                       ║
   * ║  Do not delete, weaken, or move this without reading                  ║
   * ║  `docs/decisions/2026-08-09-data-api-lockdown.md` first.              ║
   * ╚═══════════════════════════════════════════════════════════════════════╝
   *
   * Of the five mechanisms the Data API lockdown appeared to have, **this is
   * the one keeping `anon` out of tables created after it ran.**
   *
   *   · The table-level REVOKE works — but it cannot reach a future table.
   *   · `REVOKE USAGE ON SCHEMA public` DID NOTHING. The schema belongs to
   *     `supabase_admin` and a REVOKE by `postgres` removes only what
   *     `postgres` granted. It reported success. Asserted below as still
   *     granted, so nobody mistakes it for closed.
   *   · `ALTER DEFAULT PRIVILEGES` is scoped to the issuing role. It covers
   *     tables `postgres` creates — which is only useful *because* `postgres`
   *     is the creator, i.e. because of this check.
   *   · RLS did not carry forward at all; five tables ran on one layer for
   *     three batches. `rls-coverage.e2e-spec.ts` now covers that.
   *
   * `supabase_admin` still holds default privileges granting `anon` full
   * access to tables IT creates. So a table created by any role other than
   * `postgres` arrives with `SELECT, INSERT, UPDATE, DELETE` open to the
   * publishable key that ships inside the APK — **and no migration file would
   * look wrong.**
   *
   * Nothing was checking this until 2026-08-09.
   */
  it('THE LOAD-BEARING CHECK: every table in public is owned by postgres', async () => {
    const rows = await prisma.$queryRaw<{ tablename: string; tableowner: string }[]>`
      SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public'`;

    const foreign = rows
      .filter((r) => !POSTGIS.has(r.tablename) && r.tableowner !== 'postgres')
      .map((r) => `${r.tablename} owned by ${r.tableowner}`);
    expect(foreign).toEqual([]);
  });

  it('anon and authenticated have no privilege on any table we own', async () => {
    const rows = await prisma.$queryRaw<{ table_name: string; grantee: string }[]>`
      SELECT DISTINCT table_name, grantee
        FROM information_schema.role_table_grants
       WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated')`;

    const leaked = rows
      .filter((r) => !POSTGIS.has(r.table_name))
      .map((r) => `${r.grantee} on ${r.table_name}`)
      .sort();
    expect(leaked).toEqual([]);
  });

  it('the PostGIS exemption is exactly three tables, and they still exist', async () => {
    // Otherwise the exemption set above is a hole of unknown size.
    const rows = await prisma.$queryRaw<{ table_name: string }[]>`
      SELECT DISTINCT table_name
        FROM information_schema.role_table_grants
       WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated')`;
    expect(rows.map((r) => r.table_name).sort()).toEqual(
      [...POSTGIS].sort(),
    );
  });

  it('schema USAGE for anon is STILL GRANTED, and that is recorded rather than fixed', async () => {
    /**
     * `REVOKE USAGE ON SCHEMA public FROM anon, authenticated` is in the
     * lockdown migration and DID NOTHING. The schema belongs to
     * `supabase_admin`; a REVOKE issued by `postgres` can only remove grants
     * `postgres` made. The statement reported success.
     *
     * Asserted as TRUE on purpose. It is not a hole by itself — USAGE with no
     * table privileges grants the ability to name objects and nothing more —
     * and pretending we removed it would be worse than knowing we did not. If
     * this ever flips to false, somebody with more privilege than us changed
     * it and the note above needs revisiting.
     */
    // Guarded on the role existing. `anon` is a Supabase role; against a plain
    // Postgres container `has_schema_privilege` would throw and this check
    // would fail for a reason that has nothing to do with the claim.
    const exists = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM pg_roles WHERE rolname = 'anon'`;
    if (Number(exists[0].n) === 0) return;

    const rows = await prisma.$queryRaw<{ usage: boolean }[]>`
      SELECT has_schema_privilege('anon', 'public', 'USAGE') AS usage`;
    expect(rows[0].usage).toBe(true);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
//  index names — CLAUDE.md rule 3 says they are part of the contract
// ═══════════════════════════════════════════════════════════════════════════
describe('every index doc 04 names by name exists', () => {
  /**
   * "Follow the DB schema exactly, **including index names**" (CLAUDE.md rule
   * 3). Nothing verified it, and the sweep found one that does not match.
   *
   * Read out of the document rather than listed here, so the document stays the
   * contract.
   */
  let named: string[] = [];
  let present: string[] = [];

  /**
   * Named in doc 04 for a table that does not exist yet, or deliberately not
   * built. Each has to say WHICH, because "the table isn't there" and "we
   * decided against it" are different facts.
   */
  const notYet = new Map<string, string>([
    ['idx_pay_user', 'payments — table not built; blocked on company registration'],
    ['idx_pay_resv', 'payments — table not built'],
    ['idx_pay_status_created', 'payments — table not built'],
    ['idx_loyalty_user', 'loyalty_transactions — table not built (C-4.5, P1)'],
    ['idx_subs_status_period', 'restaurant_subscriptions — table not built (R-4.4, blocked on payments)'],
    // `idx_notif_user_unread` WAS HERE, exempted on 2026-08-09 by the
    // silent-lapse sweep because nothing read `read_at`. Group G's
    // `GET /notifications` reads it, so the index was built the same day, under
    // doc 04's name, and the exemption came out in the same commit — which is
    // the arrangement the exemption itself specified. The "nothing on the
    // not-yet list has quietly been built" test below is what made that
    // mandatory rather than polite.
  ]);

  beforeAll(async () => {
    const doc = readFileSync(
      join(__dirname, '..', '..', '..', 'docs', 'blueprint', '04-database-design.md'),
      'utf8',
    );
    named = [...new Set(doc.match(/idx_[a-z0-9_]+/g) ?? [])].sort();

    present = (
      await prisma.$queryRaw<{ indexname: string }[]>`
        SELECT indexname FROM pg_indexes WHERE schemaname = 'public'`
    ).map((r) => r.indexname);
  });

  it('doc 04 was read and it names indexes — census', () => {
    expect(named.length).toBeGreaterThanOrEqual(20);
    expect(present.length).toBeGreaterThanOrEqual(40);
  });

  it('each one either exists or is on the not-yet list with a reason', () => {
    const missing = named.filter((n) => !present.includes(n) && !notYet.has(n));
    expect(missing).toEqual([]);
  });

  it('and nothing on the not-yet list has quietly been built', () => {
    // A stale entry here would mean the reason above is no longer true and
    // nobody removed it — which is how an exemption list becomes fiction.
    const built = [...notYet.keys()].filter((n) => present.includes(n));
    expect(built).toEqual([]);
  });
});
