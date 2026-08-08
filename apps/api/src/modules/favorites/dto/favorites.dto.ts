import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsISO8601, IsUUID, Matches, Max, Min } from 'class-validator';

export class SaveVenueDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  restaurantId!: string;
}

/**
 * C-3.6 — joining a waitlist.
 *
 * THE WINDOW IS REQUIRED, and that is the design. "Notify me if anything frees
 * up that night" produces an offer at 22:30 for somebody who wanted 19:00, and
 * the second time that happens they stop reading the notifications — at which
 * point the feature is worse than absent, because the venue thinks it has
 * reach it does not have.
 *
 * `desiredDate` is separate from the window rather than derived from it. The
 * window is an absolute instant range; the date is the VENUE'S wall-clock day,
 * which is what the queue is ordered and swept by. Deriving one from the other
 * needs a timezone, and every place this codebase has guessed a timezone has
 * been wrong by two or three hours depending on the month.
 */
export class JoinWaitlistDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  restaurantId!: string;

  @ApiProperty({ example: '2026-08-12', description: "The VENUE'S wall-clock day." })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'desiredDate must be YYYY-MM-DD' })
  desiredDate!: string;

  @ApiProperty({ example: '2026-08-12T16:00:00.000Z', description: 'Absolute instant.' })
  @IsISO8601()
  windowStart!: string;

  @ApiProperty({ example: '2026-08-12T19:00:00.000Z' })
  @IsISO8601()
  windowEnd!: string;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 50 })
  @IsInt()
  @Min(1)
  @Max(50)
  partySize!: number;
}
