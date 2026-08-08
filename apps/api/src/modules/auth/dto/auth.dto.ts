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
  /**
   * A PHONE NUMBER. Not an email — `users.email` is a contact field and
   * grants access to nothing.
   *
   * The pattern is defence in depth behind the service, which no longer looks
   * up by email at all. It matters because a field that ACCEPTS an address is
   * a field somebody will eventually match on again; rejecting the shape at
   * the edge makes the contract say so.
   *
   * Still named `identifier` rather than `phone`: renaming is a breaking
   * change to a published contract, and the name is not the load-bearing part
   * once an address cannot get past validation. Same expression as
   * `RegisterDto.phone`, deliberately — two phone patterns that drift is how
   * one door starts accepting what the other rejects.
   */
  @ApiProperty({
    description: "Phone number, E.164 or local Egyptian. NOT an email.",
    example: "+201000000000",
  })
  @IsString()
  @Matches(/^(\+?\d{7,20}|0\d{9,11})$/, { message: "identifier must be a phone number" })
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
  @ApiProperty({ description: "The opaque handle returned by /auth/request-otp" })
  @IsString()
  @MaxLength(64)
  challengeId!: string;

  @ApiProperty({ example: "123456", minLength: 6, maxLength: 6 })
  @IsString()
  @Matches(/^\d{6}$/, { message: "code must be 6 digits" })
  code!: string;

  /*
   * `purpose` IS GONE, and its absence is a security improvement.
   *
   * It used to be a client-supplied field, so a caller chose which challenge
   * their code answered. The purpose now lives on the stored challenge and is
   * read from it, which means the separation it protects — a registration code
   * cannot sign anyone in, a sign-in code cannot activate an account — is no
   * longer something the caller can get wrong or lie about.
   */
}

/**
 * Supply a name for a number that has just been VERIFIED but has no account.
 *
 * There is no phone field, deliberately. The number comes from the challenge,
 * so this cannot be pointed at somebody else's number, and it cannot be called
 * at all without having answered a code sent to that number.
 */
export class CompleteRegistrationDto {
  @ApiProperty({ description: "A challenge that has already been verified" })
  @IsString()
  @MaxLength(64)
  challengeId!: string;

  @ApiProperty({ maxLength: 120 })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ enum: ["ar", "en"], default: "ar" })
  @IsOptional()
  @IsIn(["ar", "en"])
  locale?: "ar" | "en";
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
  @ApiProperty({ description: "The challenge to re-send. The number comes from it." })
  @IsString()
  @MaxLength(64)
  challengeId!: string;
}

/**
 * `PATCH /auth/me` — what a diner may change about themselves.
 *
 * TWO FIELDS. The absences are the design:
 *
 * **No `email`.** Step 4 of the email chain puts it here, and step 3 — the
 * verification flow that decides what an unverified address may be used for —
 * is PAUSED. Accepting one now would write an unverified address to
 * `users.email`, which is the Decision 6 hole in a new place: anybody could
 * type somebody else's address onto their own account, and every confirmation
 * that account ever generated would arrive in a stranger's inbox. The global
 * pipe runs `forbidNonWhitelisted`, so an `email` in the body is a 400 rather
 * than a silent drop — a field that is accepted and discarded looks exactly
 * like a field that works.
 *
 * **No `phone`.** The number is proved by answering a code sent to it. A
 * profile form that could set it would be a way to claim a number without
 * ever demonstrating control of it, which is precisely what AUTH-3 closed.
 *
 * **No `status`, no `roles`.** Self-service privilege escalation.
 *
 * Both fields optional, neither meaningful alone: a body naming neither is
 * refused in the handler, because 200 for a change that did not happen is
 * indistinguishable from one that did.
 */
export class UpdateProfileDto {
  @ApiPropertyOptional({ maxLength: 120, example: "Nour Hassan" })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  fullName?: string;

  @ApiPropertyOptional({ enum: ["ar", "en"], description: "Language for notifications and copy." })
  @IsOptional()
  @IsIn(["ar", "en"])
  locale?: "ar" | "en";
}