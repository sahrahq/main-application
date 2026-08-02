import 'failure_mapper.dart';

/// Every repository call funnels its errors through the one mapper here, so
/// nothing above the data layer ever sees a `DioException`, an
/// `ApiException`, or a `FormatException` (ENGINEERING-STANDARDS §7).
///
/// A free function rather than a base class: repositories implement pure-Dart
/// domain interfaces, and a shared superclass would put a data-layer type in
/// the domain's inheritance chain.
Future<T> guarded<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    // `mapFailure` passes a Failure through unchanged, so nesting is safe.
    throw mapFailure(e);
  }
}
