import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { ImagesService, ImageView } from '../images/images.service';
import { amenityKeys } from '../search/search-doc';
// Shared with the menus and reviews reads. See `live-restaurant.ts` for why the
// predicate stopped being duplicated once there were four copies of it in three
// files.
import { LIVE_ONLY, SLUG_RE, UUID_RE, restaurantNotFound } from './live-restaurant';

/**
 * The public restaurant profile — doc 06 §3, `GET /restaurants/:idOrSlug`.
 *
 * Snake_case on the wire, matching the search result item in doc 06 §3 rather
 * than the camelCase the owner endpoints use. These two responses describe the
 * SAME entity — a diner tapping a search result lands on this — and a client
 * that has to switch naming convention halfway through one concept ends up
 * with two mappers for one restaurant. The rest of the API is camelCase and
 * that inconsistency is real; it is not made worse by splitting the one entity
 * that appears in both shapes.
 */
export interface PublicHours {
  /** 0=Sunday. Null on a one-off date row. */
  day_of_week: number | null;
  /** YYYY-MM-DD for a one-off, null for a weekly row. */
  specific_date: string | null;
  name_en: string;
  name_ar: string;
  /** HH:MM on the restaurant's wall clock. */
  opens_at: string;
  closes_at: string;
  spans_midnight: boolean;
}

export interface PublicRestaurantProfile {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  description_en: string | null;
  description_ar: string | null;
  cuisines: string[];
  neighborhood: string | null;
  city: string;
  address_en: string | null;
  address_ar: string | null;
  lat: number | null;
  lng: number | null;
  price_band: number | null;
  rating: number;
  rating_count: number;
  phone: string | null;
  website: string | null;
  amenities: string[];
  policies: Record<string, unknown> | null;
  timezone: string;
  booking_mode: string;
  /** Every ACTIVE shift, ordered. Empty means the venue takes no bookings. */
  hours: PublicHours[];
  /** Cover first, then by position. Empty is a designed state, not an error. */
  images: ImageView[];
}

interface ProfileRow {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  description_en: string | null;
  description_ar: string | null;
  cuisines: string[] | null;
  neighborhood: string | null;
  city: string;
  address_en: string | null;
  address_ar: string | null;
  lat: number | null;
  lng: number | null;
  price_band: number | null;
  rating_avg: string | number;
  rating_count: number;
  phone: string | null;
  website: string | null;
  amenities: unknown;
  policies: unknown;
  timezone: string;
  booking_mode: string;
}

interface ShiftRow {
  day_of_week: number | null;
  specific_date: Date | null;
  name_en: string;
  name_ar: string;
  opens_at: Date;
  closes_at: Date;
  spans_midnight: boolean;
}

/** A `TIME` column comes back as a Date pinned to 1970 — only HH:MM is real. */
function hhmm(t: Date): string {
  return t.toISOString().slice(11, 16);
}


const PROFILE_SELECT = Prisma.sql`
  SELECT r.id, r.slug, r.name_en, r.name_ar,
         r.description_en, r.description_ar, r.cuisines,
         r.neighborhood, r.city, r.address_en, r.address_ar,
         ST_Y(r.location::geometry) AS lat,
         ST_X(r.location::geometry) AS lng,
         r.price_band, r.rating_avg, r.rating_count,
         r.phone, r.website, r.amenities, r.policies,
         r.timezone, r.booking_mode::text AS booking_mode
    FROM restaurants r`;

@Injectable()
export class PublicRestaurantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly images: ImagesService,
  ) {}

  /**
   * Resolve by id OR slug, LIVE ONLY.
   *
   * A venue that exists but is not `active` is a 404, not a 403. A 403 is a
   * confirmation that the row exists, which makes this endpoint an
   * enumeration oracle for unlaunched venues — the one thing an owner would
   * least like a competitor to be able to poll for.
   */
  async profile(idOrSlug: string): Promise<PublicRestaurantProfile> {
    const isUuid = UUID_RE.test(idOrSlug);
    if (!isUuid && !SLUG_RE.test(idOrSlug)) throw this.notFound();

    // Two queries rather than one with a branch in the WHERE clause: an
    // `id = $1::uuid OR slug = $1` predicate needs $1 to be both a uuid and
    // text, and the casts that make Postgres accept that also make it
    // unreadable. The lookup key is known before the query — use it.
    const rows = isUuid
      ? await this.prisma.$queryRaw<ProfileRow[]>`
          ${PROFILE_SELECT} WHERE r.id = ${idOrSlug}::uuid ${LIVE_ONLY} LIMIT 1`
      : await this.prisma.$queryRaw<ProfileRow[]>`
          ${PROFILE_SELECT} WHERE r.slug = ${idOrSlug} ${LIVE_ONLY} LIMIT 1`;

    const r = rows[0];
    if (!r) throw this.notFound();

    const shifts = await this.prisma.$queryRaw<ShiftRow[]>`
      SELECT day_of_week, specific_date, name_en, name_ar,
             opens_at, closes_at, spans_midnight
        FROM shifts
       WHERE restaurant_id = ${r.id}::uuid
         AND active = true
       ORDER BY day_of_week NULLS LAST, specific_date, opens_at`;

    // A second query rather than a join. The gallery is a list and the profile
    // is a row; joining them would multiply every profile column by the number
    // of photos and leave the caller to de-duplicate — which is how a venue
    // with eight photos becomes eight venues in somebody's map.
    const images = await this.images.forRestaurant(r.id);

    return {
      id: r.id,
      slug: r.slug,
      name_en: r.name_en,
      name_ar: r.name_ar,
      description_en: r.description_en,
      description_ar: r.description_ar,
      cuisines: r.cuisines ?? [],
      neighborhood: r.neighborhood,
      city: r.city,
      address_en: r.address_en,
      address_ar: r.address_ar,
      lat: r.lat === null ? null : Number(r.lat),
      lng: r.lng === null ? null : Number(r.lng),
      price_band: r.price_band === null ? null : Number(r.price_band),
      rating: Number(r.rating_avg ?? 0),
      rating_count: Number(r.rating_count ?? 0),
      phone: r.phone,
      website: r.website,
      amenities: amenityKeys(r.amenities),
      policies:
        r.policies && typeof r.policies === 'object' && !Array.isArray(r.policies)
          ? (r.policies as Record<string, unknown>)
          : null,
      timezone: r.timezone,
      booking_mode: r.booking_mode,
      images,
      hours: shifts.map((s) => ({
        day_of_week: s.day_of_week === null ? null : Number(s.day_of_week),
        specific_date: s.specific_date === null ? null : s.specific_date.toISOString().slice(0, 10),
        name_en: s.name_en,
        name_ar: s.name_ar,
        opens_at: hhmm(s.opens_at),
        closes_at: hhmm(s.closes_at),
        spans_midnight: s.spans_midnight,
      })),
    };
  }

  private notFound(): NotFoundException {
    return restaurantNotFound();
  }
}
