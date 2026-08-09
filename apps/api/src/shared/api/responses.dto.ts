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

  /**
   * The handle to the challenge just issued. Required, because an endpoint
   * that sends a code and does not return the handle to answer it is an
   * endpoint nobody can complete.
   */
  @ApiProperty({ description: 'Answer it at /auth/verify-otp.' })
  challengeId!: string;
}

/**
 * The handle to an unanswered challenge. Carries NOTHING else — no user id, no
 * hint about whether the number is registered, because issuing a challenge
 * involves no lookup (AUTH-3).
 */
export class OtpChallengeResponse {
  @ApiProperty({ description: 'Opaque. Answer it at /auth/verify-otp.' })
  challengeId!: string;
}

export class TokenPairResponse {
  @ApiProperty() accessToken!: string;
  @ApiProperty({ type: 'integer' }) expiresIn!: number;
  @ApiProperty() refreshToken!: string;
  @ApiProperty({ type: UserResponse }) user!: UserResponse;
}

/**
 * What answering a challenge produced.
 *
 * `status` is REQUIRED and non-nullable, so a client that fails to parse it
 * gets an error rather than silently reading "not signed in" from a missing
 * field. `tokens` is present only for `signed_in`.
 */
export class VerifyOtpResponse {
  @ApiProperty({ enum: ['signed_in', 'profile_needed'] })
  status!: 'signed_in' | 'profile_needed';

  @ApiPropertyOptional({ type: () => TokenPairResponse })
  tokens?: TokenPairResponse;
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

/**
 * One stored photo, in every size it exists in.
 *
 * `urls` IS A MAP KEYED BY WIDTH — "160", "400", "1200" — rather than three
 * named fields. The client picks the smallest that fits the slot it is drawing
 * into; adding a fourth size later is a server change and a client that
 * already knows how to choose, instead of a schema change and a release.
 *
 * NO CLIENT EVER BUILDS ONE OF THESE. The bucket, the CDN in front of it and
 * the path convention are deployment concerns, and a client that assembled
 * URLs itself would need re-releasing the day any of them moved.
 *
 * `width`/`height` are the ORIGINAL's, and they are not decoration: every
 * client reserves its box from this ratio before a byte arrives, so a list
 * does not reflow as photos land.
 */
export class ImageResponse {
  @ApiProperty() id!: string;

  @ApiProperty({
    type: 'object',
    additionalProperties: { type: 'string' },
    description: 'Width in px → public URL. Pick the smallest that fits.',
    example: { '160': 'https://…/160.webp', '400': '…', '1200': '…' },
  })
  urls!: Record<string, string>;

  @ApiProperty({ type: 'integer', description: "The ORIGINAL's width, for the aspect box." })
  width!: number;

  @ApiProperty({ type: 'integer' }) height!: number;
  @ApiProperty({ type: 'integer' }) position!: number;
  @ApiProperty({ description: 'The venue hero. Exactly one per owner.' }) is_cover!: boolean;
}

/**
 * One saved venue, in the shape a card draws.
 *
 * The venue FIELDS, not a venue id. A saved list of ids would mean one request
 * per row — twenty round trips over a Cairo mobile connection before the first
 * screenful can draw.
 */
export class SavedVenueResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty({ type: [String] }) cuisines!: string[];
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) price_band?: number | null;
  @ApiProperty() rating!: number;
  @ApiProperty({ type: 'integer' }) rating_count!: number;
  @ApiPropertyOptional({ type: ImageResponse, nullable: true }) cover?: ImageResponse | null;

  @ApiProperty({ description: 'When it was saved. Drives the newest-first order.' })
  saved_at!: string;
}

export class WaitlistVenueResponse {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty() city!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) neighborhood?: string | null;
}

/** A place in a queue for a table that is currently full (C-3.6). */
export class WaitlistEntryResponse {
  @ApiProperty() id!: string;

  @ApiProperty({ description: 'waiting | offered | converted | expired | cancelled' })
  status!: string;

  @ApiProperty({ description: "The VENUE'S wall-clock day, YYYY-MM-DD." })
  desired_date!: string;

  @ApiProperty({ description: 'Absolute instant. The earliest the diner will accept.' })
  window_start!: string;

