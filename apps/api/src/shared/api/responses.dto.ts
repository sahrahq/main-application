import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * Response shapes, declared so the OpenAPI document describes what comes BACK
 * and not only what goes in.
 *
 * Without these the spec has request schemas and untyped responses, and a
 * generated client is forced into `Map<String, dynamic>` on every call — which
 * moves every rename, every removed field and every changed type from a
 * compile error to a runtime surprise in a screen. That is the one guarantee
 * the client exists to provide, so `tool/generate_client.dart` REFUSES to emit
 * an operation whose success response has no schema. Adding an endpoint without
 * a response DTO fails the build rather than quietly producing `dynamic`.
 *
 * These are documentation types. The services keep returning their own
 * interfaces; these describe the wire shape for the generator.
 */

// ───────────────────────────────────────────────────────────────────── auth ──

export class UserResponse {
  @ApiProperty() id!: string;
  @ApiProperty() phone!: string;
  @ApiPropertyOptional({ nullable: true }) email?: string | null;
  @ApiProperty() fullName!: string;
  @ApiProperty() locale!: string;
  @ApiProperty() status!: string;
  @ApiProperty({ type: [String] }) roles!: string[];
}

export class RegisterResponse {
  @ApiProperty() userId!: string;
  @ApiProperty() otpRequired!: boolean;
}

export class TokenPairResponse {
  @ApiProperty() accessToken!: string;
  @ApiProperty({ type: 'integer' }) expiresIn!: number;
  @ApiProperty() refreshToken!: string;
  @ApiProperty({ type: UserResponse }) user!: UserResponse;
}

export class OtpSentResponse {
  @ApiProperty() sent!: boolean;
  @ApiProperty({ description: 'Seconds until another code may be requested.' })
  retryAfter!: number;
}

// ───────────────────────────────────────────────────────────── availability ──

export class SlotResponse {
  @ApiProperty({ description: "HH:MM on the RESTAURANT'S wall clock." })
  time!: string;

  @ApiProperty({ description: 'Absolute instant, ISO-8601 UTC. POST this back.' })
  startsAt!: string;

  @ApiProperty({ type: [String] }) zones!: string[];
}

export class AvailabilityResponse {
  @ApiProperty() date!: string;
  @ApiProperty({ type: 'integer' }) partySize!: number;
  @ApiProperty({ description: 'IANA zone the `time` fields are expressed in.' })
  timezone!: string;
  @ApiProperty({ type: [SlotResponse] }) slots!: SlotResponse[];
}

// ─────────────────────────────────────────────────────────────────── search ──

export class SearchResultResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty({ type: [String] }) cuisines!: string[];
  @ApiPropertyOptional({ nullable: true }) neighborhood?: string | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) price_band?: number | null;
  @ApiProperty() rating!: number;
  @ApiProperty({ type: 'integer' }) rating_count!: number;
  @ApiPropertyOptional() distance_km?: number;

  @ApiPropertyOptional({
    type: [String],
    description:
      'Local HH:MM teasers. A HINT, not an offer — no absolute instant is ' +
      'given precisely so no client can treat one as bookable.',
  })
  next_available?: string[];
}

export class SearchResponse {
  @ApiProperty({ type: [SearchResultResponse] }) results!: SearchResultResponse[];
  @ApiPropertyOptional({ nullable: true }) next_cursor?: string | null;
  @ApiProperty({ type: 'integer' }) estimated_total!: number;
  @ApiProperty() availability_filtered!: boolean;
}

// ───────────────────────────────────────────────────────────── reservations ──

export class ReservationTableResponse {
  @ApiProperty() tableId!: string;
}

export class ReservationResponse {
  @ApiProperty() id!: string;
  @ApiProperty() code!: string;
  @ApiProperty() restaurantId!: string;
  @ApiPropertyOptional({ nullable: true }) userId?: string | null;
  @ApiPropertyOptional({ nullable: true }) guestName?: string | null;
  @ApiPropertyOptional({ nullable: true }) guestPhone?: string | null;
  @ApiProperty({ type: 'integer' }) partySize!: number;
  @ApiProperty() startsAt!: string;
  @ApiProperty() endsAt!: string;
  @ApiProperty() status!: string;
  @ApiProperty() source!: string;
  @ApiPropertyOptional({ nullable: true }) holdExpiresAt?: string | null;
  @ApiPropertyOptional({ type: [ReservationTableResponse] })
  tables?: ReservationTableResponse[];
}

