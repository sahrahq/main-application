import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { FavoritesService } from './favorites.service';
import { WaitlistService } from './waitlist.service';
import { SaveVenueDto, JoinWaitlistDto } from './dto/favorites.dto';
import { SavedVenueResponse, WaitlistEntryResponse } from '../../shared/api/responses.dto';

/**
 * C-2.7 — the diner's saved places.
 *
 * `/saved` rather than `/users/me/saved`: the subject is the token, so there
 * is no id in any route here and nothing for a caller to tamper with. Same
 * shape as `/reservations`, and for the same reason.
 */
@ApiTags('saved')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('saved')
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Get()
  @ApiOkResponse({ type: [SavedVenueResponse] })
  @ApiOperation({ summary: "The caller's saved venues, newest first" })
  listSaved(@CurrentUser() user: AuthedUser): Promise<SavedVenueResponse[]> {
    return this.favorites.list(user.id) as Promise<SavedVenueResponse[]>;
  }

  /**
   * Save a venue.
   *
   * **201 the first time, 200 afterwards, and both are success.** The unique
   * index makes a duplicate INSERT fail at the database; turning that into an
   * error for the diner would punish a double tap on a bad connection for
   * arriving at exactly the state they asked for.
   *
   * No `Idempotency-Key`: the operation is idempotent by construction, which
   * is the whole point of the paragraph above.
   */
  @Post()
  @ApiOkResponse({ description: 'Already saved' })
  @ApiOperation({ summary: 'Save a venue (idempotent)' })
  @ApiResponse({ status: 201, description: 'Saved' })
  @ApiResponse({ status: 404, description: 'restaurant_not_found' })
  async save(
    @CurrentUser() user: AuthedUser,
    @Body() dto: SaveVenueDto,
    @Res({ passthrough: true }) res: Response,
  ): Promise<void> {
    const { created } = await this.favorites.save(user.id, dto.restaurantId);
    res.status(created ? 201 : 200);
  }

  /**
   * Unsave. 204 whether or not it was saved.
   *
   * The control is a toggle. A 404 for "already not saved" would be accurate
   * and useless — the diner wanted it gone and it is gone.
   */
  @Delete(':restaurantId')
  @HttpCode(204)
  @ApiOperation({ summary: 'Unsave a venue (idempotent)' })
  @ApiResponse({ status: 204, description: 'Not saved any more, either way' })
  unsave(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ): Promise<void> {
    return this.favorites.unsave(user.id, restaurantId);
  }
}

/**
 * C-3.6 — the waitlist.
 *
 * **THE NOTIFY HALF IS NOT BUILT.** Joining works; nothing offers anybody a
 * table yet. See `WaitlistService` for why that split is deliberate and what
 * it is waiting on, and see the copy on the notify-me control, which must not
 * promise a notification the platform cannot send.
 */
@ApiTags('waitlists')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('waitlists')
export class WaitlistController {
  constructor(private readonly waitlist: WaitlistService) {}

  @Get()
  @ApiOkResponse({ type: [WaitlistEntryResponse] })
  @ApiOperation({ summary: "The caller's live waitlist entries" })
  listWaitlists(@CurrentUser() user: AuthedUser): Promise<WaitlistEntryResponse[]> {
    return this.waitlist.list(user.id) as Promise<WaitlistEntryResponse[]>;
  }

  @Post()
  @HttpCode(201)
  @ApiOkResponse({ type: WaitlistEntryResponse })
  @ApiOperation({ summary: 'Join the waitlist for a date and window' })
  @ApiResponse({ status: 201, description: 'Joined' })
  @ApiResponse({ status: 400, description: 'validation_failed — past date, or window inverted' })
  @ApiResponse({ status: 404, description: 'restaurant_not_found' })
  @ApiResponse({ status: 409, description: 'already_on_waitlist' })
  join(
    @CurrentUser() user: AuthedUser,
    @Body() dto: JoinWaitlistDto,
  ): Promise<WaitlistEntryResponse> {
    return this.waitlist.join({
      userId: user.id,
      restaurantId: dto.restaurantId,
      desiredDate: dto.desiredDate,
      windowStart: new Date(dto.windowStart),
      windowEnd: new Date(dto.windowEnd),
      partySize: dto.partySize,
    }) as Promise<WaitlistEntryResponse>;
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Leave the waitlist' })
  @ApiResponse({ status: 204, description: 'Left (the row is kept, marked cancelled)' })
  @ApiResponse({
    status: 404,
    description:
      "waitlist_entry_not_found — ALSO for another diner's entry, deliberately.",
  })
  leave(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    return this.waitlist.leave(user.id, id);
  }
}