  @ApiProperty({ description: 'And the latest. An offer outside this range is worse than none.' })
  window_end!: string;

  @ApiProperty({ type: 'integer' }) party_size!: number;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description:
      'Set only while `offered`. C-3.6 gives a 10-minute claim window, and a ' +
      'CHECK constraint ties the two together in both directions.',
  })
  offer_expires_at?: string | null;

  @ApiProperty({ type: WaitlistVenueResponse }) restaurant!: WaitlistVenueResponse;
}

// ─────────────────────────────────────────────── menus (R-2.3 / C-2.6) ──

export class MenuItemResponse {
  @ApiProperty() id!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) description_en?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) description_ar?: string | null;

  /**
   * A DECIMAL STRING, not a number. `NUMERIC(12,2)` through
   * `JSON.stringify(Number(...))` loses the scale — 320.00 arrives as `320` —
   * and CLAUDE.md rule 5's "never floats" does not stop being true at the wire.
   */
  @ApiProperty({ type: 'string', example: '320.00', description: 'Decimal string; never a float.' })
  price!: string;

  @ApiProperty({ example: 'EGP' }) currency!: string;

  @ApiProperty({
    type: [String],
    description:
      'From a fixed vocabulary a CHECK constraint enforces. We mark the ' +
      'exception, never the default — there is no `halal` tag, because in ' +
      'Cairo it is the default and marking it would imply the unmarked ' +
      'dishes are not.',
    example: ['vegetarian', 'spicy'],
  })
  dietary_tags!: string[];

  @ApiPropertyOptional({ type: ImageResponse, nullable: true }) image?: ImageResponse | null;
}

export class MenuCategoryResponse {
  @ApiProperty() id!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty({ type: [MenuItemResponse] }) items!: MenuItemResponse[];
}

export class MenuResponse {
  @ApiProperty() id!: string;
  @ApiProperty() name_en!: string;
  @ApiProperty() name_ar!: string;
  @ApiProperty({ description: 'food | drinks | ramadan | set' }) kind!: string;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description:
      'R-2.3 fallback for a venue whose menu is one scanned file. Composed ' +
      'from the stored key; the client hands it to the phone rather than ' +
      'rendering it.',
  })
  pdf_url?: string | null;

  @ApiProperty({
    type: [MenuCategoryResponse],
    description:
      'Available items only, ordered. A category whose items are all off ' +
      'tonight is omitted rather than sent empty.',
  })
  categories!: MenuCategoryResponse[];
}

// ───────────────────────────────────────────────────────── reviews (C-4.4) ──

export class ReviewResponse {
  @ApiProperty() id!: string;
  @ApiProperty({ type: 'integer', minimum: 1, maximum: 5 }) rating!: number;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) food_rating?: number | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) service_rating?: number | null;
  @ApiPropertyOptional({ type: 'integer', nullable: true }) ambience_rating?: number | null;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description: 'Nullable — stars alone is a complete review.',
  })
  body?: string | null;

  @ApiProperty({
    description:
      'First name and a surname initial ("Nour H."). Never the full name a ' +
      'diner gave at registration.',
    example: 'Nour H.',
  })
  author!: string;

  @ApiProperty() created_at!: string;

  @ApiPropertyOptional({ nullable: true, type: 'string' }) owner_reply?: string | null;
  @ApiPropertyOptional({ nullable: true, type: 'string' }) owner_replied_at?: string | null;
}

export class ReviewSummaryResponse {
  @ApiProperty({ description: 'Computed from the reviews themselves, not from the cached column.' })
  rating!: number;

  @ApiProperty({ type: 'integer' }) rating_count!: number;

  @ApiProperty({
    type: 'object',
    additionalProperties: { type: 'integer' },
    description: 'Star figure → how many gave it. Always all five keys.',
    example: { '5': 210, '4': 78, '3': 16, '2': 5, '1': 3 },
  })
  breakdown!: Record<string, number>;
}

