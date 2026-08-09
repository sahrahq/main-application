import {
  Body, Controller, Headers, HttpCode, Post, Param, ParseUUIDPipe, BadRequestException,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth, ApiHeader, ApiOkResponse, ApiOperation, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import { ReservationsService, HOLD_TTL_MINUTES } from './reservations.service';
import { CreateHoldDto } from './dto/create-hold.dto';
import { ConfirmHoldDto } from '../restaurants/dto/restaurant.dto';
import { ReservationResponse } from '../../shared/api/responses.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { isValidTimeZone, utcToZonedHhmm } from '../../shared/time/timezone';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * BOOKING REQUIRES AN ACCOUNT — doc 02 C-1.6, decided 2026-08-02.
 *
 * Browsing stays fully open: search, venue detail and real availability need
 * no token. The wall goes up at the booking ACTION and not before it.
 *
 * Why an identity is not optional here:
 *
 *   - without one the diner cannot see the booking again, cannot cancel it,
 *     and cannot be told when the venue cancels — the cancellation notice
 *     built in CANCEL-1 has nobody to reach
 *   - neither we nor the restaurant can tell a repeat diner from a serial
 *     no-show, and "is this guest a regular?" is one of the things venues are
 *     actually buying
 *
 * Sign-up is phone + OTP, about thirty seconds. That is the friction accepted;
 * the capability kept is the whole customer relationship.
 *
 * Walk-in and phone bookings (R-3.2) stay anonymous and are unaffected — they
 * enter through `WalkInsService`, which calls the engine directly rather than
 * through this controller.
 */
@ApiTags('reservations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reservations')
export class ReservationsController {
  constructor(
    private readonly reservations: ReservationsService,
    private readonly notifications: NotificationsService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Place a 5-minute hold on a table.
   *
   * Idempotency-Key is REQUIRED on every mutation (CLAUDE.md rule 2,
   * doc 06 §1). Replaying a key returns the original reservation instead of
   * creating a second one — which matters most exactly when the network is
   * bad and the client retries.
   */
  @Post('holds')
  @ApiOkResponse({ type: ReservationResponse })
  @HttpCode(201)
  @ApiOperation({ summary: `Hold a table for ${HOLD_TTL_MINUTES} minutes` })
  // `@ApiHeader` adds only the DESCRIPTION. The header parameter itself is in
  // the spec because `@Headers('idempotency-key')` is in the signature below —
  // @nestjs/swagger reads route argument metadata directly. Deleting this
  // decorator leaves the contract intact; deleting the parameter is what
  // changes it. That is the right way round: the spec follows the handler.
  @ApiHeader({ name: 'idempotency-key', required: true, description: 'Client-generated UUID v4' })
  @ApiResponse({ status: 201, description: 'Hold created' })
  @ApiResponse({ status: 409, description: 'slot_taken | pacing_limit_reached' })
  // The RETURN TYPE IS DECLARED, and that is not decoration.
  //
  // `@ApiOkResponse({ type: ReservationResponse })` tells the spec — and
  // therefore the generated Dart client — what comes back. Nothing was
  // checking that the object below actually matched it: this handler returned
  // neither `restaurantId` nor `source`, both declared required, and the
  // client's `ReservationResponse.fromJson` threw a null cast on the first
  // real booking. The e2e suite missed it because those tests assert on named
  // fields rather than on shape.
  //
  // Annotating the return type puts `tsc` on the same contract the decorator
  // advertises, so the next mismatch is a compile error in this file.
  async createHold(
    @Body() dto: CreateHoldDto,
    @CurrentUser() user: AuthedUser,
    @Headers('idempotency-key') idempotencyKey?: string,
  ): Promise<ReservationResponse> {
    if (!idempotencyKey || !UUID_RE.test(idempotencyKey)) {
      throw new BadRequestException({
        code: 'missing_idempotency_key',
        message: 'Idempotency-Key header must be a UUID v4.',
        message_ar: 'ترويسة Idempotency-Key لازم تكون UUID v4.',
      });
    }

    const r = await this.reservations.createHold({
      restaurantId: dto.restaurantId,
      // Guaranteed present by the guard, and by the DB constraint
      // `app_booking_has_diner` underneath it — the column was nullable, and
      // nullable is why nothing objected for weeks.
      userId: user.id,
      partySize: dto.partySize,
      startsAt: new Date(dto.startsAt),
      seatingPref: dto.seatingPref ?? null,
      guestName: dto.guestName ?? null,
      guestPhone: dto.guestPhone ?? null,
      specialRequests: dto.specialRequests ?? null,
      occasion: dto.occasion ?? null,
      idempotencyKey,
    });

    return {
      id: r.id,
      code: r.code,
      restaurantId: r.restaurantId,
      userId: r.userId,
      guestName: r.guestName,
      guestPhone: r.guestPhone,
      status: r.status,
      source: r.source,
      startsAt: r.startsAt.toISOString(),
      endsAt: r.endsAt.toISOString(),
      partySize: r.partySize,
      holdExpiresAt: r.holdExpiresAt?.toISOString() ?? null,
    };
  }

  /**
   * Confirm a hold within its 5-minute window (doc 06 §3).
   *
   * Idempotency-Key is required here too, and it must be a DIFFERENT key from
   * the one used on the hold — this is a separate mutation.
   */
  @Post('holds/:id/confirm')
  @ApiOkResponse({ type: ReservationResponse })
  @HttpCode(200)
  @ApiOperation({ summary: 'Confirm a held table' })
  @ApiHeader({ name: 'idempotency-key', required: true, description: 'Client-generated UUID v4' })
  @ApiResponse({ status: 200, description: 'Reservation confirmed' })
  @ApiResponse({ status: 409, description: 'hold_expired | invalid_status_transition' })
  @ApiResponse({ status: 404, description: 'reservation_not_found' })
  async confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfirmHoldDto,
    @CurrentUser() user: AuthedUser,
    @Headers('idempotency-key') idempotencyKey?: string,
  ): Promise<ReservationResponse> {
    if (!idempotencyKey || !UUID_RE.test(idempotencyKey)) {
      throw new BadRequestException({
        code: 'missing_idempotency_key',
        message: 'Idempotency-Key header must be a UUID v4.',
        message_ar: 'ترويسة Idempotency-Key لازم تكون UUID v4.',
      });
    }

    const r = await this.reservations.confirmHold({
      holdId: id,
      // `confirmHold` refuses to let one diner confirm another's hold. It has
      // always been able to; nothing was ever telling it who was asking — so
      // with an unauthenticated confirm, a guessed hold id would have
      // committed somebody else's table.
      userId: user.id,
      specialRequests: dto.specialRequests ?? null,
      occasion: dto.occasion ?? null,
      idempotencyKey,
    });

    // C-4.7 — THE RECEIPT, IN THE CENTRE.
    //
    // The confirmation screen already tells them, so this is not the diner
    // learning something new. It is the notification centre being able to
    // answer "what happened on my account?" without a hole where the most
    // important event is — a centre that lists cancellations and reminders but
    // not the booking they refer to reads as broken.
    //
    // DEDUPED ON THE RESERVATION. Confirm is idempotent (doc 06 §1) and a
    // replayed key returns the same reservation without re-writing it; without
    // a dedupe key a retried confirm would still record a second receipt.
    //
    // After the commit, and unable to undo it: `notify` does not throw.
    //
    // One PK lookup for the venue's names and timezone, outside the
    // transaction. The names are in the payload because both the lock screen
    // and the centre need something to call the place, and the centre must not
    // fetch a venue per row. The timezone is because a booking that says 19:00
    // on the confirmation and 17:00 in the centre is a support ticket.
    const venue = await this.prisma.restaurant.findUnique({
      where: { id: r.restaurantId },
      select: { nameEn: true, nameAr: true, timezone: true },
    });
    const tz = isValidTimeZone(venue?.timezone ?? '') ? venue!.timezone : 'Africa/Cairo';

    await this.notifications.notify({
      userId: user.id,
      type: 'reservation_confirmed',
      data: {
        reservation_id: r.id,
        code: r.code,
        restaurant_id: r.restaurantId,
        venue: venue?.nameEn ?? '',
        venue_ar: venue?.nameAr ?? '',
        starts_at: r.startsAt.toISOString(),
        date: r.startsAt.toISOString().slice(0, 10),
        time: utcToZonedHhmm(r.startsAt, tz),
        party: String(r.partySize),
      },
      dedupeKey: `reservation_confirmed:${r.id}`,
    });

    return {
      id: r.id,
      code: r.code,
      restaurantId: r.restaurantId,
      userId: r.userId,
      guestName: r.guestName,
      guestPhone: r.guestPhone,
      status: r.status,
      source: r.source,
      startsAt: r.startsAt.toISOString(),
      endsAt: r.endsAt.toISOString(),
      partySize: r.partySize,
      // Confirmed: the hold window is over, so there is no expiry left to
      // report. Explicitly null rather than absent — the field is declared.
      holdExpiresAt: null,
    };
  }
}
