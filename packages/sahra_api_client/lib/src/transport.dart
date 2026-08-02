/// How the generated client reaches the network.
///
/// A port, not a Dio dependency: this package stays pure Dart, the app supplies
/// a Dio-backed implementation with the auth, locale, retry and idempotency
/// interceptors from doc 07 §3, and tests supply a fake without a socket.
///
/// The return value is the DECODED JSON body. Errors are the transport's
/// business — it throws, and the app's failure mapper turns the doc 06 §1
/// envelope into a `Failure` (ENGINEERING-STANDARDS §7).
abstract class SahraTransport {
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  });
}
