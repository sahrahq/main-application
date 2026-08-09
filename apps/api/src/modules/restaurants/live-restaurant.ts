import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * ONE DEFINITION OF "A VENUE THE PUBLIC CAN SEE".
 *
 * `public-restaurants.service.ts` had this inline and said why the predicate is
 * repeated across its two lookups: "an inactive or soft-deleted venue must be
 * invisible on EVERY path, and a shared predicate that one caller forgets is
 * how a suspended listing comes back to life."
 *
 * That argument is about two queries in one file, where both are visible at
 * once. Group D adds two more public reads in two more modules — menus and
 * reviews — and at four copies in three files the same argument points the
 * other way: the copy somebody forgets is now in a file they are not looking
 * at. So the predicate moves here and the callers share it.
 *
 * A suspended venue's menu and reviews must vanish with its profile. If they
 * did not, the platform would be publishing the prices and the reputation of a
 * restaurant it has taken off the platform.
 */
export const LIVE_ONLY = Prisma.sql`AND r.status = 'active' AND r.deleted_at IS NULL`;

export const SLUG_RE = /^[a-z0-9][a-z0-9-]{0,79}$/;
export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function restaurantNotFound(): NotFoundException {
  return new NotFoundException({
    code: 'restaurant_not_found',
    message: 'We could not find that restaurant.',
    message_ar: 'مش لاقيين المطعم ده.',
  });
}

/**
 * Resolve an id-or-slug to a live restaurant's id, or 404.
 *
 * For the callers that need only the id — a menu or a review list does not
 * want the profile's twenty columns. `profile()` keeps its single query rather
 * than calling this and then fetching, because the round trip would double for
 * no gain there.
 *
 * A venue that exists but is not `active` is a 404, not a 403, for the reason
 * spelled out on `profile()`: a 403 confirms the row exists and turns this into
 * an enumeration oracle for unlaunched venues.
 */
@Injectable()
export class LiveRestaurantResolver {
  constructor(private readonly prisma: PrismaService) {}

  async resolveId(idOrSlug: string): Promise<string> {
    const isUuid = UUID_RE.test(idOrSlug);
    if (!isUuid && !SLUG_RE.test(idOrSlug)) throw restaurantNotFound();

    const rows = isUuid
      ? await this.prisma.$queryRaw<{ id: string }[]>`
          SELECT r.id FROM restaurants r WHERE r.id = ${idOrSlug}::uuid ${LIVE_ONLY} LIMIT 1`
      : await this.prisma.$queryRaw<{ id: string }[]>`
          SELECT r.id FROM restaurants r WHERE r.slug = ${idOrSlug} ${LIVE_ONLY} LIMIT 1`;

    const id = rows[0]?.id;
    if (!id) throw restaurantNotFound();
    return id;
  }
}
