import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/main.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';

import '../support/fakes.dart';

/// THE WHOLE JOURNEY, COLD LAUNCH TO A BOOKING FOUND AGAIN.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS, AND WHY IT IS NOT A SCREEN TEST
/// ─────────────────────────────────────────────────────────────────────────
///
/// Sign-in, my bookings and reservation detail were built, golden-tested in
/// four cells each, accessibility-checked, viewport-checked, and shipped with
/// 461 passing tests — and **nothing in the app routed to any of them**. There
/// was no way to reach your account from anywhere. Every screen passed its own
/// test; the product did not exist.
///
/// No per-screen test can ask that question, because every per-screen test
/// starts by constructing the screen. This one starts by launching the app and
/// is only allowed to touch things a finger could reach.
///
/// **A screen that passes its own test and cannot be reached is
/// indistinguishable from a screen that does not exist.** That is the UI form
/// of "a capability that is never called is indistinguishable from one that
/// does not exist" (ENGINEERING-STANDARDS).
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE ONE RULE FOR EDITING THIS FILE
/// ─────────────────────────────────────────────────────────────────────────
///
/// Navigate ONLY by tapping what is on screen. No `context.go`, no route
/// constants, no provider pokes to skip a step, no constructing a screen
/// directly. The moment this file is allowed a shortcut it stops being able to
/// detect a missing one.
void main() {
  const String venueId = '4f743baa-3054-4fda-90ce-1a602faf1e77';

  /// The server, as a table of canned responses. Only the socket is fake —
  /// the real client, repositories, notifiers, router and widgets all run.
  FakeTransport backend({required bool Function() signedIn}) {
    return FakeTransport((method, path, query) {
      if (path.contains('/restaurants/search')) return _searchPage;
      if (path.endsWith('/availability')) return _availability;
      if (path == '/v1/restaurants/$venueId' || path.endsWith('/layali-lounge-zamalek')) {
        return _profile;
      }
      if (path == '/v1/auth/request-otp') {
        // A HANDLE AND NOTHING ELSE — identical for a number
        // nobody has ever seen. That is AUTH-3 closed.
        return <String, Object?>{'challengeId': 'journey-challenge'};
      }
      if (path == '/v1/auth/verify-otp') {
        // `profile_needed`, because this is a diner who has never
        // booked before — the cold-start path, and the only one that
        // reaches the name step. A `signed_in` stub here would walk a
        // returning diner and never touch the third step at all.
        return <String, Object?>{'status': 'profile_needed'};
      }
      if (path == '/v1/auth/complete-registration') return _tokenPair;
      if (path == '/v1/reservations/holds') {
        // C-1.6 — the server refuses an anonymous hold. The app must turn
        // this into a sign-in detour, not an error.
        if (!signedIn()) throw envelope(401, 'unauthenticated');
        return _reservation('held');
      }
      if (path.endsWith('/confirm')) return _reservation('confirmed');
      if (path == '/v1/reservations') return <Object>[_myReservation];
      if (path == '/v1/reservations/$_reservationId') return _myReservation;
      throw StateError('the journey touched an endpoint nobody stubbed: $method $path');
    });
  }

  testWidgets('cold launch → browse → book → sign in → confirmed → found again',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // COLD, with nothing in storage. No session, no pending selection.
    final store = InMemorySessionStore();
    var signedIn = false;

    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(backend(signedIn: () => signedIn)),
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentSessionProvider, (_, next) => signedIn = next != null);

    // `SahraApp` ITSELF, not a MaterialApp assembled here.
    //
    // The first cut of this test built its own `MaterialApp.router` around
    // `buildRouter()` — and got a different app. `main.dart`'s `builder` also
    // installs `LocaleSync`, which is what tells the repositories which
    // language to resolve venue names in; without it the English run rendered
    // «ليالي لاونج». A journey test that reassembles the app is testing an
    // assembly nobody ships.
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SahraApp()),
    );
    await tester.pumpAndSettle();

    // ── 1. It opens, on Discover, without asking anyone to sign in. ────────
    expect(find.text('Discover'), findsOneWidget, reason: 'no navigation on launch',);
    expect(find.text('Sign in to book'), findsNothing, reason: 'browsing was gated',);

    // ── 2. Search. ────────────────────────────────────────────────────────
    await tester.enterText(find.byType(TextField).first, 'layali');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Layali Lounge'), findsWidgets, reason: 'search returned nothing',);

    // ── 3. Into the venue. ────────────────────────────────────────────────
    await tester.tap(find.text('Layali Lounge').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Book'), findsWidgets, reason: 'no way in to booking',);

    // ── 4. To the booking screen. ─────────────────────────────────────────
    await tester.tap(find.textContaining('Book a table').last);
    await tester.pumpAndSettle();

    // ── 5. Pick a time and try to book, as a guest. ────────────────────────
    await tester.tap(find.text('18:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Confirm for'));
    await tester.pumpAndSettle();

    // ── 6. C-1.6 sends us to sign-in, carrying the table. ─────────────────
    expect(find.text('Sign in to book'), findsOneWidget,
        reason: 'a guest booking did not reach sign-in',);
    expect(find.textContaining('Your table:'), findsOneWidget,
        reason: 'the diner was asked to sign in with no idea what for',);

    // ── 7. Sign in for real, through the screen. ──────────────────────────
    // ONE FIELD NOW. The name moved to a third step that only appears when the
    // number turns out to belong to nobody; these stubs answer `signed_in`, so
    // it never appears here.
    await tester.enterText(find.byType(TextField).first, '01000000000');
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // ── 7b. A NAME, because this number belongs to nobody yet. ────────────
    //
    // The third step of the same screen, not a route of its own. It appears
    // only for a number with no account, which is why the stub answers
    // `profile_needed`: a returning diner never sees it.
    expect(find.text('What should we call you?'), findsOneWidget,
        reason: 'a brand-new number did not reach the name step',);
    await tester.enterText(find.byType(TextField).first, 'Nour');
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // ── 8. The hold re-fires by itself and the booking confirms. ──────────
    expect(find.textContaining('SAH-'), findsWidgets,
        reason: 'the booking did not complete after sign-in',);

    // ── 9. Leave the confirmation the way the screen offers. ──────────────
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // ── 10. FIND IT AGAIN FROM THE HOME SCREEN. ───────────────────────────
    // This is the step that did not exist. Everything above passed for weeks
    // while this was impossible.
    expect(find.text('Bookings'), findsOneWidget, reason: 'no route to bookings',);
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Layali Lounge'), findsWidgets,
        reason: 'the reservation just made is not in the bookings list',);

    // ── 11. And open it. ──────────────────────────────────────────────────
    await tester.tap(find.text('Layali Lounge').first);
    await tester.pumpAndSettle();
    expect(find.text('SAH-7K2M'), findsOneWidget,
        reason: 'the reservation detail is unreachable from the list',);
  }, timeout: const Timeout(Duration(minutes: 2)),);
}

