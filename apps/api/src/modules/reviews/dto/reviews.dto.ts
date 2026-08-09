import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

/**
 * doc 06 §Reviews:
 * `{reservation_id, rating, food_rating?, service_rating?, ambience_rating?,
 *   body?, photo_ids?}`
 *
 * `photo_ids` IS DELIBERATELY ABSENT. C-4.4 wants review photos and the
 * `images` table already has a `review` owner type, so the field would have
 * been cheap to accept — and accepting a field nothing stores is worse than
 * not having it: a client that sends photo ids and gets a 201 has every reason
 * to believe the photos are attached.
 *
 * The reason it is out of scope is a boundary, not a backlog. From
 * `docs/decisions/2026-08-09-hand-rolled-multipart.md`: the parser "handles
 * ADMIN-AUTHENTICATED input only and must never be reused for an
 * unauthenticated or diner-facing upload path". A diner uploading a photo of
 * their dinner is exactly that path, and it is the moment to revisit the
 * `multer` dependency rather than extend the parser.
 *
 * `forbidNonWhitelisted: true` is global, so sending `photo_ids` is a 400 with
 * a named field rather than a silent drop. That is the behaviour we want: it
 * says no out loud.
 */
export class CreateReviewDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  reservationId!: string;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  foodRating?: number;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  serviceRating?: number;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  ambienceRating?: number;

  /**
   * 2000 to match the CHECK constraint. Validated in both places on purpose:
   * the constraint is the guarantee, this is the error message. A diner who
   * writes 2001 characters should be told which field and by how much, not
   * handed a database exception.
   */
  @ApiPropertyOptional({ maxLength: 2000 })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  body?: string;
}
