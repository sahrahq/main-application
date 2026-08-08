/// The single mapping from a backend error `code` to an ARB key.
///
/// doc 06 §1 sends `{ error: { code, message, message_ar, details, request_id } }`.
/// The server's own `message`/`message_ar` are a FALLBACK for a code this
/// client does not know — never the primary path. The client owns its copy and
/// its tone; a server string written for an API consumer is not the sentence a
/// diner should read when their table is gone.
///
/// `error_code_coverage_test.dart` extracts every `code: '…'` literal from
/// `apps/api/src` and fails if any is missing here or from either ARB file. A
/// backend error added without client copy breaks the Flutter suite, which is
/// the only mechanism that keeps the two halves of this repo honest with each
/// other.
library;

/// backend code → ARB key.
const Map<String, String> errorCodeToArbKey = <String, String>{
  'account_unavailable': 'errAccountUnavailable',
  'bad_request': 'errBadRequest',
  'bookings_outside_new_hours': 'errBookingsOutsideNewHours',
  'capacity_conflict_with_reservations': 'errCapacityConflictWithReservations',
  'conflict': 'errConflict',
  'duplicate_request': 'errDuplicateRequest',
  'forbidden': 'errForbidden',
  'forbidden_role': 'errForbiddenRole',
  'hold_expired': 'errHoldExpired',
  'internal_error': 'errInternalError',
  'invalid_availability_filter': 'errInvalidAvailabilityFilter',
  'invalid_credentials': 'errInvalidCredentials',
  'invalid_date': 'errInvalidDate',
  'invalid_idempotency_key': 'errInvalidIdempotencyKey',
  'invalid_otp': 'errInvalidOtp',
  'invalid_party_size': 'errInvalidPartySize',
  'invalid_query_param': 'errInvalidQueryParam',
  'invalid_sort': 'errInvalidSort',
  'invalid_status_transition': 'errInvalidStatusTransition',
  'image_not_found': 'errImageNotFound',
  'image_too_large': 'errImageTooLarge',
  'invalid_image': 'errInvalidImage',
  'storage_unavailable': 'errStorageUnavailable',
  'unsupported_image_type': 'errUnsupportedImageType',
  'missing_idempotency_key': 'errMissingIdempotencyKey',
  'not_an_owner': 'errNotAnOwner',
  'not_found': 'errNotFound',
  'otp_expired': 'errOtpExpired',
  'otp_rate_limited': 'errOtpRateLimited',
  'otp_sending_unavailable': 'errOtpSendingUnavailable',
  'pacing_limit_reached': 'errPacingLimitReached',
  'payload_too_large': 'errPayloadTooLarge',
  'rate_limited': 'errRateLimited',
  'reservation_not_found': 'errReservationNotFound',
  'reservation_not_modifiable': 'errReservationNotModifiable',
  'restaurant_not_found': 'errRestaurantNotFound',
  'search_unavailable': 'errSearchUnavailable',
  'service_busy': 'errServiceBusy',
  'service_unavailable': 'errServiceUnavailable',
  'shift_not_found': 'errShiftNotFound',
  'shift_overlap': 'errShiftOverlap',
  'slot_taken': 'errSlotTaken',
  'slug_unavailable': 'errSlugUnavailable',
  'table_has_future_reservations': 'errTableHasFutureReservations',
  'table_name_taken': 'errTableNameTaken',
  'table_not_found': 'errTableNotFound',
  'too_many_attempts': 'errTooManyAttempts',
  'unauthenticated': 'errUnauthenticated',
  'unprocessable': 'errUnprocessable',
  'validation_failed': 'errValidationFailed',
};

/// Client-side conditions the server never sends a code for.
///
/// `errOffline` is here rather than in the map above because offline is not a
/// response — it is the absence of one. It is a first-class member of the
/// `Failure` hierarchy (ENGINEERING-STANDARDS §7) precisely so a Dart 3
/// exhaustive switch makes forgetting it a compile error.
const Set<String> clientOnlyArbKeys = <String>{
  'errOffline',
  'errUnknown',
};
