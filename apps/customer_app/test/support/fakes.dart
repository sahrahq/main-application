import 'package:sahra_api_client/sahra_api_client.dart';

import 'package:sahra_customer_app/core/error/api_exception.dart';
import 'package:sahra_customer_app/core/error/failure_mapper.dart';

/// A transport with no socket.
///
/// The generated client takes a `SahraTransport` port precisely so this is
/// possible: every test below drives the REAL `SahraApi`, the REAL repository
/// and the REAL notifier, and only the wire is fake. A test that stubbed the
/// repository instead would prove the screen works against a mock and nothing
/// about whether the client decodes what the server actually sends.
class FakeTransport implements SahraTransport {
  FakeTransport(this.handler);

  /// (method, path) → decoded body, or throw.
  final Object? Function(String method, String path, Map<String, String>? query) handler;

  final List<String> calls = <String>[];

  @override
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    calls.add('$method $path');
    // Every mutation must carry one (doc 06 §1). Asserted here rather than in
    // one test, so a call site that forgets it fails wherever it is exercised.
    if (method != 'GET') {
      final key = headers?['idempotency-key'];
      if (key == null || !_uuidV4.hasMatch(key)) {
        throw StateError('$method $path was sent without a UUID v4 Idempotency-Key');
      }
    }
    return handler(method, path, query);
  }
}

final RegExp _uuidV4 =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// The doc 06 §1 envelope, as the server would send it.
ApiException envelope(int status, String code, {List<String> alternatives = const <String>[]}) =>
    ApiException.fromEnvelope(status, <String, Object?>{
      'error': <String, Object?>{
        'code': code,
        'message': 'en copy from the server',
        'message_ar': 'نص من السيرفر',
        'request_id': 'req_test',
        if (alternatives.isNotEmpty) 'alternatives': alternatives,
      },
    });

/// What a phone in a lift raises.
const OfflineException offline = OfflineException();
