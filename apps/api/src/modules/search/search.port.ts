/**
 * The search index, behind a port (doc 06 §3 names Meilisearch; hexagonal
 * boundary per DEVELOPMENT.md §1).
 *
 * The index answers exactly one question: WHICH restaurants match this text
 * and these facets. It never answers WHAT to show the diner and it never
 * answers WHEN a table is free. Both of those come from Postgres and the
 * AvailabilityService respectively — see restaurant-search.service.ts.
 *
 * That split is the whole design. An index is a denormalised copy and is
 * therefore always a little stale; confining it to matching means staleness
 * costs recall (a venue shows up late) and never correctness (a venue shows a
 * price, a rating, or a free table that is not real).
 */

/**
 * What actually lives in the index. Note what is ABSENT: no availability, no
 * slots, no `next_available`. Availability is derived per doc 05 §1 and must
 * never be cached here — a cached slot is a promise the engine did not make.
 */
export interface RestaurantSearchDoc {
  id: string;
  nameEn: string;
  nameAr: string;
  cuisines: string[];
  neighborhood: string | null;
  city: string;
  priceBand: number | null;
  rating: number;
  ratingCount: number;
  amenities: string[];
  /** Meilisearch's reserved geo field; absent if the venue has no point. */
  _geo?: { lat: number; lng: number };
}

export interface IndexQuery {
  q?: string;
  cuisine?: string;
  neighborhood?: string;
  priceBand?: number;
  ratingMin?: number;
  amenities?: string[];
  lat?: number;
  lng?: number;
  radiusKm?: number;
  sort?: 'relevance' | 'rating' | 'distance';
  limit: number;
  offset: number;
}

export interface IndexHits {
  /** Restaurant ids, in ranked order. */
  ids: string[];
  estimatedTotal: number;
}

/**
 * Abstract class rather than a symbol token: it is both the DI token and the
 * contract, so an adapter that drifts from it fails to compile.
 */
export abstract class RestaurantIndexPort {
  abstract ensureIndex(): Promise<void>;
  abstract upsert(docs: RestaurantSearchDoc[]): Promise<void>;
  abstract remove(ids: string[]): Promise<void>;
  abstract query(q: IndexQuery): Promise<IndexHits>;
  /** Block until every pending write is visible. Tests and reindex only. */
  abstract waitForIdle(): Promise<void>;
}
