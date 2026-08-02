import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

/**
 * doc 06 §4 has no cancel row, so there is nothing here that contradicts it.
 *
 * **THE REASON IS REQUIRED.** It is what the diner ends up staring at, and
 * "cancelled" with no explanation is worse than a phone call — it tells them
 * something went wrong and gives them nothing to do about it, no idea whether
 * to try again, and nobody to be annoyed with except us.
 *
 * Trimmed before validation, so `"   "` fails rather than arriving as a
 * whitespace reason nobody can read.
 */
export class CancelReservationDto {
  @ApiProperty({
    minLength: 3,
    maxLength: 300,
    example: 'Burst pipe in the kitchen — we are so sorry.',
    description: 'REQUIRED. Shown to the diner verbatim.',
  })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(3)
  @MaxLength(300)
  reason!: string;
}
