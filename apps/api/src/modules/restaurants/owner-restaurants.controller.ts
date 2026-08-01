import {
  Body, Controller, Get, Param, Patch, Post, Query, UseGuards, ParseUUIDPipe,
  ForbiddenException, BadRequestException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RestaurantsService } from './restaurants.service';
import { OwnerReservationsService } from './owner-reservations.service';
import { CreateRestaurantDto, UpdateRestaurantDto } from './dto/restaurant.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { PrismaService } from '../../shared/prisma/prisma.service';

/** doc 06 §4 — `/owner/...`, role owner/staff. */
@ApiTags('owner:restaurants')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('owner/restaurants')
export class OwnerRestaurantsController {
  constructor(
    private readonly restaurants: RestaurantsService,
    private readonly book: OwnerReservationsService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Map the authenticated user to their owner record.
   *
   * Ownership is resolved server-side from the token, never taken from the
   * request body — otherwise any authenticated diner could pass someone
   * else's ownerId and edit their venue.
   */
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

  @Post()
  @ApiOperation({ summary: 'Create a restaurant (lands in draft)' })
  @ApiResponse({ status: 201 })
  async create(@CurrentUser() user: AuthedUser, @Body() dto: CreateRestaurantDto) {
    return this.restaurants.create(await this.ownerIdOf(user), dto);
  }

  @Get()
  @ApiOperation({ summary: 'List my restaurants' })
  async listMine(@CurrentUser() user: AuthedUser) {
    return this.restaurants.listMine(await this.ownerIdOf(user));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one of my restaurants' })
  async getOne(@CurrentUser() user: AuthedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.restaurants.getOwned(await this.ownerIdOf(user), id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update profile, policies, amenities' })
  async update(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRestaurantDto,
  ) {
    return this.restaurants.update(await this.ownerIdOf(user), id, dto);
  }

  /**
   * The book (doc 06 §4). `date` is the venue's LOCAL calendar day — a Cairo
   * restaurant's 01:00 covers belong to that night's service, not to the
   * previous UTC date.
   */
  @Get(':id/reservations')
  @ApiOperation({ summary: "Tonight's book, in the restaurant's local time" })
  async reservations(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('date') date: string,
    @Query('status') status?: string,
  ) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) {
      throw new BadRequestException({
        code: 'invalid_date',
        message: 'date must be YYYY-MM-DD.',
        message_ar: 'التاريخ لازم يكون بصيغة YYYY-MM-DD.',
      });
    }
    return this.book.listForDate({
      ownerId: await this.ownerIdOf(user),
      restaurantId: id,
      date,
      status,
    });
  }

  @Post(':id/submit')
  @ApiOperation({ summary: 'draft → pending_review' })
  @ApiResponse({ status: 409, description: 'invalid_status_transition' })
  async submit(@CurrentUser() user: AuthedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.restaurants.submitForReview(await this.ownerIdOf(user), id);
  }
}
