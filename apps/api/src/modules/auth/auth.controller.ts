import { Body, Controller, Post, HttpCode, Req, UseGuards, Get } from '@nestjs/common';
import {
  ApiBearerAuth, ApiOkResponse, ApiOperation, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { AuthService, RequestCtx } from './auth.service';
import { RegisterDto, LoginDto, RefreshDto, LogoutDto, VerifyOtpDto, ResendOtpDto } from './dto/auth.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { RegisterResponse, TokenPairResponse, UserResponse, OtpSentResponse, ApiErrorResponse } from '../../shared/api/responses.dto';

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
  @ApiOkResponse({ type: RegisterResponse })
  @ApiResponse({ status: 400, type: ApiErrorResponse })
  @HttpCode(201)
  @ApiOperation({ summary: 'Create an account (phone is the primary identity)' })
  @ApiResponse({ status: 201, description: '{ userId, otpRequired: true }' })
  @ApiResponse({ status: 409, description: 'phone_exists | email_exists' })
  register(@Body() dto: RegisterDto, @Req() req: Request): Promise<RegisterResponse> {
    return this.auth.register({
      phone: dto.phone,
      fullName: dto.fullName,
      email: dto.email ?? null,
      password: dto.password ?? null,
      locale: dto.locale,
    }, ctxOf(req));
  }

  @Post('verify-otp')
  @ApiOkResponse({ type: TokenPairResponse })
  @HttpCode(200)
  @ApiOperation({ summary: 'Verify the phone code; activates the account' })
  @ApiResponse({ status: 200, description: 'Access + refresh token pair' })
  @ApiResponse({ status: 400, description: 'invalid_otp | otp_expired' })
  @ApiResponse({ status: 429, description: 'too_many_attempts' })
  verifyOtp(@Body() dto: VerifyOtpDto, @Req() req: Request): Promise<TokenPairResponse> {
    return this.auth.verifyOtp(dto.userId, dto.code, ctxOf(req));
  }

  @Post('resend-otp')
  @ApiOkResponse({ type: OtpSentResponse })
  @HttpCode(202)
  @ApiOperation({ summary: 'Re-send the phone code (rate limited)' })
  @ApiResponse({ status: 429, description: 'otp_rate_limited' })
  async resendOtp(@Body() dto: ResendOtpDto, @Req() req: Request): Promise<void> {
    await this.auth.resendOtp(dto.userId, ctxOf(req));
  }

  @Post('login')
  @ApiOkResponse({ type: TokenPairResponse })
  @HttpCode(200)
  @ApiOperation({ summary: 'Password login' })
  @ApiResponse({ status: 200, description: 'Access + refresh token pair' })
  @ApiResponse({ status: 401, description: 'invalid_credentials | account_unavailable' })
  login(@Body() dto: LoginDto, @Req() req: Request): Promise<TokenPairResponse> {
    return this.auth.login(dto.identifier, dto.password, ctxOf(req));
  }

  @Post('refresh')
  @ApiOkResponse({ type: TokenPairResponse })
  @HttpCode(200)
  @ApiOperation({
    summary: 'Rotate the refresh token',
    description:
      'Returns a NEW pair and revokes the presented token. Replaying a ' +
      'revoked token revokes the entire family and returns 401.',
  })
  @ApiResponse({ status: 401, description: 'invalid_refresh_token | token_reuse_detected' })
  refresh(@Body() dto: RefreshDto, @Req() req: Request): Promise<TokenPairResponse> {
    return this.auth.refresh(dto.refreshToken, ctxOf(req));
  }

  @Post('logout')
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoke this refresh token, or every one for the user' })
  async logout(@Body() dto: LogoutDto): Promise<void> {
    await this.auth.logout(dto.refreshToken, dto.allDevices === true);
  }

  @Get('me')
  @ApiOkResponse({ type: UserResponse })
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'The caller identified by the access token' })
  // Returned only { id, roles, locale } while `UserResponse` declares phone,
  // fullName, email and status as well — so the generated client threw a null
  // cast on `phone`. The JWT deliberately carries only what authorisation
  // needs (doc 09 §1.1), so the profile is read from the database rather than
  // widening the claims: a token is not a place to cache a display name.
  me(@CurrentUser() user: AuthedUser): Promise<UserResponse> {
    return this.auth.profile(user.id);
  }
}
