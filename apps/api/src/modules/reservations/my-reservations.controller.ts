import {
  BadRequestException, Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post,
  Query, UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { MyReservationsService, RESERVATION_VIEWS } from './my-reservations.service';
import { ReservationsService } from './reservations.service';
import { AvailabilityService } from '../availability/availability.service';
import { WaitlistOfferService } from '../favorites/waitlist-offer.service';
import { CancelOwnReservationDto, ModifyReservationDto } from './dto/modify-reservation.dto';
import { AvailabilityResponse, MyReservationResponse } from '../../shared/api/responses.dto';

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
  constructor(
    private readonly reservations: MyReservationsService,
    /**
     * The engine, for the two routes that touch inventory. A modify releases
     * a table and takes another one; that is a booking write and it belongs
     * in the service that owns the advisory lock, not in a second place that
     * reimplements two of its three layers.
     */
    private readonly engine: ReservationsService,
    /** The same grid the booking screen reads, minus this reservation. */
    private readonly availability: AvailabilityService,
    /** C-3.6 — the queue that wants to hear about a cancellation. */
    private readonly waitlistOffers: WaitlistOfferService,
  ) {}

  @Get()
  @ApiOkResponse({ type: [MyReservationResponse] })
  @ApiOperation({ summary: "The caller's own reservations" })
  @ApiQuery({ name: 'status', required: false, enum: RESERVATION_VIEWS as unknown as string[] })
  @ApiResponse({ status: 400, description: 'invalid_query_param' })
  listMyReservations(
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

  /**
   * The times this booking could move to (C-3.4's picker).
   *
   * ── WHY THIS IS NOT A QUERY PARAMETER ON THE PUBLIC GRID ────────────────
   *
   * `GET /restaurants/:id/availability` is anonymous by design, so a
   * caller-supplied reservation id there would be either trusted — an oracle
   * for "does this reservation exist" — or checked against nobody. Here the
   * reservation is in the path, behind the diner guard, and the venue, the
   * party size and the ownership all come off a row already proved to be the
   * caller's. There is nothing left to check.
   *
   * ── AND WHY IT EXISTS AT ALL ────────────────────────────────────────────
   *
   * A diner's own booking holds a table, so the ordinary grid hides not just
   * their current time but the slots either side of it — with a 90-minute turn
   * that is exactly "move me an hour later". `modifyOwn` accepts those moves;
   * without this route the picker would never offer them, and at a
   * one-or-two-table venue the modify button would look broken rather than
   * refuse anything.
   *
   * `party_size` is optional and defaults to the booking's own, so the common
   * case ("same party, different time") needs no parameter at all.
   */
  @Get(':id/available-slots')
  @ApiOkResponse({ type: AvailabilityResponse })
  @ApiOperation({ summary: 'Times this booking could be moved to' })
  @ApiQuery({ name: 'date', example: '2026-08-09' })
  @ApiQuery({ name: 'party_size', required: false, example: 2 })
  @ApiResponse({ status: 400, description: 'invalid_date | invalid_party_size' })
  @ApiResponse({ status: 404, description: 'reservation_not_found' })
  async movableSlots(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('date') date: string,
    @Query('party_size') partySize?: string,
  ): Promise<AvailabilityResponse> {
    // Ownership first, and it is the same 404 a stranger's id gets from every
    // other route here.
    const reservation = await this.reservations.one(user.id, id);

    if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) {
      throw new BadRequestException({
        code: 'invalid_date',
        message: 'date must be YYYY-MM-DD.',
        message_ar: 'التاريخ لازم يكون بصيغة YYYY-MM-DD.',
      });
    }

    const n = partySize === undefined || partySize === '' ? reservation.party_size : Number(partySize);
    if (!Number.isInteger(n) || n < 1 || n > 50) {
      throw new BadRequestException({
        code: 'invalid_party_size',
        message: 'party_size must be an integer between 1 and 50.',
        message_ar: 'عدد الأفراد لازم يكون رقم بين 1 و 50.',
      });
    }

    return this.availability.getSlots({
      restaurantId: reservation.restaurant.id,
      date,
      partySize: n,
      // The booking does not block itself. See `SlotQuery.excludeReservationId`.
      excludeReservationId: id,
    });
  }

  /**
   * C-3.4 — move a booking, or change how many are coming.
   *
   * NO `Idempotency-Key`. The body names absolute values, so a replay lands on
   * the same window with the same party and no retry can produce a second row.
   * See `ReservationsService.modifyOwn` for the full argument and for what
   * would have to change to make a key mandatory.
   *
   * Returns the reservation in the SAME shape the two reads return, so the
   * client replaces its state with the response instead of re-fetching — one
   * request rather than two on a Cairo mobile connection, and no window in
   * which the screen shows a stale time.
   */
  @Patch(':id')
  @ApiOkResponse({ type: MyReservationResponse })
  @ApiOperation({ summary: 'Change the time or party size of your own booking' })
  @ApiResponse({ status: 400, description: 'validation_failed — no fields, or a past time' })
  @ApiResponse({
    status: 404,
    description:
      "reservation_not_found — ALSO returned for another diner's reservation, " +
      'deliberately, and byte-identical to an id that exists for nobody.',
  })
  @ApiResponse({
    status: 409,
    description:
      'slot_taken | pacing_limit_reached | invalid_status_transition | ' +
      'reservation_not_modifiable (already started)',
  })
  async modify(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ModifyReservationDto,
  ): Promise<MyReservationResponse> {
    if (dto.startsAt === undefined && dto.partySize === undefined) {
      // Refused rather than treated as a successful no-op. A 200 for a body
      // that changed nothing reads to the client exactly like a change that
      // worked, which is how a broken form ships looking healthy.
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Give a new time or a new party size.',
        message_ar: 'حدّد وقت جديد أو عدد أفراد جديد.',
        details: [{ field: 'startsAt', issue: 'required_one_of' }],
      });
    }

    const startsAt = dto.startsAt === undefined ? undefined : new Date(dto.startsAt);
    if (startsAt !== undefined && startsAt.getTime() <= Date.now()) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Pick a time in the future.',
        message_ar: 'اختر وقت في المستقبل.',
        details: [{ field: 'startsAt', issue: 'past' }],
      });
    }

    await this.engine.modifyOwn({
      reservationId: id,
      userId: user.id,
      startsAt,
      partySize: dto.partySize,
    });

    return this.reservations.one(user.id, id) as Promise<MyReservationResponse>;
  }

  /**
   * C-3.5 — the diner cancels.
   *
   * `/reservations/:id/cancel`, NOT `/owner/reservations/:id/cancel`. Two
   * doors, two actors, and the row records which one was used — the diner's
   * own cancellation leaves their upcoming list at once, while the venue's
   * stays visible until acknowledged. Collapsing them into one handler with a
   * role branch is one refactor away from recording the wrong actor, and the
   * acknowledgement model has no other input.
   *
   * 200 with the updated reservation rather than 204: the screen that made
   * this call is showing the booking, and it needs the new status, the
   * cancelled-at stamp and the reason to redraw itself.
   */
  @Post(':id/cancel')
  // 200, not Nest's 201. Nothing is created.
  @HttpCode(200)
  @ApiOkResponse({ type: MyReservationResponse })
  @ApiOperation({ summary: 'Cancel your own booking' })
  @ApiResponse({ status: 404, description: 'reservation_not_found' })
  @ApiResponse({ status: 409, description: 'invalid_status_transition — already settled' })
  async cancelOwn(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelOwnReservationDto,
  ): Promise<MyReservationResponse> {
    const freed = await this.engine.cancelOwn({
      reservationId: id,
      userId: user.id,
      reason: dto.reason ?? null,
    });

    // C-3.6 — the second of the three paths that free a table. A diner
    // cancelling at 18:00 for a 20:00 table is the single most useful thing
    // that can happen to somebody on that venue's waitlist, and until Group G
    // nothing looked.
    //
    // After the cancellation has committed, and unable to undo it:
    // `onSlotFreed` does not throw.
    await this.waitlistOffers.onSlotFreed(freed);

    return this.reservations.one(user.id, id) as Promise<MyReservationResponse>;
  }
}
