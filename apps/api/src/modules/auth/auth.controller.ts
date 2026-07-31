import { Body, Controller, Post, HttpCode, Req, UseGuards, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import type { Request } from 'express';
import { AuthService, RequestCtx } from './auth.service';
import { RegisterDto, LoginDto, RefreshDto, LogoutDto } from './dto/auth.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';

/** Bind a refresh token to where it came from, for audit + anomaly review. */
function ctxOf(req: Request): RequestCtx {
  return {
    userAgent: req.get('user-agent') ?? undefined,
    ip: req.ip ?? undefined,
  };
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @HttpCode(201)
  @ApiOperation({ summary: 'Create an account (phone is the primary identity)' })
  @ApiResponse({ status: 201, description: '{ userId, otpRequired: true }' })
  @ApiResponse({ status: 409, description: 'phone_exists | email_exists' })
  register(@Body() dto: RegisterDto) {
    return this.auth.register({
      phone: dto.phone,
      fullName: dto.fullName,
      email: dto.email ?? null,
      password: dto.password ?? null,
      locale: dto.locale,
    });
  }

  @Post('login')
  @HttpCode(200)
  @ApiOperation({ summary: 'Password login' })
  @ApiResponse({ status: 200, description: 'Access + refresh token pair' })
  @ApiResponse({ status: 401, description: 'invalid_credentials | account_unavailable' })
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto.identifier, dto.password, ctxOf(req));
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Rotate the refresh token',
    description:
      'Returns a NEW pair and revokes the presented token. Replaying a ' +
      'revoked token revokes the entire family and returns 401.',
  })
  @ApiResponse({ status: 401, description: 'invalid_refresh_token | token_reuse_detected' })
  refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(dto.refreshToken, ctxOf(req));
  }

  @Post('logout')
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoke this refresh token, or every one for the user' })
  async logout(@Body() dto: LogoutDto): Promise<void> {
    await this.auth.logout(dto.refreshToken, dto.allDevices === true);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'The caller identified by the access token' })
  me(@CurrentUser() user: AuthedUser) {
    return { id: user.id, roles: user.roles, locale: user.locale };
  }
}
