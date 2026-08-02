import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sahra_api_client/sahra_api_client.dart';

import '../error/api_exception.dart';
import '../error/failure_mapper.dart';

/// The `SahraTransport` port, over Dio (doc 07 §2 `core/network`).
///
/// The generated client knows nothing about Dio — it takes this port, so the
/// package stays pure Dart and tests hand it a fake with no socket. Everything
/// cross-cutting lives here and nowhere else: locale, app version, request id,
/// and the translation of a `DioException` into the doc 06 §1 envelope.
///
/// ONE RULE ABOUT RETRIES, and it is a product decision rather than a
/// networking one: reads may be retried, mutations may not. A hold or a
/// confirm carries an `Idempotency-Key` precisely so that a retry is safe, but
/// retrying automatically would hide a `slot_taken` behind a spinner and
/// present the diner with a booking they never saw succeed. doc 07 §3 puts an
/// offline mutation queue in the OWNER console and explicitly keeps it out of
/// the customer app for the same reason.
class DioTransport implements SahraTransport {
  DioTransport({
    required String baseUrl,
    required String Function() localeCode,
    Dio? dio,
  })  : _localeCode = localeCode,
        _dio = (dio ?? Dio())
          ..options.baseUrl = baseUrl
          ..options.connectTimeout = const Duration(seconds: 8)
          ..options.receiveTimeout = const Duration(seconds: 15)
          // Every status is "successful" as far as Dio is concerned, so this
          // class — not Dio's own exception shape — decides what an error is.
          // Without it a 409 arrives as a DioException whose response body has
          // to be dug out of two nullable fields at the point of use.
          ..options.validateStatus = _anyStatusIsHandledHere;

  final Dio _dio;
  final String Function() _localeCode;

  @override
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: <String, String>{
            // doc 06 §1 — the server sends BOTH languages on every error, so
            // this selects localized CONTENT, never which message we show.
            'Accept-Language': _localeCode(),
            'X-App-Version': _appVersion,
            ...?headers,
          },
        ),
      );
    } on DioException catch (e) {
      throw _translate(e);
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return response.data;
    throw ApiException.fromEnvelope(status, response.data);
  }

  /// Offline and "the network misbehaved" are different failures with
  /// different advice, and Dio does not distinguish them — `connectionError`
  /// covers both a flight-mode phone and a server that is not listening.
  ///
  /// Drawn here rather than in a screen because it is the only place with
  /// enough information, and because leaving it to screens guarantees three
  /// screens draw it three ways.
  Object _translate(DioException e) => switch (e.type) {
        // Not a wildcard: every member is listed so a new DioExceptionType in
        // a future Dio release is a COMPILE ERROR here rather than a silent
        // fall-through to "offline" for something that is not.
        DioExceptionType.connectionError => const OfflineException(),
        DioExceptionType.connectionTimeout => const OfflineException(),
        DioExceptionType.sendTimeout => const TransportException('send timeout'),
        DioExceptionType.receiveTimeout => const TransportException('receive timeout'),
        DioExceptionType.badCertificate => const TransportException('bad certificate'),
        DioExceptionType.cancel => const TransportException('cancelled'),
        DioExceptionType.badResponse => ApiException.fromEnvelope(
            e.response?.statusCode ?? 0,
            e.response?.data,
          ),
        DioExceptionType.transformTimeout => const TransportException('transform timeout'),
        DioExceptionType.unknown => e.error is FormatException
            ? const TransportException('malformed body')
            : const OfflineException(),
      };
}

/// Every status reaches [DioTransport.send], which decides what an error is.
/// Named rather than an inline `(_) => true` so the reason survives: Dio's own
/// exception shape buries a 409's body in two nullable fields, and the booking
/// flow reads that body on its most important path.
bool _anyStatusIsHandledHere(int? status) => true;

/// doc 06 §1: "Mobile clients send `X-App-Version`; server can force-upgrade
/// via 426". Read from the build, not hardcoded per call site.
const String _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
