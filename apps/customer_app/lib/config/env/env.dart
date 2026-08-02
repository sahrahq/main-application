import 'dart:ui';

/// Build-time configuration, from `--dart-define-from-file=env/dev.json`.
///
/// `String.fromEnvironment` is const, so a wrong value is a wrong BUILD rather
/// than a runtime surprise, and nothing here can be edited by a user.
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

  /// Pin the app to one locale, ignoring the device.
  ///
  /// A DEVELOPMENT AND REVIEW affordance, not a product setting: Arabic is
  /// half of this product and checking it should not require changing your
  /// operating system's language. Empty means "follow the device", which is
  /// what a real build does.
  ///
  ///     flutter run -d chrome --dart-define=FORCE_LOCALE=ar
  static const String forceLocale = String.fromEnvironment('FORCE_LOCALE');
}

/// The locale to run in, or null to follow the device.
Locale? forcedLocale() =>
    Env.forceLocale.isEmpty ? null : Locale(Env.forceLocale);
