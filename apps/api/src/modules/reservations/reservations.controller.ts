import {
  Body, Controller, Headers, HttpCode, Post, Param, ParseUUIDPipe, BadRequestException,
} from '@nestjs/common';
import { ApiHeader, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ReservationsService, HOLD_TTL_MINUTES } from './reservations.service';
import { CreateHoldDto } from './dto/create-hold.dto';
import { ConfirmHoldDto } from '../restaurants/dto/restaurant.dto';

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
  @HttpCode(201)
  @ApiOperation({ summary: `Hold a table for ${HOLD_TTL_MINUTES} minutes` })
  @ApiHeader({ name: 'Idempotency-Key', required: true, description: 'Client-generated UUID v4' })
  @ApiResponse({ status: 201, description: 'Hold created' })
  @ApiResponse({ status: 409, description: 'slot_taken | pacing_limit_reached' })
  async createHold(
    @Body() dto: CreateHoldDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
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
      status: r.status,
      startsAt: r.startsAt,
      endsAt: r.endsAt,
      partySize: r.partySize,
      holdExpiresAt: r.holdExpiresAt,
    };
  }

  /**
   * Confirm a hold within its 5-minute window (doc 06 §3).
   *
   * Idempotency-Key is required here too, and it must be a DIFFERENT key from
   * the one used on the hold — this is a separate mutation.
   */
  @Post('holds/:id/confirm')
  @HttpCode(200)
  @ApiOperation({ summary: 'Confirm a held table' })
  @ApiHeader({ name: 'Idempotency-Key', required: true, description: 'Client-generated UUID v4' })
  @ApiResponse({ status: 200, description: 'Reservation confirmed' })
  @ApiResponse({ status: 409, description: 'hold_expired | invalid_status_transition' })
  @ApiResponse({ status: 404, description: 'reservation_not_found' })
  async confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfirmHoldDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
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
      status: r.status,
      startsAt: r.startsAt,
      endsAt: r.endsAt,
      partySize: r.partySize,
      specialRequests: r.specialRequests,
      occasion: r.occasion,
    };
  }
}
