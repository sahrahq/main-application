import { Module, OnModuleInit, Logger } from '@nestjs/common';
import { AvailabilityModule } from '../availability/availability.module';
import { RestaurantIndexPort } from './search.port';
import { MeiliSearchIndex, DEFAULT_INDEX_UID } from './meili-search.index';
import { DisabledSearchIndex } from './disabled-search.index';
import { RestaurantSearchService } from './restaurant-search.service';
import { SearchController } from './search.controller';

/**
 * Search wiring (doc 06 §3).
 *
 * Exports the PORT, not the Meilisearch class, so the admin module can keep
 * the index in step on approve/reject without depending on Meilisearch —
 * exactly the same shape as the OTP store adapters.
 */
@Module({
  imports: [AvailabilityModule],
  providers: [
    {
      provide: RestaurantIndexPort,
      useFactory: (): RestaurantIndexPort => {
        const host = process.env.MEILISEARCH_HOST;
        if (!host) return new DisabledSearchIndex();
        return new MeiliSearchIndex(
          host,
          process.env.MEILISEARCH_API_KEY || process.env.MEILISEARCH_MASTER_KEY || undefined,
          process.env.MEILISEARCH_INDEX ?? DEFAULT_INDEX_UID,
        );
      },
    },
    RestaurantSearchService,
  ],
  controllers: [SearchController],
  exports: [RestaurantIndexPort, RestaurantSearchService],
})
export class SearchModule implements OnModuleInit {
  private readonly logger = new Logger(SearchModule.name);

  constructor(private readonly index: RestaurantIndexPort) {}

  /**
   * Settings are pinned at boot rather than assumed. An index created by hand
   * has no filterableAttributes, and every faceted query against it fails with
   * an error that reads like a bad request from the client.
   *
   * A failure here is logged, not thrown: the API serves bookings, and a
   * search server that is slow to start must not stop the process that takes
   * reservations.
   */
  async onModuleInit(): Promise<void> {
    try {
      await this.index.ensureIndex();
    } catch (err) {
      this.logger.error(
        `Could not initialise the search index: ${(err as Error).message}. Search will 503 until it is reachable.`,
      );
    }
  }
}
