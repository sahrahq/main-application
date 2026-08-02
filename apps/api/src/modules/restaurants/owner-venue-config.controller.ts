import {
  BadRequestException, Body, Controller, Delete, ForbiddenException, Get, Headers,
  Param, ParseUUIDPipe, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth, ApiHeader, ApiOkResponse, ApiOperation, ApiQuery, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import { TablesService } from './tables.service';
import { ShiftsService } from './shifts.service';
import { WalkInsService } from './walk-ins.service';
import { CreateTableDto, UpdateTableDto, CreateShiftDto, UpdateShiftDto } from './dto/venue-config.dto';
import { CreateWalkInDto } from './dto/walk-in.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { TableResponse, RemoveTableResponse, ShiftResponse, ShiftWriteResponse, RemoveShiftResponse, ReservationResponse } from '../../shared/api/responses.dto';

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
    private readonly walkIns: WalkInsService,
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
  @ApiOkResponse({ type: [TableResponse] })
  @ApiOperation({ summary: 'List tables' })
  async listTables(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ) {
    return this.tables.list(await this.ownerIdOf(user), restaurantId);
  }

  @Post('tables')
  @ApiOkResponse({ type: TableResponse })
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
  @ApiOkResponse({ type: TableResponse })
  @ApiOperation({ summary: 'Get one table' })
  async getTable(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Param('tableId', ParseUUIDPipe) tableId: string,
  ) {
    return this.tables.get(await this.ownerIdOf(user), restaurantId, tableId);
  }

  @Patch('tables/:tableId')
  @ApiOkResponse({ type: TableResponse })
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
  @ApiOkResponse({ type: RemoveTableResponse })
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

  // ───────────────────────────────────── walk-ins and phone bookings (R-3.2) ──

  /**
   * doc 06 §4 line 106. Consumes the SAME inventory as an app booking, through
   * the same engine path (doc 05 §7) — a party seated off-platform would
   * otherwise be invisible and the next online booking would double-seat them.
   *
   * Idempotency-Key is required, as on every mutation (doc 06 §1). It matters
   * more than usual here: a host taps "seat" on a tablet with poor signal and
   * taps again, and two tables must not be consumed.
   */
  @Post('reservations')
  @ApiOkResponse({ type: ReservationResponse })
  @ApiOperation({ summary: 'Seat a walk-in or take a phone booking' })
  @ApiHeader({ name: 'idempotency-key', required: true, description: 'Client-generated UUID v4' })
  @ApiResponse({ status: 201 })
  @ApiResponse({ status: 409, description: 'slot_taken — the same 409 the app gets' })
  async createWalkIn(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
    @Body() dto: CreateWalkInDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    if (!idempotencyKey || !UUID_V4.test(idempotencyKey)) {
      throw new BadRequestException({
        code: 'invalid_idempotency_key',
        message: 'Idempotency-Key header must be a UUID v4.',
        message_ar: 'ترويسة Idempotency-Key لازم تكون UUID v4.',
        details: [{ field: 'Idempotency-Key', issue: 'format' }],
      });
    }

    return this.walkIns.create(await this.ownerIdOf(user), restaurantId, {
      ...dto,
      startsAt: dto.startsAt ? new Date(dto.startsAt) : undefined,
      idempotencyKey,
    });
  }

  // ───────────────────────────────────────────── opening hours / shifts (R-2.4) ──

  @Get('shifts')
  @ApiOkResponse({ type: [ShiftResponse] })
  @ApiOperation({ summary: 'List opening hours' })
  async listShifts(
    @CurrentUser() user: AuthedUser,
    @Param('restaurantId', ParseUUIDPipe) restaurantId: string,
  ) {
    return this.shifts.list(await this.ownerIdOf(user), restaurantId);
  }

  @Post('shifts')
  @ApiOkResponse({ type: ShiftResponse })
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
  @ApiOkResponse({ type: ShiftResponse })
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
  @ApiOkResponse({ type: ShiftWriteResponse })
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
  @ApiOkResponse({ type: RemoveShiftResponse })
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
