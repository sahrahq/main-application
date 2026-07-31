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
}