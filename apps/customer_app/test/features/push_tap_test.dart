import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/shared/push/push_taps.dart';

/// A TAPPED NOTIFICATION MUST ARRIVE AT THE THING IT IS ABOUT.
///
/// The destination decision is a pure function precisely so it can be asserted
/// without a router, a BuildContext or a frame — the wiring is one line in
/// `PushTapListener` and the judgement is all here.
void main() {
  group('routeForPush', () {
    test('a reservation notification routes to that reservation', () {
      expect(
        routeForPush(<String, String>{'type': 'reservation_reminder_24h', 'reservation_id': 'r-1'}),
        '/bookings/r-1',
      );
    });

    test('EVERY type the server sends carries reservation_id, so every one routes', () {
      // Enumerated from the server's own catalogue rather than a list beside
      // it — these are the types `notifications.e2e-spec.ts` pins, and it
      // asserts `reservation_id` is present on all of them.
      const List<String> types = <String>[
        'reservation_cancelled_by_venue',
        'reservation_confirmed',
        'reservation_reminder_24h',
        'reservation_reminder_2h',
        'waitlist_offer',
        'waitlist_offer_expired',
      ];
      for (final String t in types) {
        expect(
          routeForPush(<String, String>{'type': t, 'reservation_id': 'abc'}),
          '/bookings/abc',
          reason: '$t did not route to its reservation',
        );
      }
    });

    test('a payload with no reservation names no destination — and that is NOT a dead end', () {
      // `null` means "no specific destination". `PushTapListener` sends those
      // to the notification centre, which lists everything — always a better
      // answer than leaving the diner wherever the app happened to be.
      expect(routeForPush(<String, String>{'type': 'something_new'}), isNull);
      expect(routeForPush(<String, String>{}), isNull);
    });

    test('an EMPTY reservation_id is treated as absent, not as /bookings/', () {
      // A blank id would otherwise build `/bookings/` and land on a route that
      // does not exist.
      expect(routeForPush(<String, String>{'reservation_id': ''}), isNull);
    });
  });

  group('FakePushTaps mirrors the real contract', () {
    test('THE COLD-START MESSAGE IS CONSUMED ONCE', () {
      // The real `getInitialMessage()` returns the launch message exactly
      // once; a second call is null. The fake must do the same, or a rebuild
      // would re-navigate a diner who has since walked somewhere else and the
      // test would never see it.
      final FakePushTaps taps = FakePushTaps(initial: <String, String>{'reservation_id': 'r-9'});
      expect(taps.initialTap(), completion(<String, String>{'reservation_id': 'r-9'}));
      expect(taps.initialTap(), completion(isNull));
    });

    test('a cold launch with no tap yields null rather than throwing', () {
      expect(FakePushTaps().initialTap(), completion(isNull));
    });

    test('background taps arrive on the stream', () {
      final FakePushTaps taps = FakePushTaps();
      expectLater(taps.taps(), emits(<String, String>{'reservation_id': 'r-2'}));
      taps.emit(<String, String>{'reservation_id': 'r-2'});
    });
  });
}
