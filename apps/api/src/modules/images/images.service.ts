import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ImageOwnerType, ImageStatus } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../shared/prisma/prisma.service';
import {
  ACCEPTED_MIME,
  IMAGE_FORMAT,
  IMAGE_PROCESSOR,
  IMAGE_SIZES,
  IMAGE_STORAGE,
  ImageProcessor,
  ImageSize,
  ImageStorage,
  MAX_UPLOAD_BYTES,
  originalKey,
  renditionKey,
} from './image.ports';

/** One image, as every read serves it. */
export interface ImageView {
  id: string;
  /** size → public URL. The client picks; it never builds one. */
  urls: Record<string, string>;
  width: number;
  height: number;
  position: number;
  is_cover: boolean;
}

@Injectable()
export class ImagesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(IMAGE_PROCESSOR) private readonly processor: ImageProcessor,
    @Inject(IMAGE_STORAGE) private readonly storage: ImageStorage,
  ) {}

  /**
   * Add a photo to a restaurant.
   *
   * ── THE ORDER OF OPERATIONS, WHICH IS THE WHOLE DESIGN ─────────────────
   *
   * Resize → store → THEN write the row. The row is the last thing to exist,
   * so there is no window in which the database advertises an image whose
   * bytes are not in the bucket yet. The opposite order — row first, bytes
   * after — produces a venue page with a broken image and a row nothing can
   * distinguish from a healthy one.
   *
   * The cost of this order is the mirror failure: bytes stored with no row, if
   * the insert fails. Those are orphans in a bucket, invisible to every diner,
   * and cheap to sweep. Choosing which way to fail is the decision; failing
   * towards "invisible and cheap" rather than "visible and broken" is the
   * answer.
   */
  async addRestaurantImage(input: {
    restaurantId: string;
    body: Buffer;
    mimeType: string;
    /** Make this the venue's hero. The previous cover is demoted. */
    cover?: boolean;
  }): Promise<ImageView> {
    if (input.body.length === 0) {
      throw new BadRequestException({
        code: 'invalid_image',
        message: 'That file is empty.',
        message_ar: 'الملف فاضي.',
      });
    }

    if (input.body.length > MAX_UPLOAD_BYTES) {
      throw new BadRequestException({
        code: 'image_too_large',
        message: `Images must be under ${Math.round(MAX_UPLOAD_BYTES / 1024 / 1024)} MB.`,
        message_ar: `الصورة لازم تكون أقل من ${Math.round(MAX_UPLOAD_BYTES / 1024 / 1024)} ميجا.`,
      });
    }

    // DENY BY DEFAULT. `sharp` opens SVG and PDF happily, and an SVG is a
    // script-execution vector the moment anything renders it as markup.
    if (!(ACCEPTED_MIME as readonly string[]).includes(input.mimeType)) {
      throw new BadRequestException({
        code: 'unsupported_image_type',
        message: 'Upload a JPEG, PNG or WebP.',
        message_ar: 'ارفع صورة JPEG أو PNG أو WebP.',
        details: [{ field: 'file', issue: input.mimeType }],
      });
    }

    const restaurant = await this.prisma.restaurant.findFirst({
      where: { id: input.restaurantId, deletedAt: null },
      select: { id: true },
    });
    if (!restaurant) {
      throw new NotFoundException({
        code: 'restaurant_not_found',
        message: 'Restaurant not found.',
        message_ar: 'المطعم غير موجود.',
      });
    }

    const id = randomUUID();
    const baseKey = `restaurants/${input.restaurantId}/${id}`;

    const processed = await this.processor.process(input.body);

    for (const rendition of processed.renditions) {
      await this.storage.put(
        renditionKey(baseKey, rendition.size),
        rendition.body,
        `image/${IMAGE_FORMAT}`,
      );
    }
    // Kept, never served. See `originalKey`.
    await this.storage.put(originalKey(baseKey), processed.original, input.mimeType);

    // Appended at the end of the existing order rather than inserted, so
    // uploading a photo never silently reshuffles the ones already there.
    const last = await this.prisma.image.findFirst({
      where: { ownerType: ImageOwnerType.restaurant, ownerId: input.restaurantId },
      orderBy: { position: 'desc' },
      select: { position: true },
    });
    const position = last === null ? 0 : last.position + 1;

    // FIRST PHOTO IS THE COVER, automatically. A venue with photos and no
    // cover renders an empty hero above a full gallery, which reads as broken
    // rather than as unconfigured — and nobody uploading the first photo of a
    // venue means "but not as the main one".
    const isCover = input.cover === true || last === null;

    // Both writes in one transaction: demoting the old cover and promoting the
    // new one must not be separable, or a failure between them leaves a venue
    // with no cover at all — which the partial unique index permits and the
    // hero cannot render.
    await this.prisma.$transaction(async (tx) => {
      if (isCover) {
        await tx.image.updateMany({
          where: {
            ownerType: ImageOwnerType.restaurant,
            ownerId: input.restaurantId,
            isCover: true,
          },
          data: { isCover: false },
        });
      }

      await tx.image.create({
        data: {
          id,
          ownerType: ImageOwnerType.restaurant,
          ownerId: input.restaurantId,
          url: baseKey,
          width: processed.width,
          height: processed.height,
          position,
          isCover,
          // Set at the end, so a row is only ever `ready` once its bytes are
          // stored. Nothing serves a `processing` row.
          status: ImageStatus.ready,
        },
      });
    });

    return {
      id,
      urls: this.urlsFor(baseKey),
      width: processed.width,
      height: processed.height,
      position,
      is_cover: isCover,
    };
  }

  /** Every ready image for a venue, in the order the owner set. */
  async forRestaurant(restaurantId: string): Promise<ImageView[]> {
    const rows = await this.prisma.image.findMany({
      where: {
        ownerType: ImageOwnerType.restaurant,
        ownerId: restaurantId,
        status: ImageStatus.ready,
      },
      orderBy: [{ isCover: 'desc' }, { position: 'asc' }],
    });

    return rows.map((r) => ({
      id: r.id,
      urls: this.urlsFor(r.url),
      width: r.width,
      height: r.height,
      position: r.position,
      is_cover: r.isCover,
    }));
  }

  /** Covers for many venues at once — the search list's N+1 guard. */
  async coversFor(restaurantIds: string[]): Promise<Map<string, ImageView>> {
    if (restaurantIds.length === 0) return new Map();

    const rows = await this.prisma.image.findMany({
      where: {
        ownerType: ImageOwnerType.restaurant,
        ownerId: { in: restaurantIds },
        isCover: true,
        status: ImageStatus.ready,
      },
    });

    return new Map(
      rows.map((r) => [
        r.ownerId,
        {
          id: r.id,
          urls: this.urlsFor(r.url),
          width: r.width,
          height: r.height,
          position: r.position,
          is_cover: r.isCover,
        },
      ]),
    );
  }

  /**
   * Images by id, for the callers that already hold a foreign key to one.
   *
   * `menu_items.image_id` is the only real FK into this table — the other three
   * owner types are polymorphic and read the other way, by owner. One lookup
   * for every dish on a menu page rather than one per dish.
   *
   * NOT filtered by `ownerType`. The caller holds a foreign key the database
   * enforced; re-deriving what kind of thing it points at here would be a
   * second opinion about a fact that is already settled.
   */
  async byIds(ids: string[]): Promise<Map<string, ImageView>> {
    if (ids.length === 0) return new Map();

    const rows = await this.prisma.image.findMany({
      where: { id: { in: ids }, status: ImageStatus.ready },
    });

    return new Map(
      rows.map((r) => [
        r.id,
        {
          id: r.id,
          urls: this.urlsFor(r.url),
          width: r.width,
          height: r.height,
          position: r.position,
          is_cover: r.isCover,
        },
      ]),
    );
  }

  /** Remove an image and every rendition of it. */
  async remove(id: string): Promise<void> {
    const image = await this.prisma.image.findUnique({ where: { id } });
    if (!image) {
      throw new NotFoundException({
        code: 'image_not_found',
        message: 'Image not found.',
        message_ar: 'الصورة غير موجودة.',
      });
    }

    // Row first here, and deliberately the opposite order from upload. A row
    // without bytes renders broken; bytes without a row are invisible. Both
    // orders leak the same way on failure, so both choose the invisible leak.
    await this.prisma.image.delete({ where: { id } });
    await this.storage.remove(image.url);

    // A venue whose COVER was deleted has photos and no hero. Promote the
    // next one rather than leaving the gallery headless.
    if (image.isCover) {
      const next = await this.prisma.image.findFirst({
        where: { ownerType: image.ownerType, ownerId: image.ownerId },
        orderBy: { position: 'asc' },
      });
      if (next) {
        await this.prisma.image.update({
          where: { id: next.id },
          data: { isCover: true },
        });
      }
    }
  }

  /**
   * Every rendition's public address, keyed by width.
   *
   * COMPOSED HERE, never by the client. The bucket, the CDN in front of it and
   * the path convention are deployment concerns; a client that built these
   * itself would need a release the day any of them moved.
   */
  private urlsFor(baseKey: string): Record<string, string> {
    const urls: Record<string, string> = {};
    for (const size of IMAGE_SIZES) {
      urls[String(size)] = this.storage.publicUrl(renditionKey(baseKey, size as ImageSize));
    }
    return urls;
  }
}
