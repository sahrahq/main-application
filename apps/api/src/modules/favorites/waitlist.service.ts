import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, WaitlistStatus } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';

export interface WaitlistEntry {
  id: string;
  status: string;
  desired_date: string;
  window_start: string;
  window_end: string;
  party_size: number;
  offer_expires_at: string | null;
  restaurant: {
    id: string;
    slug: string;
    name_en: string;
    name_ar: string;
    city: string;
    neighborhood: string | null;
  };
}

/** Statuses that occupy a place in the queue. Mirrors `idx_wait_no_duplicates`. */
const LIVE: WaitlistStatus[] = [WaitlistStatus.waiting, WaitlistStatus.offered];

/**
 * C-3.6 — the waitlist a diner joins when a venue is full. **The JOIN half.**
 *
 * ── WHAT CHANGED IN GROUP G ──────────────────────────────────────────────
 *
 * This docblock said, for two batches, "**nothing here offers anybody a
 * table**". That is no longer true, and the sentence is replaced rather than
 * softened — a stale "not built yet" is worse than none, because the next
 * reader trusts it and stops looking.
 *
 * `WaitlistOfferService` now offers a freed table to the top matching entry and
 * records a notification, hooked into all three paths that free inventory. The
 * offer engine is there, not here: this class owns joining and leaving, and a
 * queue that also serves itself is two features in one file.
 *
 * ── WHAT IS STILL NOT TRUE, SAID JUST AS PLAINLY ─────────────────────────
 *
 * **An offer reaches nobody.** The notification is recorded and the diner sees
 * it only if they open the app — push is blocked on the Firebase project
 * (`docs/decisions/2026-08-09-firebase-handover.md`).
 *
 * **And an offer withholds nothing.** doc 05 §5's ten-minute claim window is
 * not enforced: anybody may take that table in the meantime. Argued in
 * `docs/decisions/2026-08-09-group-g-split.md` §3.1, asserted in
 * `waitlist-offer.e2e-spec.ts`, and the reason the copy says "first come, first
 * served" rather than doc 11's "claim in 10 min".
 *
 * The `offered` status, `offer_expires_at` and `priority` all existed before
 * there was anything to use them, because a sweeper is easier to add to a
 * schema that already says what it means than to retrofit.
 */
@Injectable()
export class WaitlistService {
  constructor(private readonly prisma: PrismaService) {}

  async join(input: {
    userId: string;
    restaurantId: string;
    desiredDate: string;
    windowStart: Date;
    windowEnd: Date;
    partySize: number;
  }): Promise<WaitlistEntry> {
    if (input.windowEnd <= input.windowStart) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'The end of the window must be after the start.',
        message_ar: 'نهاية المدة لازم تكون بعد بدايتها.',
        details: [{ field: 'windowEnd', issue: 'before_start' }],
      });
    }

    // A day that has gone cannot be waited for. Checked on the DATE rather
    // than the window, because a diner joining at 21:00 for tonight's 19:00
    // slot is asking for something that already happened.
    const today = new Date().toISOString().slice(0, 10);
    if (input.desiredDate < today) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Pick a date in the future.',
        message_ar: 'اختر تاريخ في المستقبل.',
        details: [{ field: 'desiredDate', issue: 'past' }],
      });
    }

    const venue = await this.prisma.restaurant.findFirst({
      where: { id: input.restaurantId, deletedAt: null },
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
      const row = await this.prisma.waitlist.create({
        data: {
          userId: input.userId,
          restaurantId: input.restaurantId,
          desiredDate: new Date(`${input.desiredDate}T00:00:00.000Z`),
          windowStart: input.windowStart,
          windowEnd: input.windowEnd,
          partySize: input.partySize,
        },
        include: { restaurant: true },
      });
      return toEntry(row);
    } catch (err) {
      // The PARTIAL unique index. A settled entry does not block; a live one
      // does, and this is that refusal.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        throw new ConflictException({
          code: 'already_on_waitlist',
          message: "You're already on the list for that night.",
          message_ar: 'إنت بالفعل في قائمة الانتظار لليلة دي.',
        });
      }
      throw err;
    }
  }

  /** The caller's live entries, soonest first. */
  async list(userId: string): Promise<WaitlistEntry[]> {
    const rows = await this.prisma.waitlist.findMany({
      where: { userId, status: { in: LIVE } },
      include: { restaurant: true },
      orderBy: { desiredDate: 'asc' },
      take: 100,
    });
    return rows.map(toEntry);
  }

  /**
   * Leave the queue.
   *
   * CANCELLED, NOT DELETED. The row is the evidence that somebody wanted a
   * table that night, which is exactly what a venue wants to know when it
   * decides whether to add a seating — and deleting it would erase demand data
   * to save forty bytes. The partial unique index is what lets the row stay
   * without blocking a re-join.
   *
   * 404 for another diner's entry, matching every other owned resource here.
   */
  async leave(userId: string, id: string): Promise<void> {
    const changed = await this.prisma.waitlist.updateMany({
      where: { id, userId, status: { in: LIVE } },
      data: { status: WaitlistStatus.cancelled, offerExpiresAt: null },
    });

    if (changed.count === 0) {
      throw new NotFoundException({
        code: 'waitlist_entry_not_found',
        message: 'We could not find that waitlist entry.',
        message_ar: 'مش لاقيين طلب الانتظار ده.',
      });
    }
  }
}

interface RowWithVenue {
  id: string;
  status: WaitlistStatus;
  desiredDate: Date;
  windowStart: Date;
  windowEnd: Date;
  partySize: number;
  offerExpiresAt: Date | null;
  restaurant: {
    id: string;
    slug: string;
    nameEn: string;
    nameAr: string;
    city: string;
    neighborhood: string | null;
  };
}

function toEntry(row: RowWithVenue): WaitlistEntry {
  return {
    id: row.id,
    status: row.status,
    desired_date: row.desiredDate.toISOString().slice(0, 10),
    window_start: row.windowStart.toISOString(),
    window_end: row.windowEnd.toISOString(),
    party_size: row.partySize,
    offer_expires_at: row.offerExpiresAt?.toISOString() ?? null,
    restaurant: {
      id: row.restaurant.id,
      slug: row.restaurant.slug,
      name_en: row.restaurant.nameEn,
      name_ar: row.restaurant.nameAr,
      city: row.restaurant.city,
      neighborhood: row.restaurant.neighborhood,
    },
  };
}
