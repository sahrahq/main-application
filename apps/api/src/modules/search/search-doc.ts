import { PrismaService } from '../../shared/prisma/prisma.service';
import { RestaurantSearchDoc } from './search.port';
import { indexSkeletons, MIN_SKELETON_LEN } from './transliterate';

/**
 * The one query that reads a restaurant for BOTH purposes: building an index
 * document and rendering a search result. Postgres is the source of truth for
 * every field a diner sees.
 */
export interface RestaurantRowForSearch {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  cuisines: string[];
  neighborhood: string | null;
  city: string;
  price_band: number | null;
  rating_avg: string | number;
  rating_count: number;
  amenities: unknown;
  status: string;
  lat: number | null;
  lng: number | null;
}

/**
 * Load rows by id, LIVE ONLY.
 *
 * The `status = 'active' AND deleted_at IS NULL` predicate is deliberately
 * repeated here even though only active venues are ever indexed. It makes
 * index staleness harmless in the one direction that matters: a venue that was
 * suspended a second ago and is still sitting in the index simply vanishes
 * from results. The index can lag; it can never resurrect a dead listing.
 */
export async function loadLiveRows(
  prisma: PrismaService,
  ids: string[],
): Promise<Map<string, RestaurantRowForSearch>> {
  if (ids.length === 0) return new Map();

  const rows = await prisma.$queryRaw<RestaurantRowForSearch[]>`
    SELECT r.id, r.slug, r.name_en, r.name_ar, r.cuisines,
           r.neighborhood, r.city, r.price_band,
           r.rating_avg, r.rating_count, r.amenities, r.status::text AS status,
           ST_Y(r.location::geometry) AS lat,
           ST_X(r.location::geometry) AS lng
      FROM restaurants r
     WHERE r.id = ANY(${ids}::uuid[])
       AND r.status = 'active'
       AND r.deleted_at IS NULL`;

  return new Map(rows.map((r) => [r.id, r]));
}

/** Everything currently eligible to be searchable — the reindex source. */
export async function loadAllLiveIds(prisma: PrismaService): Promise<string[]> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    SELECT id FROM restaurants
     WHERE status = 'active' AND deleted_at IS NULL
     ORDER BY updated_at DESC`;
  return rows.map((r) => r.id);
}

export function toSearchDoc(r: RestaurantRowForSearch): RestaurantSearchDoc {
  const doc: RestaurantSearchDoc = {
    id: r.id,
    nameEn: r.name_en,
    nameAr: r.name_ar,
    cuisines: r.cuisines ?? [],
    neighborhood: r.neighborhood,
    city: r.city,
    priceBand: r.price_band === null ? null : Number(r.price_band),
    rating: Number(r.rating_avg ?? 0),
    ratingCount: Number(r.rating_count ?? 0),
    amenities: amenityKeys(r.amenities),
    // Both names, because either may be the one a diner types phonetically:
    // an Arabic name reached from franco-Arabic, and a Latin-branded name
    // reached from Arabic. Short keys are dropped — one consonant matches
    // half the city.
    translit: [
      ...new Set([...indexSkeletons(r.name_en), ...indexSkeletons(r.name_ar)]),
    ].filter((s) => s.length >= MIN_SKELETON_LEN),
  };
  if (r.lat !== null && r.lng !== null) doc._geo = { lat: Number(r.lat), lng: Number(r.lng) };
  return doc;
}

/**
 * `amenities` is JSONB and the schema does not pin its shape yet. Accept the
 * two forms already in use — `["valet"]` and `{valet: true}` — and ignore
 * anything else rather than throwing: a malformed amenities blob on one venue
 * must not take that venue out of search entirely.
 */
export function amenityKeys(value: unknown): string[] {
  if (Array.isArray(value)) return value.filter((v): v is string => typeof v === 'string');
  if (value && typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v === true)
      .map(([k]) => k);
  }
  return [];
}