export class ReviewPageResponse {
  @ApiProperty({ type: ReviewSummaryResponse }) summary!: ReviewSummaryResponse;
  @ApiProperty({ type: [ReviewResponse] }) results!: ReviewResponse[];

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description: 'Keyset, not offset — a new review must not shift page two.',
  })
  next_cursor?: string | null;
}

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

  @ApiPropertyOptional({
    type: ImageResponse,
    nullable: true,
    description:
      'The venue hero, or null. Fetched for the whole page in ONE query — a ' +
      'search list that asked per row would issue twenty requests over a ' +
      'Cairo mobile connection to render its first screenful.',
  })
  cover?: ImageResponse | null;
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
 * NOT present, because the schema has nowhere to put them yet: menus (no menu
 * tables, R-2.3). Omitted rather than returned empty, because an empty array
 * reads as "this venue has no menu" instead of "this platform cannot store
 * menus yet".
 *
 * Photos WERE on that list until Group B built the `images` table; `images` is
 * now a real field on this response.
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
  @ApiProperty({
    type: [ImageResponse],
    description:
      'The venue gallery, cover first then by position. Empty for a venue ' +
      'with no photos — which the client draws as a designed empty state, ' +
      'never as a broken image.',
  })
  images!: ImageResponse[];

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

  @ApiProperty({
    description:
      'Whether POST /reviews would accept this visit right now — seated or ' +
      'completed, the table time is over, and not already reviewed. DERIVED ' +
      'ON THE SERVER from the same function the endpoint enforces, so the ' +
      'control the client draws cannot disagree with the answer it gets.',
  })
  can_review!: boolean;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description: 'The review this visit already has. Null is the common case.',
  })
  review_id?: string | null;

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

/** doc 06 §3 — `/devices`. */
export class DeviceResponse {
  @ApiProperty() id!: string;
  @ApiProperty({ description: 'Always true; the call is an upsert.' })
  registered!: boolean;
}

// ──────────────────────────────────────────────────── notifications (C-4.7) ──

export class NotificationResponse {
  @ApiProperty() id!: string;

  @ApiProperty({
    description:
      'Machine-readable kind. THE CLIENT OWNS THE COPY, keyed by this — the ' +
      'same rule as the doc 06 §1 error codes. The server renders text only ' +
      'for a lock screen, where there is no client to localise anything.',
  })
  type!: string;

  @ApiProperty({
    type: 'object',
    // STRING VALUES, DECLARED. Not `additionalProperties: true`.
    //
    // The keys vary by type, so the object is genuinely free-form in its shape
    // — but every value is a string, because `NotifyInput.data` is
    // `Record<string, string>` and FCM's data payload is a string map anyway.
    // Declaring that gets the generated Dart field typed `Map<String, String>`
    // instead of `Map<String, dynamic>`, which is the difference between a
    // client that fails at compile time and one that fails in a diner's hand.
    //
    // It also keeps this off the free-form allowlist in
    // `client_drift_test.dart`, which currently has exactly one entry and is
    // worth keeping that way.
    additionalProperties: { type: 'string' },
    description:
      'Substitutions for the copy, and the deep-link target. Keys vary by ' +
      'type; `reservation_id` and `restaurant_id` are what the client routes ' +
      'on when present. Values are always strings.',
  })
  data!: Record<string, string>;

  @ApiProperty({ description: 'When we owed them this. ISO 8601, UTC.' })
  created_at!: string;

  @ApiPropertyOptional({
    nullable: true,
    type: 'string',
    description:
      'When they FIRST saw it — never re-stamped on a later read. Null while ' +
      'unread.',
  })
  read_at?: string | null;
}

export class NotificationListResponse {
  @ApiProperty({ type: [NotificationResponse] })
  items!: NotificationResponse[];

  @ApiProperty({
    type: 'integer',
    description:
      'Unread across the WHOLE history, not across `items`. A count of the ' +
      'page would read zero for a diner with more notifications than one page.',
  })
  unread_count!: number;
}

export class MarkReadResponse {
  @ApiProperty({
    type: 'integer',
    description:
      'How many rows this call changed. Zero is an ordinary outcome — ' +
      'everything was already read — and is what makes "it did nothing" ' +
      'distinguishable in a test rather than assumed.',
  })
  marked!: number;

  @ApiProperty({ type: 'integer', description: 'Unread remaining, after this call.' })
  unread_count!: number;
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
