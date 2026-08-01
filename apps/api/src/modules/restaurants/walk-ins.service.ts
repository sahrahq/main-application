import { Injectable } from '@nestjs/common';
import { Reservation, ReservationSource, TableZone } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { ReservationsService } from '../reservations/reservations.service';
import { assertOwned, badRequest } from './venue-config.guards';

/**
 * Channels a member of staff may enter a booking on.
 *
 * `app` is excluded deliberately: letting staff write it would launder a
 * host-entered booking as a customer one, and the owner's book and the
 * analytics that follow both depend on being able to tell them apart.
 * `waitlist` and `admin` belong to flows that are not built.
 */
const STAFF_SOURCES = [ReservationSource.walk_in, ReservationSource.phone] as const;
export type StaffSource = (typeof STAFF_SOURCES)[number];

export interface CreateWalkInInput {
  partySize: number;
  /** A walk-in may have a name, a name and a phone, or neither. */
  guestName?: string | null;
  guestPhone?: string | null;
  /** Omitted for a party at the door; set for a phone booking. */
  startsAt?: Date;
  source?: StaffSource | string;
  seatingPref?: TableZone | string | null;
  specialRequests?: string | null;
  occasion?: string | null;
  idempotencyKey: string;
}

/**
 * Walk-ins and phone bookings (R-3.2 — "non-negotiable for adoption").
 *
 * Notice how little is here. That is the design, not an omission.
 *
 * doc 05 §7: "Walk-ins consume the same inventory through the same engine
 * path." A party seated off-platform is invisible to the engine, so the table
 * they are sitting at still looks free and the next app booking sends a second
 * party to it. The fix is not a careful second implementation of seating — a
 * parallel path would drift from the first one the day either changes. This
 * service resolves WHO is asking and WHAT channel it came from, then hands the
 * booking to `createHold`, which owns the advisory lock, the free-table
 * re-check inside it, and the EXCLUDE USING GIST constraint underneath.
 *
 * The only engine change walk-ins needed was one parameter,
 * `confirmImmediately`, because a party at the podium has no checkout to
 * abandon and so no reason to sit in a 5-minute hold.
 */
@Injectable()
export class WalkInsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reservations: ReservationsService,
  ) {}

  async create(
    ownerId: string,
    restaurantId: string,
    input: CreateWalkInInput,
  ): Promise<Reservation> {
    // Authorisation FIRST, before anything touches inventory — a caller with
    // no right to this venue must not be able to probe its availability by
    // watching which errors come back, nor leave a half-written row behind.
    await assertOwned(this.prisma, ownerId, restaurantId);

    const source = this.assertStaffSource(input.source);

    return this.reservations.createHold({
      restaurantId,
      // No customer account, and no fake user row invented to satisfy a
      // foreign key: `reservations.user_id` is already nullable precisely for
      // this case (doc 04 — "NULL for walk-in / phone bookings taken by
      // staff"), with guest_name / guest_phone alongside it.
      userId: null,
      guestName: input.guestName?.trim() || null,
      guestPhone: input.guestPhone?.trim() || null,
      partySize: input.partySize,
      // A walk-in is a party standing at the door; a phone booking names its
      // time. Defaulting to now keeps the host from having to type the clock.
      startsAt: input.startsAt ?? new Date(),
      seatingPref: (input.seatingPref as TableZone | null) ?? null,
      specialRequests: input.specialRequests ?? null,
      occasion: input.occasion ?? null,
      source,
      confirmImmediately: true,
      idempotencyKey: input.idempotencyKey,
    }) as Promise<Reservation>;
  }

  private assertStaffSource(value: string | undefined): StaffSource {
    if (value === undefined) return ReservationSource.walk_in;
    if ((STAFF_SOURCES as readonly string[]).includes(value)) return value as StaffSource;
    throw badRequest(
      'invalid_source',
      `source must be one of ${STAFF_SOURCES.join(', ')}.`,
      'نوع الحجز لازم يكون walk_in أو phone.',
    );
  }
}
