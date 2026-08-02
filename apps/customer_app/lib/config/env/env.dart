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

  /// Draw the app inside a phone-sized frame, centred on the page.
  ///
  /// ON BY DEFAULT, and only meaningful on web: `flutter run -d chrome` is a
  /// preview harness for a phone-first app, and reviewing a 375-point screen
  /// stretched across a 1440-point window shows you something that will never
  /// ship. Turn it off to look at wide layouts deliberately:
  ///
  ///     --dart-define=DEVICE_FRAME=false
  ///
  /// It is COSMETIC. Correctness at real device sizes is guaranteed by
  /// `test/layout/viewport_matrix_test.dart`, not by this looking right.
  static const bool deviceFrame =
      bool.fromEnvironment('DEVICE_FRAME', defaultValue: true);

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
