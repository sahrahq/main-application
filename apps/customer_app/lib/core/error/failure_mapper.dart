import 'api_exception.dart';
import 'failure.dart';

/// `ApiException` → `Failure`. One file, ENGINEERING-STANDARDS §7.
///
/// Status code decides the CLASS; the backend `code` decides the COPY. That
/// split matters: `slot_taken` and `hold_expired` are both 409s handled the
/// same structural way (offer somewhere else to go) while reading completely
/// differently to a diner.
Failure mapFailure(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      401 => AuthFailure(code: error.code, requestId: error.requestId),
      403 => AuthFailure(code: error.code, requestId: error.requestId),
      400 || 422 => ValidationFailure(
          code: error.code,
          requestId: error.requestId,
          details: error.details.map((e) => FieldIssue(e.key, e.value)).toList(),
        ),
      409 => ConflictFailure(
          code: error.code,
          requestId: error.requestId,
          alternatives: error.alternatives,
        ),
      429 => ServerFailure(
          code: error.code,
          requestId: error.requestId,
          retryAfterSeconds: error.retryAfter,
        ),
      _ => error.statusCode >= 500
          ? ServerFailure(
              code: error.code,
              requestId: error.requestId,
              retryAfterSeconds: error.retryAfter,
            )
          : UnknownFailure(code: error.code, requestId: error.requestId),
    };
  }

  if (error is OfflineException) return const OfflineFailure();
  if (error is TransportException) return const NetworkFailure();
  if (error is Failure) return error;
  return const UnknownFailure();
}

/// The phone has no usable connection. Raised by the transport, never by Dio
/// directly — see the note in dio_transport.dart about why this distinction is
/// drawn there and not in a screen.
class OfflineException implements Exception {
  const OfflineException();
}

/// Reached the network, and it failed anyway: timeout, reset, malformed body.
class TransportException implements Exception {
  const TransportException(this.detail);
  final String detail;

  @override
  String toString() => 'TransportException($detail)';
}
