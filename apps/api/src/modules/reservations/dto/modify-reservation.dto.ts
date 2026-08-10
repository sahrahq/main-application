import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsISO8601, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

/**
 * C-3.4 — what a diner may change about a booking they already hold.
 *
 * TWO FIELDS, AND THAT IS THE WHOLE LIST. Time and party size are the two
 * things that re-check availability, which is the only reason this route goes
 * through the reservation engine at all. `specialRequests` and `occasion` are
 * deliberately absent: they are free text nobody re-allocates a table for, and
 * putting them here would mean a note change and a table move share one code
 * path, one lock and one failure mode.
 *
 * Both optional, neither meaningful alone — a body naming neither is refused
 * rather than treated as a successful no-op. `class-validator` cannot express
 * "at least one of", so the handler checks it and returns the same
 * `validation_failed` envelope (doc 06 §1) that a bad value would.
 */
export class ModifyReservationDto {
  @ApiPropertyOptional({
    example: '2026-08-09T17:00:00.000Z',
    description: 'The new start, ISO-8601 UTC. Must be in the future.',
  })
  @IsOptional()
  @IsISO8601()
  startsAt?: string;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 50, example: 4 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  partySize?: number;
}

/**
 * The diner's cancellation.
 *
 * `reason` IS OPTIONAL HERE, and REQUIRED on the venue's route. That asymmetry
 * is the design, not an oversight:
 *
 *   - the venue's reason is read by a human whose table just vanished, and
 *     "your booking is cancelled" with no cause is the message that loses the
 *     customer for good
 *   - the diner's reason is read by nobody with those stakes, and demanding
 *     one would make cancelling fractionally harder than simply not turning
 *     up — which is the outcome this endpoint exists to prevent
 */
export class CancelOwnReservationDto {
  @ApiPropertyOptional({ maxLength: 280, description: 'Optional. Free text, for the venue.' })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  reason?: string;
}
