import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { RestaurantIndexPort, IndexHits, IndexQuery } from './search.port';

/**
 * What the port resolves to when MEILISEARCH_HOST is not configured.
 *
 * The two halves behave differently on purpose:
 *
 *   query()  → 503. There is no honest empty result for "search is not
 *              running"; returning [] would tell the diner no restaurant in
 *              Cairo matches, which a client would happily cache.
 *
 *   upsert()/remove() → warn and continue. Indexing is a side effect of
 *              approving a venue, not part of approving it. An admin decision
 *              is a Postgres fact; it must never fail because a search server
 *              is down. `pnpm reindex` reconciles the drift afterwards.
 */
@Injectable()
export class DisabledSearchIndex extends RestaurantIndexPort {
  private readonly logger = new Logger(DisabledSearchIndex.name);

  async ensureIndex(): Promise<void> {
    this.logger.warn(
      'MEILISEARCH_HOST is not set — /restaurants/search will return 503 and index writes are dropped. Run `pnpm reindex` after enabling it.',
    );
  }

  async upsert(): Promise<void> {
    this.logger.warn('Index upsert dropped: search is disabled.');
  }

  async remove(): Promise<void> {
    this.logger.warn('Index remove dropped: search is disabled.');
  }

  async query(_q: IndexQuery): Promise<IndexHits> {
    throw new ServiceUnavailableException({
      code: 'search_unavailable',
      message: 'Search is temporarily unavailable. Please try again.',
      message_ar: 'البحث غير متاح مؤقتًا. برجاء المحاولة مرة أخرى.',
    });
  }

  async waitForIdle(): Promise<void> {
    /* nothing is ever pending */
  }
}