// ──────────────────────────────────────────────────────────── owner: venue ──

export class RestaurantResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() status!: string;
  @ApiProperty() nameEn!: string;
  @ApiProperty() nameAr!: string;
  @ApiPropertyOptional({ nullable: true }) descriptionEn?: string | null;
  @ApiPropertyOptional({ nullable: true }) descriptionAr?: string | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) priceBand?: number | null;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ nullable: true }) neighborhood?: string | null;
}

export class TableResponse {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ type: 'integer' }) minCapacity!: number;
  @ApiProperty({ type: 'integer' }) maxCapacity!: number;
  @ApiProperty() zone!: string;
  @ApiProperty({ type: 'integer' }) priority!: number;
  @ApiProperty({ type: [String] }) combinableWith!: string[];
  @ApiProperty() active!: boolean;
}

export class RemoveTableResponse {
  @ApiProperty({ description: 'True only when the table had never been used.' })
  deleted!: boolean;
  @ApiProperty({ description: 'True when it was retired so history survives.' })
  deactivated!: boolean;
}

export class ShiftResponse {
  @ApiProperty() id!: string;
  @ApiProperty() nameEn!: string;
  @ApiProperty() nameAr!: string;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) dayOfWeek?: number | null;
  @ApiPropertyOptional({ nullable: true }) specificDate?: string | null;
  @ApiProperty() opensAt!: string;
  @ApiProperty() closesAt!: string;
  @ApiProperty() spansMidnight!: boolean;
  @ApiProperty({ type: Object }) defaultTurnMinutes!: Record<string, number>;
  @ApiProperty() isRamadan!: boolean;
  @ApiProperty() active!: boolean;
}

export class ShiftWriteResponse {
  @ApiProperty({ type: ShiftResponse }) shift!: ShiftResponse;

  @ApiProperty({
    type: [String],
    description:
      'Live future bookings now outside the shift. NEVER cancelled — returned ' +
      'so the restaurant can contact those guests.',
  })
  reservationsOutsideHours!: string[];
}

export class RemoveShiftResponse {
  @ApiProperty() deleted!: boolean;
  @ApiProperty({ type: [String] }) reservationsOutsideHours!: string[];
}

// ───────────────────────────────────────────────────────── owner: the book ──

export class BookRowResponse {
  @ApiProperty() id!: string;
  @ApiProperty() code!: string;
  @ApiProperty({ description: "HH:MM in the restaurant's local time." })
  time!: string;
  @ApiProperty() startsAt!: string;
  @ApiProperty({ type: 'integer' }) partySize!: number;
  @ApiProperty() status!: string;
  @ApiProperty({ description: 'app | walk_in | phone — which door it came through.' })
  source!: string;
  @ApiPropertyOptional({ nullable: true }) guestName?: string | null;
  @ApiPropertyOptional({ nullable: true }) guestPhone?: string | null;
  @ApiPropertyOptional({ nullable: true }) specialRequests?: string | null;
  @ApiPropertyOptional({ nullable: true }) occasion?: string | null;
  @ApiProperty({ type: [String] }) tables!: string[];
}

export class BookResponse {
  @ApiProperty() date!: string;
  @ApiProperty() timezone!: string;
  @ApiProperty({ type: [BookRowResponse] }) reservations!: BookRowResponse[];
}

// ──────────────────────────────────────────────────────────────────── admin ──

export class AdminRestaurantResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() status!: string;
  @ApiProperty() nameEn!: string;
  @ApiProperty() nameAr!: string;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ nullable: true }) neighborhood?: string | null;
}

// ──────────────────────────────────────────────────────────────────── error ──

export class ErrorDetailResponse {
  @ApiProperty() field!: string;
  @ApiProperty() issue!: string;
}

export class ApiErrorBody {
  @ApiProperty({ description: 'The only field a client should branch on.' })
  code!: string;
  @ApiProperty() message!: string;
  @ApiProperty() message_ar!: string;
  @ApiPropertyOptional({ type: [ErrorDetailResponse] })
  details?: ErrorDetailResponse[];
  @ApiPropertyOptional() retry_after?: number;
  @ApiProperty() request_id!: string;
}

/** doc 06 §1 — every error, everywhere. */
export class ApiErrorResponse {
  @ApiProperty({ type: ApiErrorBody }) error!: ApiErrorBody;
}
