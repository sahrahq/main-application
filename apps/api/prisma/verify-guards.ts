/**
 * Post-migration assertion that the anti-double-booking guards actually
 * landed in the database. A missing EXCLUDE constraint is invisible until the
 * night it lets two parties onto one table — so we check explicitly.
 *
 *   pnpm --filter @sahra/api exec ts-node prisma/verify-guards.ts
 */
import { PrismaClient } from '@prisma/client';
import { config } from 'dotenv';
import { resolve } from 'path';

config({ path: resolve(__dirname, '..', '.env') });

const prisma = new PrismaClient({
  datasources: { db: { url: process.env.DIRECT_URL || process.env.DATABASE_URL } },
});

const REQUIRED_TABLES = [
  'users', 'roles', 'user_roles', 'restaurant_owners', 'restaurants',
  'shifts', 'tables', 'reservations', 'reservation_tables',
  'refresh_tokens', 'otp_challenges',
];

const REQUIRED_INDEXES = [
  'idx_users_status', 'idx_user_roles_role', 'idx_restaurants_status_neighborhood',
  'idx_restaurants_active', 'idx_restaurants_location', 'idx_restaurants_cuisines',
  'idx_shifts_rest_dow', 'idx_shifts_rest_date', 'idx_tables_rest_capacity',
  'idx_resv_rest_time', 'idx_resv_user', 'idx_resv_active', 'idx_resv_hold_expiry',
  'idx_restable_table',
];

async function main(): Promise<void> {
  let failures = 0;
  const bad = (m: string) => { console.error(`  ✗ ${m}`); failures++; };
  const ok = (m: string) => console.log(`  ✓ ${m}`);

  console.log('\nTables');
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'`;
  const have = new Set(tables.map((t) => t.tablename));
  for (const t of REQUIRED_TABLES) (have.has(t) ? ok : bad)(t);

  console.log('\nIndexes (names are load-bearing — doc 04 §5)');
  const idx = await prisma.$queryRaw<{ indexname: string }[]>`
    SELECT indexname FROM pg_indexes WHERE schemaname = 'public'`;
  const haveIdx = new Set(idx.map((i) => i.indexname));
  for (const i of REQUIRED_INDEXES) (haveIdx.has(i) ? ok : bad)(i);

  console.log('\nAnti-double-booking constraint (doc 05 §3, layer 3)');
  const excl = await prisma.$queryRaw<{ conname: string; def: string }[]>`
    SELECT conname, pg_get_constraintdef(oid) AS def
    FROM pg_constraint
    WHERE conname = 'no_table_overlap' AND contype = 'x'`;
  if (excl.length === 0) bad('no_table_overlap EXCLUDE constraint MISSING');
  else {
    ok(`no_table_overlap  ${excl[0].def}`);
    if (!/table_id/.test(excl[0].def) || !/during/.test(excl[0].def)) {
      bad('constraint exists but does not cover (table_id, during)');
    }
  }

  console.log('\nTriggers maintaining during/active');
  const trg = await prisma.$queryRaw<{ tgname: string }[]>`
    SELECT tgname FROM pg_trigger
    WHERE NOT tgisinternal AND tgname IN ('trg_resv_table_sync', 'trg_resv_propagate')`;
  const haveTrg = new Set(trg.map((t) => t.tgname));
  for (const t of ['trg_resv_table_sync', 'trg_resv_propagate']) (haveTrg.has(t) ? ok : bad)(t);

  console.log('\nExtensions');
  const ext = await prisma.$queryRaw<{ extname: string }[]>`SELECT extname FROM pg_extension`;
  const haveExt = new Set(ext.map((e) => e.extname));
  for (const e of ['btree_gist', 'citext', 'pgcrypto', 'postgis']) (haveExt.has(e) ? ok : bad)(e);

  console.log(failures === 0 ? '\nAll guards present.\n' : `\n${failures} PROBLEM(S).\n`);
  await prisma.$disconnect();
  process.exit(failures === 0 ? 0 : 1);
}

void main();
