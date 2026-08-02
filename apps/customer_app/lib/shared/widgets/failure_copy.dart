/// The SINGLE translation point from a failure to words (ENGINEERING-STANDARDS
/// §7). Not per screen, not per feature.
///
/// Two levels, and the split is deliberate:
///
///   TITLE  ← the sealed [Failure] class. Seven of them, so the `switch` below
///            is exhaustive and Dart 3 makes a missing branch a COMPILE ERROR.
///            That is the mechanism that stops `OfflineFailure` from being
///            quietly forgotten, which on Egyptian connectivity is the most
///            common failure of all.
///   BODY   ← the backend `code`, through `errorCodeToArbKey`. The server's own
///            `message`/`message_ar` are a fallback for a code this BUILD does
///            not know — a server deployed ahead of the app is normal in
///            mobile, not an edge case.
library;

import 'package:sahra_localization/sahra_localization.dart';

import '../../core/error/failure.dart';
import '../../localization/generated/app_localizations.dart';

String failureTitle(Failure failure, AppLocalizations l10n) => switch (failure) {
      OfflineFailure() => l10n.errTitleOffline,
      NetworkFailure() => l10n.errTitleNetwork,
      AuthFailure() => l10n.errTitleAuth,
      ConflictFailure() => l10n.errTitleConflict,
      ValidationFailure() => l10n.errTitleValidation,
      ServerFailure() => l10n.errTitleServer,
      UnknownFailure() => l10n.errTitleUnknown,
    };

String failureMessage(Failure failure, AppLocalizations l10n) {
  if (failure is OfflineFailure) return l10n.errOffline;

  final key = failure.code == null ? null : errorCodeToArbKey[failure.code];
  final copy = key == null ? null : _byKey(l10n)[key];
  return copy ?? l10n.errUnknown;
}

/// ARB key → the generated getter.
///
/// `AppLocalizations` has no `String operator [](String key)`, and adding a
/// reflective lookup would defeat the point — the generated class is what
/// guarantees a key exists at compile time. This table is checked by
/// `failure_copy_test.dart`, which asserts EVERY value in `errorCodeToArbKey`
/// appears here: a backend code with no branch would otherwise fall through to
/// the generic "something went wrong", silently.
Map<String, String> _byKey(AppLocalizations l) => <String, String>{
      'errAccountUnavailable': l.errAccountUnavailable,
      'errBadRequest': l.errBadRequest,
      'errBookingsOutsideNewHours': l.errBookingsOutsideNewHours,
      'errCapacityConflictWithReservations': l.errCapacityConflictWithReservations,
      'errConflict': l.errConflict,
      'errDuplicateRequest': l.errDuplicateRequest,
      'errForbidden': l.errForbidden,
      'errForbiddenRole': l.errForbiddenRole,
      'errHoldExpired': l.errHoldExpired,
      'errInternalError': l.errInternalError,
      'errInvalidAvailabilityFilter': l.errInvalidAvailabilityFilter,
      'errInvalidCredentials': l.errInvalidCredentials,
      'errInvalidDate': l.errInvalidDate,
      'errInvalidIdempotencyKey': l.errInvalidIdempotencyKey,
      'errInvalidOtp': l.errInvalidOtp,
      'errInvalidPartySize': l.errInvalidPartySize,
      'errInvalidQueryParam': l.errInvalidQueryParam,
      'errInvalidSort': l.errInvalidSort,
      'errInvalidStatusTransition': l.errInvalidStatusTransition,
      'errMissingIdempotencyKey': l.errMissingIdempotencyKey,
      'errNotAnOwner': l.errNotAnOwner,
      'errNotFound': l.errNotFound,
      'errOtpExpired': l.errOtpExpired,
      'errOtpRateLimited': l.errOtpRateLimited,
      'errPacingLimitReached': l.errPacingLimitReached,
      'errPayloadTooLarge': l.errPayloadTooLarge,
      'errRateLimited': l.errRateLimited,
      'errReservationNotFound': l.errReservationNotFound,
      'errRestaurantNotFound': l.errRestaurantNotFound,
      'errSearchUnavailable': l.errSearchUnavailable,
      'errServiceBusy': l.errServiceBusy,
      'errServiceUnavailable': l.errServiceUnavailable,
      'errShiftNotFound': l.errShiftNotFound,
      'errShiftOverlap': l.errShiftOverlap,
      'errSlotTaken': l.errSlotTaken,
      'errSlugUnavailable': l.errSlugUnavailable,
      'errTableHasFutureReservations': l.errTableHasFutureReservations,
      'errTableNameTaken': l.errTableNameTaken,
      'errTableNotFound': l.errTableNotFound,
      'errTooManyAttempts': l.errTooManyAttempts,
      'errUnauthenticated': l.errUnauthenticated,
      'errUnprocessable': l.errUnprocessable,
      'errValidationFailed': l.errValidationFailed,
      'errOffline': l.errOffline,
      'errUnknown': l.errUnknown,
    };
