import { Body, Controller, Delete, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto, RevokeDeviceDto } from './dto/device.dto';
import { DeviceResponse } from '../../shared/api/responses.dto';

/** doc 06 §3 — `/devices` POST/DELETE. */
@ApiTags('devices')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('devices')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Post()
  @ApiOkResponse({ type: DeviceResponse })
  @HttpCode(201)
  @ApiOperation({ summary: 'Register this handset for push' })
  async register(
    @CurrentUser() user: AuthedUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<DeviceResponse> {
    const row = await this.devices.register({
      userId: user.id,
      token: dto.token,
      platform: dto.platform,
      // Falls back to the ACCOUNT's locale, not to a constant — a diner who
      // set the app to English gets English on the lock screen too.
      locale: dto.locale ?? user.locale ?? 'ar',
    });
    return { id: row.id, registered: true };
  }

  /**
   * Stop pushing to this handset.
   *
   * The client MUST call this on sign-out. A token left live sends that
   * person's reservations to whoever holds the handset next.
   */
  @Delete()
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoke this handset — call on sign-out' })
  @ApiResponse({ status: 204, description: 'Revoked (idempotent)' })
  async revoke(@CurrentUser() user: AuthedUser, @Body() dto: RevokeDeviceDto): Promise<void> {
    await this.devices.revoke(user.id, dto.token);
  }
}
