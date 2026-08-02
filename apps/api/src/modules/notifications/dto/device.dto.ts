import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

const PLATFORMS = ['android', 'ios', 'web'] as const;

/** doc 06 §3 — `/devices` POST/DELETE, "FCM token registration". */
export class RegisterDeviceDto {
  @ApiProperty({ description: 'FCM registration token', maxLength: 4096 })
  @IsString()
  @MinLength(8)
  @MaxLength(4096)
  token!: string;

  @ApiProperty({ enum: PLATFORMS })
  @IsIn(PLATFORMS as unknown as string[])
  platform!: string;

  /**
   * The DEVICE's language, which is not necessarily the account's.
   *
   * A push is rendered by the operating system on a lock screen with no client
   * running, so the server picks the language — and it has to pick the one
   * displayed on that handset. A shared phone and a traveller are both real.
   */
  @ApiPropertyOptional({ enum: ['ar', 'en'], default: 'ar' })
  @IsOptional()
  @IsIn(['ar', 'en'])
  locale?: string;
}

export class RevokeDeviceDto {
  @ApiProperty({ description: 'The token to stop pushing to' })
  @IsString()
  @MaxLength(4096)
  token!: string;
}
