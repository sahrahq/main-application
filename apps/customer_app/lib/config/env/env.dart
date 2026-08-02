/// Build-time configuration, from `--dart-define-from-file=env/dev.json`.
///
/// `String.fromEnvironment` is const, so a wrong value is a wrong BUILD rather
/// than a runtime surprise, and nothing here can be edited by a user.
library;

class Env {
  const Env._();

  /// Where the API lives.
  ///
  /// The default is the Android emulator's alias for the host machine, which
  /// is what `env/dev.json` carries. It is deliberately NOT `localhost`:
  /// inside the emulator, localhost is the emulator. On Flutter Web the
  /// browser IS the host, so `env/web.json` overrides this to
  /// `http://localhost:3000`.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

  /// C-3.6, P1. The booking screen shows sold-out slots as "notify me" only
  /// when the waitlist endpoints exist; until then a bell that does nothing is
  /// worse than no bell.
  static const bool enableWaitlist = bool.fromEnvironment('ENABLE_WAITLIST');

  /// C-4.5, P2.
  static const bool enableLoyalty = bool.fromEnvironment('ENABLE_LOYALTY');
}