const String _userId = '99999999-9999-4999-8999-999999999999';
const String _reservationId = '22222222-2222-4222-8222-222222222222';

final Map<String, Object?> _searchPage = <String, Object?>{
  'results': <Object>[
    <String, Object?>{
      'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
      'slug': 'layali-lounge-zamalek',
      'name_en': 'Layali Lounge',
      'name_ar': 'ليالي لاونج',
      'cuisines': <String>['levantine'],
      'neighborhood': 'Zamalek',
      'price_band': 3,
      'rating': 4.8,
      'rating_count': 312,
      'next_available': <String>['18:00'],
    },
  ],
  'next_cursor': null,
  'estimated_total': 1,
  'availability_filtered': true,
};

final Map<String, Object?> _profile = <String, Object?>{
  'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
  'slug': 'layali-lounge-zamalek',
  'name_en': 'Layali Lounge',
  'name_ar': 'ليالي لاونج',
  'cuisines': <String>['levantine'],
  'neighborhood': 'Zamalek',
  'city': 'Cairo',
  'rating': 4.8,
  'rating_count': 312,
  'phone': '+20 2 2735 0000',
  'amenities': <String>['outdoor'],
  'timezone': 'Africa/Cairo',
  'booking_mode': 'instant',
  'hours': <Object>[
    for (var day = 0; day < 7; day++)
      <String, Object?>{
        'day_of_week': day,
        'specific_date': null,
        'name_en': 'Dinner',
        'name_ar': 'العشاء',
        'opens_at': '18:00',
        'closes_at': '23:30',
        'spans_midnight': false,
      },
  ],
};

final Map<String, Object?> _availability = <String, Object?>{
  'date': '2026-08-05',
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[
    for (final t in <String>['18:00', '18:30', '19:00'])
      <String, Object?>{
        'time': t,
        'startsAt': '2026-08-05T$t:00.000Z',
        'zones': <String>['indoor'],
      },
  ],
};

final Map<String, Object?> _tokenPair = <String, Object?>{
  'accessToken': 'journey-access',
  'refreshToken': 'journey-refresh',
  'expiresIn': 900,
  'user': <String, Object?>{
    'id': _userId,
    'phone': '+201000000000',
    'fullName': 'Nour',
    'roles': <String>['customer'],
    'status': 'active',
    'locale': 'en',
  },
};

Map<String, Object?> _reservation(String status) => <String, Object?>{
      'id': _reservationId,
      'code': 'SAH-7K2M',
      'restaurantId': '4f743baa-3054-4fda-90ce-1a602faf1e77',
      'partySize': 2,
      'startsAt': '2026-08-05T18:00:00.000Z',
      'endsAt': '2026-08-05T19:30:00.000Z',
      'status': status,
      'source': 'app',
    };

final Map<String, Object?> _myReservation = <String, Object?>{
  'id': _reservationId,
  'code': 'SAH-7K2M',
  'status': 'confirmed',
  'source': 'app',
  'starts_at': '2026-08-05T18:00:00.000Z',
  'ends_at': '2026-08-05T19:30:00.000Z',
  'date': '2026-08-05',
  'time': '21:00',
  'party_size': 2,
  'needs_acknowledgement': false,
  'cancelled_by': null,
  'cancelled_at': null,
  'cancel_reason': null,
  'occasion': null,
  'special_requests': null,
  'restaurant': <String, Object?>{
    'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
    'slug': 'layali-lounge-zamalek',
    'name_en': 'Layali Lounge',
    'name_ar': 'ليالي لاونج',
    'neighborhood': 'Zamalek',
    'city': 'Cairo',
    'timezone': 'Africa/Cairo',
  },
};
