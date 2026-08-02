import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { MyReservationsService, RESERVATION_VIEWS } from './my-reservations.service';
import { MyReservationResponse } from '../../shared/api/responses.dto';

/**
 * doc 06 §3 — a diner's own reservations.
 *
 * Guarded at the CLASS level, so a route added here cannot be forgotten. Staff
 * read the same rows through `/owner/restaurants/:id/reservations`, which is a
 * different endpoint with a different guard — there is deliberately no role
 * branch inside these handlers, because a read that serves two audiences is
 * one refactor away from serving the wrong one.
 */
@ApiTags('reservations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reservations')
export class MyReservationsController {
  constructor(private readonly reservations: MyReservationsService) {}

  @Get()
  @ApiOkResponse({ type: [MyReservationResponse] })
  @ApiOperation({ summary: "The caller's own reservations" })
  @ApiQuery({ name: 'status', required: false, enum: RESERVATION_VIEWS as unknown as string[] })
  @ApiResponse({ status: 400, description: 'invalid_query_param' })
  list(
    @CurrentUser() user: AuthedUser,
    @Query('status') status?: string,
  ): Promise<MyReservationResponse[]> {
    return this.reservations.list(
      user.id,
      MyReservationsService.parseView(status),
    ) as Promise<MyReservationResponse[]>;
  }

  @Get(':id')
  @ApiOkResponse({ type: MyReservationResponse })
  @ApiOperation({ summary: 'One of the caller\'s own reservations' })
  @ApiResponse({
    status: 404,
    description:
      'reservation_not_found — ALSO returned for a reservation belonging to ' +
      'someone else, deliberately. A 403 would confirm the row exists.',
  })
  one(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<MyReservationResponse> {
    return this.reservations.one(user.id, id) as Promise<MyReservationResponse>;
  }
}
