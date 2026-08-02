import {
  Body, Controller, Headers, HttpCode, Post, Param, ParseUUIDPipe, BadRequestException,
} from '@nestjs/common';
import {
  ApiHeader, ApiOkResponse, ApiOperation, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import { ReservationsService, HOLD_TTL_MINUTES } from './reservations.service';
import { CreateHoldDto } from './dto/create-hold.dto';
import { ConfirmHoldDto } from '../restaurants/dto/restaurant.dto';
import { ReservationResponse } from '../../shared/api/responses.dto';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@ApiTags('reservations')
@Controller('reservations')
export class ReservationsController {
  constructor(private readonly reservations: ReservationsService) {}

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
      // Confirmed: the hold window is over, so there is no expiry left to
      // report. Explicitly null rather than absent — the field is declared.
      holdExpiresAt: null,
    };
  }
}
