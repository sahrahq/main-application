import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { Prisma, RestaurantStatus } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';

export interface CreateRestaurantInput {
  nameEn: string;
  nameAr: string;
  cuisines?: string[];
  city?: string;
  neighborhood?: string;
  /** WGS84. PostGIS stores POINT(lng lat) — longitude first. */
  lat: number;
  lng: number;
  slotIntervalMin?: number;
  descriptionEn?: string;
  descriptionAr?: string;
  priceBand?: number;
  bookingMode?: 'instant' | 'request';
}

export type UpdateRestaurantInput = Partial<
  Pick<
    CreateRestaurantInput,
    'nameEn' | 'nameAr' | 'descriptionEn' | 'descriptionAr' | 'cuisines' |
    'neighborhood' | 'city' | 'priceBand' | 'slotIntervalMin' | 'bookingMode'
  >
>;

export interface RestaurantRow {
  id: string;
  slug: string;
  status: RestaurantStatus;
  nameEn: string;
  nameAr: string;
  descriptionEn: string | null;
  descriptionAr: string | null;
  priceBand: number | null;
  city: string;
  neighborhood: string | null;
}

const SELECT = {
  id: true, slug: true, status: true, nameEn: true, nameAr: true,
  descriptionEn: true, descriptionAr: true, priceBand: true,
  city: true, neighborhood: true,
} satisfies Prisma.RestaurantSelect;

@Injectable()
export class RestaurantsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Create a restaurant (doc 06 §4). Always lands in `draft` — a venue must
   * never be bookable the instant it is created; it goes through
   * submit → admin approve first.
   *
   * `location` is PostGIS and unsupported by Prisma's client, so the INSERT is
   * raw. Note ST_MakePoint takes (lng, lat) — reversing them silently puts
   * every Cairo restaurant in the Indian Ocean, and no type will catch it.
   */
  async create(ownerId: string, input: CreateRestaurantInput): Promise<RestaurantRow> {
    const slug = await this.uniqueSlug(input.nameEn);

    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO restaurants (
        owner_id, slug, name_en, name_ar, description_en, description_ar,
        cuisines, city, neighborhood, location, price_band, booking_mode,
        slot_interval_min, status, created_at, updated_at
      ) VALUES (
        ${ownerId}::uuid, ${slug}, ${input.nameEn}, ${input.nameAr},
        ${input.descriptionEn ?? null}, ${input.descriptionAr ?? null},
        ${input.cuisines ?? []}::text[],
        ${input.city ?? 'Cairo'}, ${input.neighborhood ?? null},
        ST_SetSRID(ST_MakePoint(${input.lng}, ${input.lat}), 4326)::geography,
        ${input.priceBand ?? null}::smallint,
        ${input.bookingMode ?? 'instant'}::booking_mode,
        ${input.slotIntervalMin ?? 30}::smallint,
        'draft'::restaurant_status, now(), now()
      )
      RETURNING id`;

    return this.prisma.restaurant.findUniqueOrThrow({
      where: { id: rows[0].id },
      select: SELECT,
    });
  }

  async listMine(ownerId: string): Promise<RestaurantRow[]> {
    return this.prisma.restaurant.findMany({
      where: { ownerId, deletedAt: null },
      select: SELECT,
      orderBy: { createdAt: 'desc' },
    });
  }

  async getOwned(ownerId: string, restaurantId: string): Promise<RestaurantRow> {
    const r = await this.prisma.restaurant.findFirst({
      where: { id: restaurantId, ownerId, deletedAt: null },
      select: SELECT,
    });
    // Deliberately the same error whether it does not exist or belongs to
    // someone else — otherwise this endpoint enumerates other owners' venues.
    if (!r) throw this.notFound();
    return r;
  }

  async update(
    ownerId: string,
    restaurantId: string,
    input: UpdateRestaurantInput,
  ): Promise<RestaurantRow> {
    await this.getOwned(ownerId, restaurantId);
    return this.prisma.restaurant.update({
      where: { id: restaurantId },
      data: { ...input },
      select: SELECT,
    });
  }

  /**
   * draft → pending_review (doc 06 §4).
   *
   * Guarded as a state machine rather than a blind write: re-submitting an
   * already-queued venue would otherwise reset its place in the admin queue,
   * and submitting a live venue would take it off the platform.
   */
  async submitForReview(ownerId: string, restaurantId: string): Promise<RestaurantRow> {
    const current = await this.getOwned(ownerId, restaurantId);

    if (current.status !== RestaurantStatus.draft) {
      throw new ConflictException({
        code: 'invalid_status_transition',
        message: `A restaurant can only be submitted from draft (this one is ${current.status}).`,
        message_ar: 'لا يمكن إرسال المطعم للمراجعة إلا وهو في حالة مسودة.',
      });
    }

    return this.prisma.restaurant.update({
      where: { id: restaurantId },
      data: { status: RestaurantStatus.pending_review },
      select: SELECT,
    });
  }

  /** URL-safe slug, de-duplicated with a short suffix. */
  private async uniqueSlug(nameEn: string): Promise<string> {
    const base =
      nameEn
        .toLowerCase()
        .normalize('NFKD')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 60) || 'restaurant';

    if (!(await this.prisma.restaurant.findUnique({ where: { slug: base }, select: { id: true } }))) {
      return base;
    }
    for (let i = 0; i < 50; i++) {
      const candidate = `${base}-${Math.random().toString(36).slice(2, 7)}`;
      const clash = await this.prisma.restaurant.findUnique({
        where: { slug: candidate },
        select: { id: true },
      });
      if (!clash) return candidate;
    }
    throw new ConflictException({
      code: 'slug_unavailable',
      message: 'Could not allocate a unique URL for that name.',
      message_ar: 'تعذّر إنشاء رابط فريد لهذا الاسم.',
    });
  }

  private notFound(): NotFoundException {
    return new NotFoundException({
      code: 'restaurant_not_found',
      message: 'Restaurant not found.',
      message_ar: 'المطعم غير موجود.',
    });
  }
}
