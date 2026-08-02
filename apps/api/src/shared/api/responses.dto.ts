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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) email?: string | null;
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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) price_band?: number | null;
  @ApiProperty() rating!: number;
  @ApiProperty({ type: 'integer' }) rating_count!: number;
  @ApiPropertyOptional({ type: 'number' }) distance_km?: number;

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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) next_cursor?: string | null;
  @ApiProperty({ type: 'integer' }) estimated_total!: number;
  @ApiProperty() availability_filtered!: boolean;
}

// ─────────────────────────────────────────────────── public venue profile ──

export class OpeningHoursResponse {
  @ApiPropertyOptional({ type: 'integer', nullable: true, description: '0=Sunday; null on a one-off date' })
  day_of_week?: number | null;
  @ApiPropertyOptional({ nullable: true, type: 'string', description: 'YYYY-MM-DD; null on a weekly row' })
  specific_date?: string | null;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty({ description: "HH:MM on the restaurant's wall clock." }) opens_at!: string;
  @ApiProperty() closes_at!: string;
  @ApiProperty() spans_midnight!: boolean;
}

/**
 * doc 06 §3 `/restaurants/:idOrSlug`. snake_case to match the search result
 * item in the same section — this is the same entity a diner just tapped.
 *
 * NOT present, because the schema has nowhere to put them yet: photos (no
 * image table, R-2.2) and menus (no menu tables, R-2.3). They are omitted
 * rather than returned empty, because an empty array reads as "this venue has
 * no photos" instead of "this platform cannot store photos yet".
 */
export class RestaurantProfileResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) description_en?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) description_ar?: string | null;
  @ApiProperty({ type: [String] }) cuisines!: string[];
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) address_en?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) address_ar?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'number' }) lat?: number | null;
  @ApiPropertyOptional({ nullable: true, type: 'number' }) lng?: number | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) price_band?: number | null;
  @ApiProperty() rating!: number;
  @ApiProperty({ type: 'integer' }) rating_count!: number;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) phone?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) website?: string | null;
  @ApiProperty({ type: [String] }) amenities!: string[];
  @ApiPropertyOptional({ type: 'object', additionalProperties: true, nullable: true })
  policies?: Record<string, unknown> | null;
  @ApiProperty({ description: 'IANA zone every wall-clock time here is in.' })
  timezone!: string;
  @ApiProperty({ description: 'instant | request' }) booking_mode!: string;
  @ApiProperty({ type: [OpeningHoursResponse] }) hours!: OpeningHoursResponse[];
}

// ───────────────────────────────────────────────────────────── reservations ──

export class ReservationTableResponse {
  @ApiProperty() tableId!: string;
}

export class ReservationResponse {
  @ApiProperty() id!: string;
  @ApiProperty() code!: string;
  @ApiProperty() restaurantId!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) userId?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) guestName?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) guestPhone?: string | null;
  @ApiProperty({ type: 'integer' }) partySize!: number;
  @ApiProperty() startsAt!: string;
  @ApiProperty() endsAt!: string;
  @ApiProperty() status!: string;
  @ApiProperty() source!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) holdExpiresAt?: string | null;
  @ApiPropertyOptional({ type: [ReservationTableResponse] })
  tables?: ReservationTableResponse[];
}

/** The venue block carried inside a diner's own reservation. */
export class ReservationVenueResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
  @ApiProperty() city!: string;
  @ApiProperty({ description: 'IANA zone `date` and `time` are expressed in.' })
  timezone!: string;
}

/**
 * doc 06 §3 `/reservations` and `/reservations/:id` — the DINER's view.
 *
 * snake_case, matching the search result and the public venue profile: these
 * are the customer-facing reads and a client should not switch convention
 * between them.
 *
 * Carries the instant AND the venue wall clock. `starts_at` is what the server
 * accepts and compares; `date`/`time` are what a diner reads. A client
 * deriving the second from the first plus a guessed timezone is 2–3 hours out
 * in Cairo depending on the date.
 */
export class MyReservationResponse {
  @ApiProperty() id!: string;
  @ApiProperty({ description: 'Human-readable, quoted at the door. e.g. SAH-7K2M' })
  code!: string;
  @ApiProperty({ description: 'pending | confirmed | seated | completed | no_show | cancelled_*' })
  status!: string;
  @ApiProperty({ description: 'app | walk_in | phone — which door it came through.' })
  source!: string;
  @ApiProperty({ description: 'Absolute instant, ISO-8601 UTC.' }) starts_at!: string;
  @ApiProperty() ends_at!: string;
  @ApiProperty({ description: "YYYY-MM-DD on the RESTAURANT'S wall clock." }) date!: string;
  @ApiProperty({ description: "HH:MM on the RESTAURANT'S wall clock." }) time!: string;
  @ApiProperty({ type: 'integer' }) party_size!: number;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) special_requests?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) occasion?: string | null;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description: "'user' | 'restaurant' | null. Derived, so no client parses a status string.",
  })
  cancelled_by?: string | null;

  @ApiPropertyOptional({ nullable: true, type: 'string' }) cancelled_at?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) cancel_reason?: string | null;

  @ApiProperty({
    description:
      'The RESTAURANT cancelled and the diner has not seen it yet. THE CLIENT ' +
      'MUST SURFACE THIS. It is the only signal that a booking they believe ' +
      'they hold is gone, and a reservation carrying it stays in `upcoming` ' +
      'regardless of date until POST /reservations/{id}/acknowledge-cancellation.',
  })
  needs_acknowledgement!: boolean;

  @ApiProperty({ type: ReservationVenueResponse }) restaurant!: ReservationVenueResponse;
}

// ──────────────────────────────────────────────────────────── owner: venue ──

export class RestaurantResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() status!: string;
  @ApiProperty() nameEn!: string;
  @ApiProperty() nameAr!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) descriptionEn?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) descriptionAr?: string | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) priceBand?: number | null;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) specificDate?: string | null;
  @ApiProperty() opensAt!: string;
  @ApiProperty() closesAt!: string;
  @ApiProperty() spansMidnight!: boolean;
  @ApiProperty({ type: 'object', additionalProperties: { type: 'integer' },
    description: 'Party-size band → turn minutes, e.g. {"1-2":90}.' })
  defaultTurnMinutes!: Record<string, number>;
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

/** doc 06 §4 — what a venue gets back after cancelling a booking. */
export class CancelledReservationResponse {
  @ApiProperty() id!: string;
  @ApiProperty() code!: string;
  @ApiProperty({ description: 'Always `cancelled_by_restaurant`.' }) status!: string;
  @ApiProperty() cancelled_at!: string;
  @ApiProperty({ description: 'Shown to the diner verbatim.' }) cancel_reason!: string;
  @ApiProperty() starts_at!: string;
  @ApiProperty({ type: 'integer' }) party_size!: number;

  @ApiProperty({
    description:
      'True when the table this booking held is now available again. Released ' +
      'by trg_resv_propagate, which flips reservation_tables.active off for ' +
      'any status outside held|pending|confirmed|seated.',
  })
  table_released!: boolean;
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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) guestName?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) guestPhone?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) specialRequests?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) occasion?: string | null;
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
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
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
  @ApiPropertyOptional({ type: 'number' }) retry_after?: number;
  @ApiProperty() request_id!: string;
}

/** doc 06 §1 — every error, everywhere. */
export class ApiErrorResponse {
  @ApiProperty({ type: ApiErrorBody }) error!: ApiErrorBody;
}
