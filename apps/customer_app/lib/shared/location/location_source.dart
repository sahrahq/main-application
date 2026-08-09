import 'package:geolocator/geolocator.dart';

/// WHERE THE DINER IS, ASKED FOR ONCE AND ONLY WHEN IT MATTERS.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SCOPE THIS RUNS UNDER
/// ─────────────────────────────────────────────────────────────────────────
///
/// `geolocator` was approved on 2026-08-09 as the first platform plugin after
/// `url_launcher`, and the scope was agreed with it. Written here rather than
/// only in doc 08, because this file is what the next screen will copy:
///
///   · **A ONE-SHOT POSITION.** `getCurrentPosition`, never `getPositionStream`.
///     Nothing in this product needs to follow a diner around; it needs to know
///     roughly where they are at the moment they ask "what is near me".
///   · **REQUESTED ON USE, NEVER ON LAUNCH.** The permission dialog appears
///     when the diner opens the distance control and at no other time. A
///     booking app that asks for location on first run, before it has shown
///     anybody anything, is one a lot of people deny permanently — and a
///     permanent denial is the one state we cannot undo from inside the app.
///   · **NO BACKGROUND LOCATION.** No `always` permission, no manifest entry
///     for it, ever. That is a different product with a different privacy
///     conversation.
///   · **NOT STORED.** The position lives in memory for the session. It is not
///     written to `flutter_secure_storage`, not sent anywhere except as
///     `lat`/`lng` on a search query, and not persisted across launches.
///
/// ── AND WHY THIS IS A PORT ───────────────────────────────────────────────
///
/// `Geolocator` is static methods over a platform channel. A widget calling it
/// directly cannot be told "permission denied", "location services are off" or
/// "this took twelve seconds" — and those three are most of the behaviour. On
/// a test runner the channel simply is not there, so every golden and every
/// viewport case would either throw or hang.
///
/// So the app depends on this interface and the plugin sits behind exactly one
/// implementation of it. Same shape as `SahraTransport`, `OtpDelivery` and
/// `ImageStorage`.
enum LocationOutcome {
  /// A position was obtained.
  ok,

  /// The diner said no this time. Asking again later is legitimate.
  denied,

  /// The diner said no permanently, or a policy said it for them. **Asking
  /// again does nothing** — the OS will not show the dialog. The only way
  /// forward is the device's own settings, so a screen must say that rather
  /// than offering a button that silently fails.
  deniedForever,

  /// Location services are switched off device-wide. Not about us, and not
  /// something a permission prompt fixes.
  serviceDisabled,

  /// The platform answered with an error, or took too long.
  unavailable,
}

/// A position, or why there is not one.
///
/// A record rather than an exception. "The diner declined" is an ordinary
/// answer to this question, not an exceptional one, and a `try/catch` around
/// something that usually returns null is how a denial ends up logged as a
/// crash.
class LocationResult {
  const LocationResult.ok(this.lat, this.lng) : outcome = LocationOutcome.ok;
  const LocationResult.failed(this.outcome)
      : lat = null,
        lng = null;

  final LocationOutcome outcome;
  final double? lat;
  final double? lng;

  bool get hasPosition => lat != null && lng != null;
}

abstract class LocationSource {
  /// Ask the platform where we are, prompting for permission if needed.
  ///
  /// Never throws. Every failure is a [LocationOutcome], because the caller has
  /// to render something different for each of them and an exception type would
  /// make that a `switch` on a `catch`.
  Future<LocationResult> current();

  /// Whether asking again could possibly do anything.
  ///
  /// Read before showing a "turn it on" control, so the app does not offer a
  /// button that the OS has already decided will not work.
  Future<bool> canAsk();
}

/// The real one. The only place in the app that touches `geolocator`.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  /// LOW accuracy, deliberately.
  ///
  /// "Which restaurants are near me" needs a neighbourhood, not a doorway.
  /// `LocationAccuracy.low` is roughly city-block precision, resolves in about
  /// a second against a few seconds for `high`, and does not wake the GPS
  /// radio — which on a Cairo phone at 8pm is the difference between a filter
  /// that feels instant and one the diner abandons.
  static const LocationAccuracy _accuracy = LocationAccuracy.low;

  /// Past this we stop waiting and say so.
  ///
  /// A location request with no timeout can hang indefinitely indoors. A
  /// spinner that never resolves is worse than "we could not find you" —
  /// the second one at least lets the diner search a neighbourhood instead.
  static const Duration _timeout = Duration(seconds: 8);

  @override
  Future<bool> canAsk() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final LocationPermission p = await Geolocator.checkPermission();
    return p != LocationPermission.deniedForever;
  }

  @override
  Future<LocationResult> current() async {
    try {
      // SERVICES FIRST. Requesting permission while location is switched off
      // device-wide produces a granted permission and then no position, which
      // reads to the diner as the app being broken after they said yes.
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationOutcome.serviceDisabled);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // THE ONLY PLACE IN THE APP THAT RAISES THE DIALOG.
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationResult.failed(LocationOutcome.denied);
        case LocationPermission.deniedForever:
          return const LocationResult.failed(LocationOutcome.deniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: _accuracy,
          timeLimit: _timeout,
        ),
      );
      return LocationResult.ok(position.latitude, position.longitude);
    } on Object {
      // Deliberately broad. `geolocator` throws a family of platform-specific
      // types — timeout, service, permission-definitions-not-found — and the
      // caller's behaviour is identical for all of them: say we could not find
      // you, and leave the rest of search working.
      return const LocationResult.failed(LocationOutcome.unavailable);
    }
  }
}

/// For tests, goldens and the viewport matrix.
///
/// Every screen case in the registry gets one of these. Without it, a golden of
/// the filter sheet would either throw on a missing platform channel or, worse,
/// hang for eight seconds per cell.
class FixedLocationSource implements LocationSource {
  const FixedLocationSource({this.lat, this.lng, this.outcome = LocationOutcome.ok});

  /// Zamalek, which is where the seeded venues are.
  const FixedLocationSource.zamalek()
      : lat = 30.0622,
        lng = 31.2185,
        outcome = LocationOutcome.ok;

  const FixedLocationSource.refused(this.outcome)
      : lat = null,
        lng = null;

  final double? lat;
  final double? lng;
  final LocationOutcome outcome;

  @override
  Future<bool> canAsk() async => outcome != LocationOutcome.deniedForever;

  @override
  Future<LocationResult> current() async => outcome == LocationOutcome.ok && lat != null
      ? LocationResult.ok(lat!, lng!)
      : LocationResult.failed(outcome);
}
