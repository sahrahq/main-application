import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray, IsBoolean, IsIn, IsInt, IsObject, IsOptional, IsString, IsUUID,
  Matches, Max, MaxLength, Min, MinLength,
} from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const ZONES = ['indoor', 'outdoor', 'family', 'bar', 'private'] as const;

export class CreateTableDto {
  @ApiProperty({ example: 'T1', maxLength: 30 })
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  name!: string;

  @ApiProperty({ type: 'integer', example: 2, description: 'Smallest party this table is offered to' })
  @IsInt()
  @Min(1)
  @Max(50)
  minCapacity!: number;

  @ApiProperty({ type: 'integer', example: 4 })
  @IsInt()
  @Min(1)
  @Max(50)
  maxCapacity!: number;

  @ApiPropertyOptional({ enum: ZONES, default: 'indoor' })
  @IsOptional()
  @IsIn(ZONES as unknown as string[])
  zone?: string;

  @ApiPropertyOptional({ type: 'integer', description: 'Allocation preference — lower assigns first' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(999)
  priority?: number;

  @ApiPropertyOptional({ type: [String], description: 'Table ids in THIS restaurant' })
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  combinableWith?: string[];
}

export class UpdateTableDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(30)
  name?: string;

  @ApiPropertyOptional({ type: 'integer' }) @IsOptional() @IsInt() @Min(1) @Max(50)
  minCapacity?: number;

  @ApiPropertyOptional({ type: 'integer' }) @IsOptional() @IsInt() @Min(1) @Max(50)
  maxCapacity?: number;

  @ApiPropertyOptional({ enum: ZONES })
  @IsOptional() @IsIn(ZONES as unknown as string[])
  zone?: string;

  @ApiPropertyOptional({ type: 'integer' }) @IsOptional() @IsInt() @Min(0) @Max(999)
  priority?: number;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional() @IsArray() @IsUUID('4', { each: true })
  combinableWith?: string[];

  /** Retiring a table is guarded — 409 if it has future bookings (doc 06 §4). */
  @ApiPropertyOptional({ description: 'false retires the table; 409 if it has future bookings' })
  @IsOptional() @IsBoolean()
  active?: boolean;
}

export class CreateShiftDto {
  @ApiProperty({ example: 'Dinner' })
  @IsString() @MinLength(1) @MaxLength(60)
  nameEn!: string;

  @ApiProperty({ example: 'العشاء' })
  @IsString() @MinLength(1) @MaxLength(60)
  nameAr!: string;

  @ApiPropertyOptional({ type: 'integer', example: 5, description: '0=Sunday. Exactly one of this or specificDate.' })
  @IsOptional() @IsInt() @Min(0) @Max(6)
  dayOfWeek?: number;

  @ApiPropertyOptional({ example: '2026-03-20', description: 'Exactly one of this or dayOfWeek.' })
  @IsOptional() @Matches(ISO_DATE, { message: 'specificDate must be YYYY-MM-DD' })
  specificDate?: string;

  @ApiProperty({ example: '18:00', description: 'Restaurant wall clock, 24h' })
  @Matches(HHMM, { message: 'opensAt must be HH:MM' })
  opensAt!: string;

  @ApiProperty({ example: '23:00' })
  @Matches(HHMM, { message: 'closesAt must be HH:MM' })
  closesAt!: string;

  @ApiPropertyOptional({ description: 'Set for sohour-style shifts running past midnight' })
  @IsOptional() @IsBoolean()
  spansMidnight?: boolean;

  @ApiPropertyOptional({
    type: 'object',
    additionalProperties: { type: 'integer' },
    example: { '1-2': 90, '3-4': 105, '5+': 120 },
    description: 'Party-size band → turn minutes. A bare `type: object` here would '
      + 'generate Map<String, dynamic> in the client, so the value type is declared.',
  })
  @IsOptional() @IsObject()
  defaultTurnMinutes?: Record<string, number>;

  /**
   * Persisted, but NOT yet acted on — R-2.4's iftar-pegged-to-Maghrib
   * behaviour is not implemented. See ShiftsService.
   */
  @ApiPropertyOptional({ description: 'Flag only — Maghrib anchoring is not implemented yet' })
  @IsOptional() @IsBoolean()
  isRamadan?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsBoolean()
  active?: boolean;
}

export class UpdateShiftDto extends CreateShiftDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(60)
  declare nameEn: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(60)
  declare nameAr: string;

  @ApiPropertyOptional({ example: '18:00' })
  @IsOptional() @Matches(HHMM, { message: 'opensAt must be HH:MM' })
  declare opensAt: string;

  @ApiPropertyOptional({ example: '23:00' })
  @IsOptional() @Matches(HHMM, { message: 'closesAt must be HH:MM' })
  declare closesAt: string;
}
