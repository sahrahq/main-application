import {
  BadRequestException, Body, Controller, Post, HttpCode, Patch, Req, UseGuards, Get,
} from '@nestjs/common';
import {
  ApiBearerAuth, ApiOkResponse, ApiOperation, ApiResponse, ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { AuthService, RequestCtx } from './auth.service';
import {
  RegisterDto, LoginDto, RefreshDto, LogoutDto, VerifyOtpDto, ResendOtpDto, RequestOtpDto,
  CompleteRegistrationDto, UpdateProfileDto,
} from './dto/auth.dto';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import {
  RegisterResponse, TokenPairResponse, UserResponse, OtpSentResponse, ApiErrorResponse,
  OtpChallengeResponse, VerifyOtpResponse,
} from '../../shared/api/responses.dto';

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
  @ApiOkResponse({ type: VerifyOtpResponse })
  @HttpCode(200)
  @ApiOperation({ summary: 'Answer a challenge; signs in or asks for a name' })
  @ApiResponse({ status: 200, description: "{ status: 'signed_in' | 'profile_needed' }" })
  @ApiResponse({ status: 400, description: 'invalid_otp | otp_expired' })
  @ApiResponse({ status: 429, description: 'too_many_attempts' })
  async verifyOtp(@Body() dto: VerifyOtpDto, @Req() req: Request): Promise<VerifyOtpResponse> {
    const outcome = await this.auth.verifyOtp(dto.challengeId, dto.code, ctxOf(req));
    return outcome.status === 'signed_in'
      ? { status: 'signed_in', tokens: outcome.tokens }
      : { status: 'profile_needed' };
  }

  /**
   * Name the account behind a challenge that has already been verified.
   *
   * The third step of one sign-in flow, not a second registration door: the
   * number is taken from the challenge, so nothing here can be aimed at a
   * number the caller has not proved they can read.
   */
  @Post('complete-registration')
  @ApiOkResponse({ type: TokenPairResponse })
  @HttpCode(201)
  @ApiOperation({ summary: 'Create the account for a verified challenge' })
  @ApiResponse({ status: 201, description: 'Access + refresh token pair' })
  @ApiResponse({ status: 400, description: 'invalid_otp — not verified, expired, or spent' })
  completeRegistration(
    @Body() dto: CompleteRegistrationDto,
    @Req() req: Request,
  ): Promise<TokenPairResponse> {
    return this.auth.completeRegistration(
      {
        challengeId: dto.challengeId,
        fullName: dto.fullName,
        email: dto.email ?? null,
        locale: dto.locale,
      },
      ctxOf(req),
    );
  }

  /**
   * doc 06 §2 — `/auth/login` with `{phone}`, "→ OTP flow".
   *
   * Its own route rather than a second request shape on `/auth/login`: the two
   * branches return categorically different things — a token pair, or a handle
   * to an unanswered challenge — and one endpoint returning either would force
   * a union response, which is a `Map<String, dynamic>` at the client. That is
   * the escape hatch this project has ruled out, so the deviation from the
   * doc's single row is deliberate and reported.
   *
   * This is the flow C-1.2 (P0) needs and did not have: without it a diner who
   * registered by phone could never sign in again.
   */
  @Post('request-otp')
  @ApiOkResponse({ type: OtpChallengeResponse })
  @HttpCode(202)
  @ApiOperation({ summary: 'Send a code to a phone. No account lookup.' })
  @ApiResponse({ status: 202, description: 'Code sent; continue at /auth/verify-otp' })
  @ApiResponse({ status: 429, description: 'otp_rate_limited' })
  @ApiResponse({ status: 503, description: 'otp_sending_unavailable — global daily ceiling' })
  requestOtp(@Body() dto: RequestOtpDto, @Req() req: Request): Promise<OtpChallengeResponse> {
    return this.auth.requestOtp(dto.phone, ctxOf(req));
  }

  @Post('resend-otp')
  @ApiOkResponse({ type: OtpChallengeResponse })
  @HttpCode(202)
  @ApiOperation({ summary: 'Re-send to the number the challenge went to' })
  @ApiResponse({ status: 429, description: 'otp_rate_limited' })
  @ApiResponse({ status: 503, description: 'otp_sending_unavailable' })
  resendOtp(@Body() dto: ResendOtpDto, @Req() req: Request): Promise<OtpChallengeResponse> {
    return this.auth.resendOtp(dto.challengeId, ctxOf(req));
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
    await this.auth.logout(dto.refreshToken, dto.allDevices === true, dto.deviceToken);
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

  /**
   * Edit the caller's own profile.
   *
   * NO ID ANYWHERE — not in the path, not in the body. The account edited is
   * the account the token belongs to, so this route has no way to address
   * anybody else and no ownership check that could be forgotten. Do not
   * "generalise" it to `PATCH /users/:id`; the parameter is the whole risk.
   *
   * No `Idempotency-Key`: absolute values, so replaying it writes the same
   * name twice and lands in the same place.
   */
  @Patch('me')
  @ApiOkResponse({ type: UserResponse })
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Edit your own name or language' })
  @ApiResponse({
    status: 400,
    description:
      'validation_failed — including `unknown_field` for `email` or `phone`. ' +
      'Both are refused rather than ignored: an address here would be ' +
      'unverified (email chain step 3 is not built), and a number is proved ' +
      'by OTP, never typed.',
  })
  async updateMe(
    @CurrentUser() user: AuthedUser,
    @Body() dto: UpdateProfileDto,
  ): Promise<UserResponse> {
    if (dto.fullName === undefined && dto.locale === undefined) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Give a name or a language to change.',
        message_ar: 'حدّد الاسم أو اللغة اللي عايز تغيّرها.',
        details: [{ field: 'fullName', issue: 'required_one_of' }],
      });
    }

    return this.auth.updateProfile(user.id, { fullName: dto.fullName, locale: dto.locale });
  }
}
