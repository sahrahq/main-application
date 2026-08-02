import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsUUID,
  IsInt,
  Min,
  Max,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
  IsIn,
} from 'class-validator';

export const SEATING_ZONES = ['indoor', 'outdoor', 'family', 'bar', 'private'] as const;
export type SeatingZone = (typeof SEATING_ZONES)[number];

export class CreateHoldDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  restaurantId!: string;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 50, example: 2 })
  @IsInt()
  @Min(1)
  @Max(50)
  partySize!: number;

  @ApiProperty({ example: '2026-08-01T21:00:00.000Z', description: 'ISO 8601, UTC' })
  @IsISO8601()
  startsAt!: string;

  @ApiPropertyOptional({ enum: SEATING_ZONES })
  @IsOptional()
  @IsIn(SEATING_ZONES as unknown as string[])
  seatingPref?: SeatingZone;

  @ApiPropertyOptional({ maxLength: 120 })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  guestName?: string;

  @ApiPropertyOptional({ maxLength: 20, example: '+201000000000' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  guestPhone?: string;

  @ApiPropertyOptional({ maxLength: 2000 })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  specialRequests?: string;

  @ApiPropertyOptional({ maxLength: 40, example: 'anniversary' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;
}
