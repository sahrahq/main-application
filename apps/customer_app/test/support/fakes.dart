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

    // A KEY THAT IS SENT MUST BE WELL FORMED. Nothing more is asserted here,
    // and the reason is worth writing down because this check USED to say
    // "every non-GET must carry one" and was wrong twice over.
    //
    // Wrong the first way: it could not fail for a real reason. The generator
    // emits `idempotencyKey` as a REQUIRED named parameter on exactly the
    // operations whose spec declares the header, so omitting it at a call site
    // is a compile error, not a test failure.
    //
    // Wrong the second way, and this is the one that matters: it agreed with
    // CLAUDE.md rule 2 — "every API mutation is idempotent" — while 22 of the
    // 25 mutations broke it. It passed for four weeks because the only
    // mutations any test drove were the two reservation ones, which comply.
    // A guard pointed only at the compliant cases is not a guard, so counting
    // moved to `apps/api/src/shared/api/idempotency-contract.spec.ts`, where
    // it observes the whole committed spec instead of whatever this suite
    // happened to call.
    final key = headers?['idempotency-key'];
    if (key != null && !_uuidV4.hasMatch(key)) {
      throw StateError('$method $path sent a malformed Idempotency-Key: $key');
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
