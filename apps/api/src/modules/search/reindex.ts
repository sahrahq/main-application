/**
 * `pnpm reindex` — rebuild the search index from Postgres.
 *
 * The index is a derived copy, so it can drift: a venue approved while
 * Meilisearch was down, a settings change that needs a rebuild, a fresh
 * environment. This is the reconciliation path, and it exists because the
 * write path deliberately refuses to fail an admin decision on an index error.
 *
 * Postgres is read as the source of truth and the index is made to match —
 * including deleting documents for venues that are no longer active, which is
 * the half a naive "re-add everything" reindex silently skips.
 */
import { PrismaClient } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { MeiliSearchIndex, DEFAULT_INDEX_UID } from './meili-search.index';
import { loadAllLiveIds, loadLiveRows, toSearchDoc } from './search-doc';

const BATCH = 200;

async function main(): Promise<void> {
  const host = process.env.MEILISEARCH_HOST;
  if (!host) {
    console.error('MEILISEARCH_HOST is not set — nothing to reindex.');
    process.exit(1);
  }

  const prisma = new PrismaClient();
  const index = new MeiliSearchIndex(
    host,
    process.env.MEILISEARCH_API_KEY || process.env.MEILISEARCH_MASTER_KEY || undefined,
    process.env.MEILISEARCH_INDEX ?? DEFAULT_INDEX_UID,
  );

  try {
    await prisma.$connect();
    await index.ensureIndex();

    const p = prisma as unknown as PrismaService;
    const ids = await loadAllLiveIds(p);
    console.log(`${ids.length} active restaurants to index.`);

    const live = new Set(ids);
    for (let i = 0; i < ids.length; i += BATCH) {
      const slice = ids.slice(i, i + BATCH);
      const rows = await loadLiveRows(p, slice);
      await index.upsert([...rows.values()].map(toSearchDoc));
      console.log(`  indexed ${Math.min(i + BATCH, ids.length)}/${ids.length}`);
    }
    await index.waitForIdle();

    // Now the other direction: anything in the index that Postgres no longer
    // considers live. Without this pass a suspended venue stays searchable
    // forever, which is the failure mode a reindex is supposed to cure.
    const stale = await index.allDocumentIds();
    const orphans = stale.filter((id) => !live.has(id));
    if (orphans.length) {
      await index.remove(orphans);
      await index.waitForIdle();
      console.log(`Removed ${orphans.length} document(s) no longer active.`);
    }

    console.log('Reindex complete.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
