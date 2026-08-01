import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * Statuses that mean "a diner is still expecting this table".
 *
 * `expired`, `cancelled_*`, `no_show` and `completed` are settled — nothing an
 * owner does to the configuration can hurt them. Everything here is a live
 * promise, and every destructive edit in this module is guarded against them.
 */
export const LIVE_STATUSES = [
  'held',
  'pending',
  'confirmed',
  'seated',
] as const;

/**
 * Resolve a restaurant the caller actually owns.
 *
 * Deliberately the SAME error whether the venue does not exist or belongs to
 * somebody else — a distinguishable "forbidden" would let any owner enumerate
 * the platform's restaurants by id.
 */
export async function assertOwned(
  prisma: PrismaService,
  ownerId: string,
  restaurantId: string,
): Promise<{ id: string; timezone: string }> {
  const r = await prisma.restaurant.findFirst({
    where: { id: restaurantId, ownerId, deletedAt: null },
    select: { id: true, timezone: true },
  });
  if (!r) {
    throw new NotFoundException({
      code: 'restaurant_not_found',
      message: 'Restaurant not found.',
      message_ar: 'المطعم غير موجود.',
    });
  }
  return r;
}

/** Postgres TIME comes back as a Date pinned to 1970-01-01. */
export function hhmm(t: Date): string {
  return `${String(t.getUTCHours()).padStart(2, '0')}:${String(t.getUTCMinutes()).padStart(2, '0')}`;
}

/** "18:30" → the 1970-01-01 Date Postgres wants for a TIME column. */
export function toTime(value: string, code: string): Date {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  if (!m) {
    throw badRequest(code, `"${value}" must be a 24-hour HH:MM time.`, 'الوقت لازم يكون بصيغة HH:MM.');
  }
  return new Date(Date.UTC(1970, 0, 1, Number(m[1]), Number(m[2])));
}

export function minutesOf(value: string): number {
  const [h, m] = value.split(':').map(Number);
  return h * 60 + m;
}

export function badRequest(code: string, message: string, messageAr: string): Error {
  return new BadRequestException({ code, message, message_ar: messageAr });
}
