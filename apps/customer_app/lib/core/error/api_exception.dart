/// The doc 06 §1 envelope, parsed.
///
/// ```json
/// { "error": { "code", "message", "message_ar", "details", "retry_after",
///              "request_id" } }
/// ```
///
/// Thrown by the transport, consumed by `mapFailure`, and seen by nothing
/// else. `message` and `message_ar` are kept because they are the fallback for
/// a code this build does not know about — a server deployed ahead of the app
/// is the normal case in mobile, not an edge case.
library;

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    this.message,
    this.messageAr,
    this.requestId,
    this.retryAfter,
    this.details = const <MapEntry<String, String>>[],
    this.alternatives = const <String>[],
  });

  final int statusCode;
  final String code;
  final String? message;
  final String? messageAr;
  final String? requestId;
  final int? retryAfter;
  final List<MapEntry<String, String>> details;

  /// doc 06 §6 — "409s on booking always include `alternatives`".
  final List<String> alternatives;

  /// Parse an error body. Never throws: a malformed error body must not
  /// replace the real failure with a parse failure, because the real failure
  /// is the one worth reporting.
  factory ApiException.fromEnvelope(int statusCode, Object? body) {
    if (body is! Map) {
      return ApiException(statusCode: statusCode, code: _codeForStatus(statusCode));
    }
    final error = body['error'];
    if (error is! Map) {
      return ApiException(statusCode: statusCode, code: _codeForStatus(statusCode));
    }

    final rawDetails = error['details'];
    final details = <MapEntry<String, String>>[];
    if (rawDetails is List) {
      for (final d in rawDetails) {
        if (d is Map && d['field'] != null) {
          details.add(MapEntry('${d['field']}', '${d['issue'] ?? ''}'));
        }
      }
    }

    final rawAlternatives = error['alternatives'];
    final alternatives =
        rawAlternatives is List ? rawAlternatives.whereType<String>().toList() : const <String>[];

    return ApiException(
      statusCode: statusCode,
      code: error['code'] is String ? error['code'] as String : _codeForStatus(statusCode),
      message: error['message'] as String?,
      messageAr: error['message_ar'] as String?,
      requestId: error['request_id'] as String?,
      retryAfter: error['retry_after'] is num ? (error['retry_after'] as num).toInt() : null,
      details: details,
      alternatives: alternatives,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $code, request_id=$requestId)';
}

/// A last resort for a body that carried no code at all. Kept aligned with the
/// generic codes in `errorCodeToArbKey`, so even this path lands on real copy.
String _codeForStatus(int status) => switch (status) {
      400 => 'bad_request',
      401 => 'unauthenticated',
      403 => 'forbidden',
      404 => 'not_found',
      409 => 'conflict',
      422 => 'unprocessable',
      429 => 'rate_limited',
      503 => 'service_unavailable',
      _ => status >= 500 ? 'internal_error' : 'unknown',
    };
