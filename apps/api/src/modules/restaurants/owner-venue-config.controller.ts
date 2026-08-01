import {
  Body, Controller, Delete, ForbiddenException, Get, Param, ParseUUIDPipe,
  Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { TablesService } from './tables.service';
import { ShiftsService } from './shifts.service';
import { CreateTableDto, UpdateTableDto, CreateShiftDto, UpdateShiftDto } from './dto/venue-config.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * Venue configuration — doc 06 §4 lines 102–103.
 *
 *   /owner/restaurants/:id/shifts  CRUD  weekly + special dates + is_ramadan
 *   /owner/restaurants/:id/tables  CRUD  409 if deactivating one with future bookings
 *
 * Without these two, a restaurant has no tables and no opening hours, so the
 * reservation engine has nothing to allocate and nothing to schedule. They are
 * the config the rest of the product assumes already exists.
 */
@ApiTags('owner:venue-config')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('owner/restaurants/:restaurantId')
export class OwnerVenueConfigController {
  constructor(
    private readonly tables: TablesService,
    private readonly shifts: ShiftsService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Ownership comes from the TOKEN, never the request body — otherwise any
   * authenticated diner could pass someone else's ownerId and reconfigure
   * their restaurant.
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

  // ───────────────────────────────────────────────────────── tables (R-2.5) ──

  @Get('tables')
  @ApiOperation({ summary: 'List tables' })
  async listTables(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ) {
    return this.tables.list(await this.ownerIdOf(user), restaurantId);
  }

  @Post('tables')
  @ApiOperation({ summary: 'Add a table' })
  @ApiResponse({ status: 409, description: 'table_name_taken' })
  async createTable(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Body() dto: CreateTableDto,
  ) {
    return this.tables.create(await this.ownerIdOf(user), restaurantId, dto);
  }

  @Get('tables/:tableId')
  @ApiOperation({ summary: 'Get one table' })
  async getTable(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('tableId', ParseUUIDPipe) tableId: string,
  ) {
    return this.tables.get(await this.ownerIdOf(user), restaurantId, tableId);
  }

  @Patch('tables/:tableId')
  @ApiOperation({ summary: 'Edit a table' })
  @ApiResponse({
    status: 409,
    description:
      'table_has_future_reservations (retiring one that is booked) | ' +
      'capacity_conflict_with_reservations (shrinking below a booked party)',
  })
  async updateTable(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('tableId', ParseUUIDPipe) tableId: string,
    @Body() dto: UpdateTableDto,
  ) {
    return this.tables.update(await this.ownerIdOf(user), restaurantId, tableId, dto);
  }

  @Delete('tables/:tableId')
  @ApiOperation({
    summary: 'Remove a table — hard delete if never used, otherwise retired so history survives',
  })
  @ApiResponse({ status: 409, description: 'table_has_future_reservations' })
  async removeTable(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('tableId', ParseUUIDPipe) tableId: string,
  ) {
    return this.tables.remove(await this.ownerIdOf(user), restaurantId, tableId);
  }

  // ───────────────────────────────────────────── opening hours / shifts (R-2.4) ──

  @Get('shifts')
  @ApiOperation({ summary: 'List opening hours' })
  async listShifts(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ) {
    return this.shifts.list(await this.ownerIdOf(user), restaurantId);
  }

  @Post('shifts')
  @ApiOperation({ summary: 'Add a shift (weekly or one-off date)' })
  @ApiResponse({ status: 409, description: 'shift_overlap' })
  async createShift(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Body() dto: CreateShiftDto,
  ) {
    return this.shifts.create(await this.ownerIdOf(user), restaurantId, dto);
  }

  @Get('shifts/:shiftId')
  @ApiOperation({ summary: 'Get one shift' })
  async getShift(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('shiftId', ParseUUIDPipe) shiftId: string,
  ) {
    return this.shifts.get(await this.ownerIdOf(user), restaurantId, shiftId);
  }

  /**
   * `force` overrides the stranded-booking guard. It changes what happens to
   * the SHIFT — never to the bookings, which are kept and returned so the
   * restaurant can call those guests.
   */
  @Patch('shifts/:shiftId')
  @ApiOperation({ summary: 'Edit opening hours' })
  @ApiQuery({ name: 'force', required: false, type: Boolean })
  @ApiResponse({ status: 409, description: 'bookings_outside_new_hours | shift_overlap' })
  async updateShift(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('shiftId', ParseUUIDPipe) shiftId: string,
    @Body() dto: UpdateShiftDto,
    @Query('force') force?: string,
  ) {
    return this.shifts.update(
      await this.ownerIdOf(user), restaurantId, shiftId, dto, { force: force === 'true' },
    );
  }

  @Delete('shifts/:shiftId')
  @ApiOperation({ summary: 'Remove a shift' })
  @ApiQuery({ name: 'force', required: false, type: Boolean })
  @ApiResponse({ status: 409, description: 'bookings_outside_new_hours' })
  async removeShift(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('shiftId', ParseUUIDPipe) shiftId: string,
    @Query('force') force?: string,
  ) {
    return this.shifts.remove(
      await this.ownerIdOf(user), restaurantId, shiftId, { force: force === 'true' },
    );
  }
}
