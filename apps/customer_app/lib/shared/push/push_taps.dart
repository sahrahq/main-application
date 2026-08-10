import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// WHERE A TAPPED NOTIFICATION SHOULD LAND.
///
/// A notification that opens the app on whatever screen it was last showing
/// has not done its job. The diner was told a specific thing about a specific
/// booking; the tap has to arrive there.
///
/// ── THE COLD-START CASE IS A DIFFERENT API, AND IT IS THE ONE THAT GETS
///    MISSED ─────────────────────────────────────────────────────────────
///
/// `firebase_messaging` reports a tap through **two** channels and they are
/// not interchangeable:
///
///   · `onMessageOpenedApp` — a stream. Fires when the app was ALIVE in the
///     background. Easy to find, easy to test, and on its own it handles the
///     minority case.
///   · `getInitialMessage()` — a one-shot Future. The app was **terminated**;
///     the tap is what launched the process. It is not on the stream, it has
///     already happened by the time any widget builds, and **it returns the
///     message exactly once** — a second call returns null.
///
/// Wiring only the stream produces an app that routes correctly while you are
/// testing it (because your app is always warm) and does nothing at all for a
/// diner whose phone killed it overnight — which is precisely the diner a
/// 24-hour reminder is for.
abstract class PushTaps {
  /// The tap that LAUNCHED the app, or null. Consumed once.
  Future<Map<String, String>?> initialTap();

  /// Taps that arrive while the app is alive in the background.
  Stream<Map<String, String>> taps();
}

/// The FCM-backed implementation.
///
/// A port for the same reason `PushTokenSource` is one: `FirebaseMessaging`
/// is a platform channel and does not exist on a test runner, so a widget
/// touching it directly would make every golden and viewport case throw.
class FirebasePushTaps implements PushTaps {
  @override
  Future<Map<String, String>?> initialTap() async {
    try {
      final RemoteMessage? m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _data(m);
    } catch (e) {
      // Never fatal. A launch that throws here is a launch that fails, and a
      // routing convenience must not be able to stop the app opening.
      debugPrint('initialTap unavailable: $e');
      return null;
    }
  }

  @override
  Stream<Map<String, String>> taps() {
    try {
      return FirebaseMessaging.onMessageOpenedApp.map(_data);
    } catch (e) {
      // Same reason as `initialTap`: on a runner with no Firebase app this
      // throws `core/no-app`, and a routing convenience must not be able to
      // stop the widget tree building. An empty stream is the honest answer —
      // no taps will arrive, because nothing can deliver one.
      debugPrint('tap stream unavailable: $e');
      return const Stream<Map<String, String>>.empty();
    }
  }

  /// FCM `data` is `Map<String, dynamic>` over the wire even though every
  /// value we send is a string. Coerced rather than cast, for the same reason
  /// `stringValues()` exists on the server: one stray number would throw
  /// inside a handler nobody is watching.
  static Map<String, String> _data(RemoteMessage m) => <String, String>{
        for (final MapEntry<String, dynamic> e in m.data.entries)
          if (e.value != null) e.key: '${e.value}',
      };
}

/// Test double. Both channels are values a test can produce.
class FakePushTaps implements PushTaps {
  FakePushTaps({this.initial});

  Map<String, String>? initial;
  final StreamController<Map<String, String>> controller =
      StreamController<Map<String, String>>.broadcast();

  /// Consumed ONCE, like the real one — a fake that kept returning the launch
  /// message would hide a double-navigation bug rather than expose it.
  @override
  Future<Map<String, String>?> initialTap() async {
    final Map<String, String>? m = initial;
    initial = null;
    return m;
  }

  @override
  Stream<Map<String, String>> taps() => controller.stream;

  void emit(Map<String, String> data) => controller.add(data);
}

/// The route a notification payload names, or null if it names none.
///
/// ── THE PAYLOAD CONTRACT IS THE SERVER'S, AND IT IS snake_case ───────────
///
/// `reservation_id` — pinned for every type by `notifications.e2e-spec.ts`.
/// It was `reservationId` briefly, while nothing read it; Group G gave the
/// client a renderer and one spelling had to win.
///
/// Returns a PATH rather than navigating, so the decision is a pure function
/// a test can assert on without a router, a BuildContext or a frame.
String? routeForPush(Map<String, String> data) {
  final String? id = data['reservation_id'];
  if (id != null && id.isNotEmpty) return '/bookings/$id';

  // A type we do not have a destination for is NOT a dead end: the
  // notification centre lists everything, so landing there is always better
  // than landing wherever the app happened to be. `null` means "no specific
  // destination", and the caller sends it to the centre.
  return null;
}
