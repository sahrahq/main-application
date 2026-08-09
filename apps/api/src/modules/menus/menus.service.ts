import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { LiveRestaurantResolver } from '../restaurants/live-restaurant';
import { ImagesService, ImageView } from '../images/images.service';
import { IMAGE_STORAGE, ImageStorage } from '../images/image.ports';
import { Inject } from '@nestjs/common';

export interface PublicMenuItem {
  id: string;
  name_en: string;
  name_ar: string;
  description_en: string | null;
  description_ar: string | null;
  /** A decimal STRING, never a float. See the class doc. */
  price: string;
  currency: string;
  dietary_tags: string[];
  image: ImageView | null;
}

export interface PublicMenuCategory {
  id: string;
  name_en: string;
  name_ar: string;
  items: PublicMenuItem[];
}

export interface PublicMenu {
  id: string;
  name_en: string;
  name_ar: string;
  kind: string;
  /** Composed here from `pdf_key`; null when the venue has no PDF. */
  pdf_url: string | null;
  categories: PublicMenuCategory[];
}

interface MenuRow {
  id: string;
  name_en: string;
  name_ar: string;
  kind: string;
  pdf_key: string | null;
}

interface CategoryRow {
  id: string;
  menu_id: string;
  name_en: string;
  name_ar: string;
}

interface ItemRow {
  id: string;
  category_id: string;
  name_en: string;
  name_ar: string;
  description_en: string | null;
  description_ar: string | null;
  price: string;
  currency: string;
  dietary_tags: string[] | null;
  image_id: string | null;
}

/**
 * R-2.3 / C-2.6 — a venue's menus, for the diner.
 *
 * ── MONEY LEAVES HERE AS A STRING ────────────────────────────────────────
 *
 * `price` is `NUMERIC(12,2)`, and `JSON.stringify(Number(...))` is where that
 * stops being true. 0.1 + 0.2 is the famous example; the one that matters here
 * is that a JSON number has no way to say "two decimal places" — a price of
 * 320.00 serializes as `320` and a client that formats it back gets `320`
 * where the menu says `320.00`. Prisma already hands `Decimal` over rather
 * than a float, and this keeps it that way to the wire.
 *
 * CLAUDE.md rule 5: "money is NUMERIC(12,2) + currency, never floats." A float
 * on the wire is still a float.
 *
 * ── AND UNAVAILABLE ITEMS ARE NOT SENT ───────────────────────────────────
 *
 * `available = false` is how a venue says the sea bass is off tonight. Sending
 * it with a flag would put the decision on four different clients; sending a
 * dish a diner cannot order is worse than a shorter menu. An owner deleting
 * the row is a different act with a different meaning, which is why the
 * column exists at all.
 */
@Injectable()
export class MenusService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly live: LiveRestaurantResolver,
    private readonly images: ImagesService,
    @Inject(IMAGE_STORAGE) private readonly storage: ImageStorage,
  ) {}

  /**
   * Every active menu for a live venue, ordered, with its categories and
   * available items.
   *
   * THREE QUERIES, NOT A NESTED INCLUDE. A join across menu → category → item
   * multiplies the menu row by the number of items and hands the caller a
   * result set to de-duplicate. Three flat reads, each already ordered by its
   * index, then assembled in memory — a menu is tens of rows, not thousands.
   */
  async forRestaurant(idOrSlug: string): Promise<PublicMenu[]> {
    const restaurantId = await this.live.resolveId(idOrSlug);

    const menus = await this.prisma.$queryRaw<MenuRow[]>`
      SELECT id, name_en, name_ar, kind::text AS kind, pdf_key
        FROM menus
       WHERE restaurant_id = ${restaurantId}::uuid AND active = true
       ORDER BY position, name_en`;

    if (menus.length === 0) return [];

    const menuIds = menus.map((m) => m.id);

    const categories = await this.prisma.$queryRaw<CategoryRow[]>`
      SELECT id, menu_id, name_en, name_ar
        FROM menu_categories
       WHERE menu_id = ANY(${menuIds}::uuid[])
       ORDER BY position, name_en`;

    const categoryIds = categories.map((c) => c.id);

    const items = categoryIds.length === 0
      ? []
      : await this.prisma.$queryRaw<ItemRow[]>`
          SELECT id, category_id, name_en, name_ar,
                 description_en, description_ar,
                 price::text AS price, currency, dietary_tags, image_id
            FROM menu_items
           WHERE category_id = ANY(${categoryIds}::uuid[])
             AND available = true
           ORDER BY position, name_en`;

    // One lookup for every dish photo on the page rather than one per dish.
    const imageIds = items.map((i) => i.image_id).filter((v): v is string => v !== null);
    const imagesById = await this.images.byIds(imageIds);

    const itemsByCategory = new Map<string, PublicMenuItem[]>();
    for (const i of items) {
      const list = itemsByCategory.get(i.category_id) ?? [];
      list.push({
        id: i.id,
        name_en: i.name_en,
        name_ar: i.name_ar,
        description_en: i.description_en,
        description_ar: i.description_ar,
        price: i.price,
        currency: i.currency,
        dietary_tags: i.dietary_tags ?? [],
        image: i.image_id ? imagesById.get(i.image_id) ?? null : null,
      });
      itemsByCategory.set(i.category_id, list);
    }

    const categoriesByMenu = new Map<string, PublicMenuCategory[]>();
    for (const c of categories) {
      const items = itemsByCategory.get(c.id) ?? [];
      // A CATEGORY WITH NOTHING ORDERABLE IN IT IS NOT SHOWN. Every item being
      // unavailable is the same fact as the category being off tonight, and a
      // heading with nothing under it reads as a screen that failed to load.
      if (items.length === 0) continue;
      const list = categoriesByMenu.get(c.menu_id) ?? [];
      list.push({ id: c.id, name_en: c.name_en, name_ar: c.name_ar, items });
      categoriesByMenu.set(c.menu_id, list);
    }

    return menus
      .map((m) => ({
        id: m.id,
        name_en: m.name_en,
        name_ar: m.name_ar,
        kind: m.kind,
        pdf_url: m.pdf_key ? this.storage.publicUrl(m.pdf_key) : null,
        categories: categoriesByMenu.get(m.id) ?? [],
      }))
      // A MENU WITH NO CATEGORIES SURVIVES ONLY IF IT HAS A PDF, which is the
      // R-2.3 fallback: a venue whose whole menu is one scanned file has no
      // rows here and still has something to show. Without the PDF it is an
      // empty menu, and an empty menu is not a menu.
      .filter((m) => m.categories.length > 0 || m.pdf_url !== null);
  }
}
