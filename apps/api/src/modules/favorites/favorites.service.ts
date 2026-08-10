import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { ImagesService, ImageView } from '../images/images.service';

/** A saved venue, in the shape a card needs. */
export interface SavedVenue {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  cuisines: string[];
  neighborhood: string | null;
  city: string;
  price_band: number | null;
  rating: number;
  rating_count: number;
  cover: ImageView | null;
  saved_at: string;
}

interface Row {
  id: string;
  slug: string;
  name_en: string;
  name_ar: string;
  cuisines: string[] | null;
  neighborhood: string | null;
  city: string;
  price_band: number | null;
  rating_avg: string | number;
  rating_count: number;
  saved_at: Date;
}

/**
 * C-2.7 — saved places.
 *
 * OWNERSHIP IS IN THE QUERY, never a check after the fact. `user_id = $me` is
 * part of every statement here, so there is no path that reads a row and then
 * decides whether the caller may have it — which is the shape that eventually
 * forgets to decide.
 */
@Injectable()
export class FavoritesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly images: ImagesService,
  ) {}

  /**
   * Save a venue. Returns whether this call is what created it.
   *
   * ── SAVING TWICE IS SAVING ONCE ─────────────────────────────────────────
   *
   * The unique index makes the second INSERT fail at the database. That is the
   * correct place for the rule to live — a service-level "check then insert"
   * has a window between the two statements, and a double tap on a slow
   * connection lands in it.
   *
   * So the collision is CAUGHT and turned into the answer the diner expects.
   * The boolean exists only so the controller can answer 201 the first time
   * and 200 afterwards; both are success, and the button looks the same.
   */
  async save(userId: string, restaurantId: string): Promise<{ created: boolean }> {
    const venue = await this.prisma.restaurant.findFirst({
      where: { id: restaurantId, deletedAt: null },
      select: { id: true },
    });
    if (!venue) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }

    try {
      await this.prisma.favorite.create({ data: { userId, restaurantId } });
      return { created: true };
    } catch (err) {
      // P2002 — unique constraint. Already saved, which is the state asked for.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        return { created: false };
      }
      throw err;
    }
  }

  /**
   * Unsave. **204 whether or not it was saved.**
   *
   * The button is a toggle, and a diner who taps it twice — or whose first tap
   * succeeded and whose response was lost — must not be shown an error for
   * arriving at the state they wanted. A 404 here would be technically
   * accurate and practically wrong.
   */
  async unsave(userId: string, restaurantId: string): Promise<void> {
    await this.prisma.favorite.deleteMany({ where: { userId, restaurantId } });
  }

  /**
   * The caller's saved venues, newest first.
   *
   * ONE QUERY, joined. The saved screen draws venue cards; a list of ids would
   * mean a request per row — twenty round trips over a Cairo mobile connection
   * before the first screenful can draw.
   */
  async list(userId: string): Promise<SavedVenue[]> {
    const rows = await this.prisma.$queryRaw<Row[]>`
      SELECT r.id, r.slug, r.name_en, r.name_ar, r.cuisines, r.neighborhood,
             r.city, r.price_band, r.rating_avg, r.rating_count,
             f.created_at AS saved_at
        FROM favorites f
        JOIN restaurants r ON r.id = f.restaurant_id
       WHERE f.user_id = ${userId}::uuid
         AND r.deleted_at IS NULL
       ORDER BY f.created_at DESC
       LIMIT 200`;

    // Covers for the whole page in one more query, not one per row.
    const covers = await this.images.coversFor(rows.map((r) => r.id));

    return rows.map((r) => ({
      id: r.id,
      slug: r.slug,
      name_en: r.name_en,
      name_ar: r.name_ar,
      cuisines: r.cuisines ?? [],
      neighborhood: r.neighborhood,
      city: r.city,
      price_band: r.price_band === null ? null : Number(r.price_band),
      rating: Number(r.rating_avg ?? 0),
      rating_count: Number(r.rating_count ?? 0),
      cover: covers.get(r.id) ?? null,
      saved_at: r.saved_at.toISOString(),
    }));
  }

  /**
   * Which of [restaurantIds] the caller has saved.
   *
   * For the search list's heart icons. One query for the page rather than a
   * boolean per row, same reason as the covers.
   */
  async savedIdsAmong(userId: string, restaurantIds: string[]): Promise<Set<string>> {
    if (restaurantIds.length === 0) return new Set();

    const rows = await this.prisma.favorite.findMany({
      where: { userId, restaurantId: { in: restaurantIds } },
      select: { restaurantId: true },
    });
    return new Set(rows.map((r) => r.restaurantId));
  }
}
