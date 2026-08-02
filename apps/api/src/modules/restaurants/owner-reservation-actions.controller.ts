import {
  Body, Controller, ForbiddenException, HttpCode, Param, ParseUUIDPipe, Post, UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { OwnerCancellationService } from './owner-cancellation.service';
import { CancelReservationDto } from './dto/cancel-reservation.dto';
import { CancelledReservationResponse } from '../../shared/api/responses.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { isValidTimeZone, utcToZonedHhmm } from '../../shared/time/timezone';

/**
 * doc 06 §4 — actions on a single reservation, from the venue's side.
 *
 * `/owner/reservations/:id/...` rather than
 * `/owner/restaurants/:rid/reservations/:id/...`: the reservation id already
 * determines the venue, and asking the caller to supply both invites the two
 * to disagree — at which point some handler has to decide which one wins.
 * Ownership is derived from the token and the reservation, never from a path
 * segment the caller controls.
 */
@ApiTags('owner:reservations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('owner/reservations')
export class OwnerReservationActionsController {
  constructor(
    private readonly cancellation: OwnerCancellationService,
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Ownership comes from the TOKEN, never from the request. */
  private async ownerIdOf(user: AuthedUser): Promise<string> {
    const owner = await this.prisma.restaurantOwner.findUnique({
      where: { userId: user.id },
      select: { id: true },
    });
    if (!owner) {
      throw new ForbiddenException({
        code: 'not_an_owner',
        message: 'This account is not registered as a restaurant owner.',
        message_ar: 'هذا الحساب غير مسجّل كصاحب مطعم.',
      });
    }
    return owner.id;
  }

  /**
   * The venue cancels a booking.
   *
   * NOT the diner-cancel route. Diner cancellation is C-3.5 and carries its
   * own policy, refund rules and no-show accounting; routing it through here
   * would record the wrong actor, and the diner's entire acknowledgement model
   * keys off that actor.
   */
  @Post(':id/cancel')
  // 200, not Nest's default 201 for a POST. Nothing is created — an existing
  // reservation changes state, the same as every other transition in
  // doc 06 §4.
  @HttpCode(200)
  @ApiOkResponse({ type: CancelledReservationResponse })
  @ApiOperation({ summary: 'Cancel a booking, as the restaurant' })
  @ApiResponse({ status: 400, description: 'validation_failed — a reason is REQUIRED' })
  @ApiResponse({ status: 403, description: 'not_an_owner' })
  @ApiResponse({
    status: 404,
    description:
      "reservation_not_found — ALSO returned for another venue's reservation, " +
      'deliberately, and byte-identical to an id that exists for nobody.',
  })
  @ApiResponse({ status: 409, description: 'invalid_status_transition — already settled' })
  async cancel(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelReservationDto,
  ): Promise<CancelledReservationResponse> {
    const ownerId = await this.ownerIdOf(user);
    const cancelled = await this.cancellation.cancel(ownerId, id, dto.reason);

    // NOTIFY-1's first real trigger, and the reason it was built.
    //
    // AFTER the cancellation has committed, and it can never undo it:
    // `notify` does not throw. A table that failed to be released because a
    // push timed out would be strictly worse than a diner who has to open the
    // app to find out.
    //
    // A walk-in has no account, so there is nobody to tell — the venue took
    // that booking at the podium and can say so at the podium.
    if (cancelled.user_id) {
      const venue = await this.prisma.restaurant.findUnique({
        where: { id: cancelled.restaurant_id },
        select: { nameEn: true, nameAr: true, timezone: true },
      });
      const tz = isValidTimeZone(venue?.timezone ?? '') ? venue!.timezone : 'Africa/Cairo';
      const when = new Date(cancelled.starts_at);

      await this.notifications.notify({
        userId: cancelled.user_id,
        type: 'reservation_cancelled_by_venue',
        data: {
          reservationId: cancelled.id,
          code: cancelled.code,
          // Both names: the push is rendered per DEVICE locale, and the device
          // may not match the account.
          venue: venue?.nameEn ?? '',
          venueAr: venue?.nameAr ?? '',
          reason: cancelled.cancel_reason,
          // Venue wall clock, so the lock screen never shows a UTC hour.
          date: when.toISOString().slice(0, 10),
          time: utcToZonedHhmm(when, tz),
        },
      });
    }

    return {
      id: cancelled.id,
      code: cancelled.code,
      status: cancelled.status,
      cancelled_at: cancelled.cancelled_at,
      cancel_reason: cancelled.cancel_reason,
      starts_at: cancelled.starts_at,
      party_size: cancelled.party_size,
      // The trigger has already run inside the same statement's transaction.
      table_released: true,
    };
  }
}
