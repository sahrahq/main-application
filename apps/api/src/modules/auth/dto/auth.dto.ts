import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { IsString, IsOptional, IsEmail, MinLength, MaxLength, IsIn, Matches } from "class-validator";

export class RegisterDto {
  @ApiProperty({ example: "+201000000000", description: "E.164 or local Egyptian (01xxxxxxxxx)" })
  @IsString()
  @Matches(/^(\+?\d{7,20}|0\d{9,11})$/, { message: "phone must be a valid number" })
  phone!: string;

  @ApiProperty({ maxLength: 120 })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ minLength: 8, description: "Optional — OTP-only accounts are supported" })
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password?: string;

  @ApiPropertyOptional({ enum: ["ar", "en"], default: "ar" })
  @IsOptional()
  @IsIn(["ar", "en"])
  locale?: "ar" | "en";
}

export class LoginDto {
  @ApiProperty({ description: "Phone or email" })
  @IsString()
  @MaxLength(160)
  identifier!: string;

  @ApiProperty()
  @IsString()
  @MaxLength(128)
  password!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MaxLength(256)
  refreshToken!: string;
}

export class LogoutDto {
  @ApiProperty()
  @IsString()
  @MaxLength(256)
  refreshToken!: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  allDevices?: boolean;

  /**
   * The push token to stop sending to. **The client must supply this.**
   *
   * A token left live on a signed-out account pushes that person's
   * reservations to whoever holds the handset next — on a shared or resold
   * phone that is a privacy incident, not an annoyance. Optional only because
   * a client with no push registered has none to give.
   */
  @ApiPropertyOptional({ description: 'FCM token to revoke — send it on sign-out' })
  @IsOptional()
  @IsString()
  @MaxLength(4096)
  deviceToken?: string;
}
export class VerifyOtpDto {
  @ApiProperty({ format: "uuid" })
  @IsString()
  userId!: string;

  @ApiProperty({ example: "123456", minLength: 6, maxLength: 6 })
  @IsString()
  @Matches(/^\d{6}$/, { message: "code must be 6 digits" })
  code!: string;

  /**
   * WHICH challenge this code answers.
   *
   * Challenges are keyed `otp:{purpose}:{userId}`, so a registration code
   * cannot verify a sign-in and a sign-in code cannot activate an account.
   * That separation is a security property, not bookkeeping: without it, a
   * code sent for one purpose is a credential for every purpose.
   *
   * Defaults to `phone_verify` so the registration flow is unchanged.
   */
  @ApiPropertyOptional({ enum: ["phone_verify", "login"], default: "phone_verify" })
  @IsOptional()
  @IsIn(["phone_verify", "login"])
  purpose?: "phone_verify" | "login";
}

/**
 * doc 06 §2 — `/auth/login` with `{phone}` "→ OTP flow".
 *
 * Its own route rather than a second shape on `/auth/login`, because the two
 * branches return categorically different things: a token pair, or a handle to
 * a challenge that has not been answered yet. One endpoint returning either
 * would force a union response, and a union response is a
 * `Map<String, dynamic>` at the client — the escape hatch that is ruled out.
 *
 * Named to sit beside `resend-otp`, which is its sibling.
 */
export class RequestOtpDto {
  @ApiProperty({ example: "+201000000000", description: "E.164 or local Egyptian (01xxxxxxxxx)" })
  @IsString()
  @Matches(/^(\+?\d{7,20}|0\d{9,11})$/, { message: "phone must be a valid number" })
  phone!: string;
}

export class ResendOtpDto {
  @ApiProperty({ format: "uuid" })
  @IsString()
  userId!: string;
}