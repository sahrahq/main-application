import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min,
} from 'class-validator';

const STAFF_SOURCES = ['walk_in', 'phone'] as const;
const ZONES = ['indoor', 'outdoor', 'family', 'bar', 'private'] as const;

/**
 * doc 06 §4 line 106 — `{guest_name, guest_phone?, party_size, starts_at}`.
 *
 * Only `party_size` is required. A host with a queue at the door is not
 * filling in a form: a party of four with no name is a perfectly ordinary
 * walk-in, and demanding a name would push staff into typing "x" forever,
 * which is worse data than none.
 */
export class CreateWalkInDto {
  @ApiProperty({ example: 4 })
  @IsInt()
  @Min(1)
  @Max(50)
  partySize!: number;

  @ApiPropertyOptional({ example: 'Nour', maxLength: 120 })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  guestName?: string;

  @ApiPropertyOptional({ example: '+201000000000', maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  guestPhone?: string;

  @ApiPropertyOptional({
    description: 'ISO-8601 UTC. Omit for a party at the door — defaults to now.',
  })
  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @ApiPropertyOptional({
    enum: STAFF_SOURCES,
    default: 'walk_in',
    description: '`app` is rejected — staff entries must stay distinguishable from customer ones',
  })
  @IsOptional()
  @IsIn(STAFF_SOURCES as unknown as string[])
  source?: string;

  @ApiPropertyOptional({ enum: ZONES })
  @IsOptional()
  @IsIn(ZONES as unknown as string[])
  seatingPref?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  specialRequests?: string;

  @ApiPropertyOptional({ maxLength: 40 })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  occasion?: string;
}
