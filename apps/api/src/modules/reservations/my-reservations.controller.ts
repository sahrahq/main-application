import { Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
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

  /**
   * The diner has seen that the restaurant cancelled on them.
   *
   * ITS OWN CALL, not a side effect of the GET above. A read that acknowledged
   * would be acknowledged by a prefetch, a retry, or a list render — none of
   * which is a human reading the notice, and the notice existing at all is the
   * difference between a diner knowing and a diner arriving at a restaurant
   * that is not expecting them.
   *
   * 204, idempotent, and only ever writes the timestamp once.
   *
   * NOT IN doc 06 §3 — added here because the acknowledgement model it
   * enables has no other home. See the section added to that document.
   */
  @Post(':id/acknowledge-cancellation')
  @HttpCode(204)
  @ApiOperation({ summary: 'Mark a restaurant-initiated cancellation as seen' })
  @ApiResponse({ status: 204, description: 'Acknowledged (idempotent)' })
  @ApiResponse({ status: 404, description: 'reservation_not_found' })
  acknowledge(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    return this.reservations.acknowledgeCancellation(user.id, id);
  }
}
