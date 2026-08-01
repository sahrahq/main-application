import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { AvailabilityService } from '../availability/availability.service';
import { RestaurantIndexPort } from './search.port';
import { loadLiveRows, RestaurantRowForSearch } from './search-doc';

/** doc 06 §1: "cursor-based — ?limit=20&cursor=...". */
export const SEARCH_PAGE_SIZE = 20;

/** How many upcoming times a result teases. doc 06 §3 shows two. */
const NEXT_AVAILABLE_COUNT = 3;

export interface SearchQuery {
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
  /** YYYY-MM-DD. With partySize, turns on the availability post-filter. */
  date?: string;
  partySize?: number;
  cursor?: string;
  limit?: number;
}

/** doc 06 §3, "Search response item". snake_case: this is the wire shape. */
export interface SearchResultItem {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  cuisines: string[];
  neighborhood: string | null;
  price_band: number | null;
  rating: number;
  rating_count: number;
  distance_km?: number;
  /**
   * Local HH:MM teasers, present ONLY when a date+party_size was asked for.
   * Absent means "not asked"; it never means "nothing free" — a venue with
   * nothing free is dropped from the results entirely.
   *
   * These are a HINT, not an offer. They are already stale by the time the
   * diner reads them, and they carry no absolute instant precisely so that no
   * client can treat one as bookable: to book, the client calls
   * `/restaurants/:id/availability` for real `starts_at` values, and the hold
   * re-validates again under the per-restaurant lock.
   */
  next_available?: string[];
}

export interface SearchResponse {
  results: SearchResultItem[];
  next_cursor: string | null;
  estimated_total: number;
  /** True when results were filtered by real availability. */
  availability_filtered: boolean;
}

/**
 * Discovery search — Meilisearch + availability post-filter (doc 06 §3).
 *
 * Three responsibilities, deliberately kept in three different places:
 *
 *   WHICH venues match  → Meilisearch (this is all the index is trusted for)
 *   WHAT they look like → Postgres, re-read per page
 *   WHEN they are free  → AvailabilityService, the same code path a hold uses
 *
 * The last one is the rule worth stating plainly: `next_available` is never
 * read from the index. Availability is derived, not stored (doc 05 §1), and an
 * index that cached slots would advertise tables that were taken minutes ago.
 * The worst failure in a reservation app is a diner tapping a result and
 * finding nothing bookable, so search shows only what the engine itself would
 * offer at that moment — and even then only as a hint (see next_available).
 */
@Injectable()
export class RestaurantSearchService {
  private readonly logger = new Logger(RestaurantSearchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly index: RestaurantIndexPort,
    private readonly availability: AvailabilityService,
  ) {}

  async search(q: SearchQuery): Promise<SearchResponse> {
    const limit = Math.min(Math.max(q.limit ?? SEARCH_PAGE_SIZE, 1), SEARCH_PAGE_SIZE);
    const offset = decodeCursor(q.cursor);

    // 1. WHICH — the index ranks and pages. Nothing else.
    const hits = await this.index.query({
      q: q.q,
      cuisine: q.cuisine,
      neighborhood: q.neighborhood,
      priceBand: q.priceBand,
      ratingMin: q.ratingMin,
      amenities: q.amenities,
      lat: q.lat,
      lng: q.lng,
      radiusKm: q.radiusKm,
      sort: q.sort,
      limit,
      offset,
    });

    // 2. WHAT — one round trip to Postgres for the page, preserving rank order.
    //    Ids the index still holds but Postgres no longer serves fall out here.
    const rows = await loadLiveRows(this.prisma, hits.ids);
    const ordered = hits.ids.map((id) => rows.get(id)).filter(Boolean) as RestaurantRowForSearch[];

    let results = ordered.map((r) => this.toItem(r, q));

    // 3. WHEN — the post-filter, for THIS PAGE ONLY.
    //    Availability is the expensive part (a query per slot per venue), so it
    //    is never computed for results the diner cannot see yet. Page two pays
    //    for page two.
    const wantsAvailability = Boolean(q.date && q.partySize);
    if (wantsAvailability) {
      results = await this.attachAvailability(results, q.date!, q.partySize!);
    }

    return {
      results,
      // The cursor advances by INDEX position, not by results returned. The
      // post-filter can shrink a page below `limit`, and re-deriving the
      // cursor from the survivors would silently re-serve or skip venues.
      next_cursor: hits.ids.length === limit ? encodeCursor(offset + limit) : null,
      estimated_total: hits.estimatedTotal,
      availability_filtered: wantsAvailability,
    };
  }

  /**
   * Ask AvailabilityService — the same service `/restaurants/:id/availability`
   * and the hold path consult — for each venue on the page, and drop any venue
   * with nothing bookable.
   *
   * Concurrent, because these are independent reads and a serial pass over 20
   * venues would put search well past its latency budget. Bounded at one page,
   * so concurrency is bounded at SEARCH_PAGE_SIZE by construction.
   */
  private async attachAvailability(
    items: SearchResultItem[],
    date: string,
    partySize: number,
  ): Promise<SearchResultItem[]> {
    const settled = await Promise.all(
      items.map(async (item) => {
        try {
          const av = await this.availability.getSlots({
            restaurantId: item.id,
            date,
            partySize,
          });
          const times = av.slots.map((s) => s.time);
          if (times.length === 0) return null; // nothing bookable → not a result
          return { ...item, next_available: times.slice(0, NEXT_AVAILABLE_COUNT) };
        } catch (err) {
          // One venue's bad shift data must not blank the whole page. Drop it
          // from an availability-filtered search: we cannot claim it is free.
          this.logger.warn(
            `Availability failed for ${item.id}: ${(err as Error).message} — omitting from results`,
          );
          return null;
        }
      }),
    );
    return settled.filter(Boolean) as SearchResultItem[];
  }

  private toItem(r: RestaurantRowForSearch, q: SearchQuery): SearchResultItem {
    const item: SearchResultItem = {
      id: r.id,
      slug: r.slug,
      name_en: r.name_en,
      name_ar: r.name_ar,
      cuisines: r.cuisines ?? [],
      neighborhood: r.neighborhood,
      price_band: r.price_band === null ? null : Number(r.price_band),
      rating: Number(r.rating_avg ?? 0),
      rating_count: Number(r.rating_count ?? 0),
    };
    if (q.lat !== undefined && q.lng !== undefined && r.lat !== null && r.lng !== null) {
      item.distance_km = haversineKm(q.lat, q.lng, Number(r.lat), Number(r.lng));
    }
    return item;
  }
}

/** Opaque to the client, so offset paging can become search-after later. */
function encodeCursor(offset: number): string {
  return Buffer.from(JSON.stringify({ o: offset }), 'utf8').toString('base64url');
}

function decodeCursor(cursor?: string): number {
  if (!cursor) return 0;
  try {
    const { o } = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    return Number.isInteger(o) && o >= 0 ? o : 0;
  } catch {
    return 0; // a mangled cursor restarts the list; it never 500s
  }
}

function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(h)) * 10) / 10;
}
