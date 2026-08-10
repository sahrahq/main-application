import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/features/reservations/presentation/booking_notifier.dart';
import 'package:sahra_customer_app/features/reservations/presentation/pending_booking.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/routes/routes.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/fakes.dart';
import '../support/fixture_dates.dart';

/// C-1.6: booking requires an account, and the diner comes back to the SAME
/// table afterwards.
///
/// The five cases below are the five the product owner named, and they are
/// written as five because each one fails differently:
///
///   1. tap → 401 → sign-in, selection parked
///   2. return → same slot, same date, same party, still selected
///   3. re-attempt fails `slot_taken` → refreshed grid, not a dead end
///   4. backed out → selection intact, NOTHING attempted
///   5. app restart → selection gone, and no silent re-attempt
///
/// These drive the real widget through a real GoRouter, because four of the
/// five are properties of NAVIGATION. A notifier test could assert the states
/// and pass while the screen never pushed anything.
void main() {
  const venueId = '11111111-1111-4111-8111-111111111111';
  const startsAt = '${kFutureDate}T18:00:00.000Z';

  Map<String, Object?> slots(List<String> times) => <String, Object?>{
        'date': kFutureDate,
        'partySize': 2,
        'timezone': 'Africa/Cairo',
        'slots': <Object>[
          for (final t in times)
            <String, Object?>{
              'time': t,
              'startsAt': '${kFutureDate}T${t.split(':').first}:${t.split(':').last}:00.000Z',
              'zones': <String>['indoor'],
            },
        ],
      };

  final Map<String, Object?> heldReservation = <String, Object?>{
    'id': '22222222-2222-4222-8222-222222222222',
    'code': 'SAH-7K2M',
    'restaurantId': venueId,
    'partySize': 2,
    'startsAt': startsAt,
    'endsAt': '${kFutureDate}T19:30:00.000Z',
    'status': 'held',
    'source': 'app',
  };

  /// The whole app under a router, so `push` and `pop` are real.
  Future<ProviderContainer> pumpBooking(
    WidgetTester tester, {
    required FakeTransport transport,
    List<Override> extra = const <Override>[],
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(transport),
        // Never a keystore in a test.
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
        ...extra,
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/r/$venueId/book?name=Layali%20Lounge',
      routes: buildRouter().configuration.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: SahraTheme.light(locale: const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...SahraTheme.localizationsDelegates,
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  /// Tap the first slot chip, then the confirm button.
  Future<void> chooseAndBook(WidgetTester tester) async {
    await tester.tap(find.textContaining('6:00'));
    await tester.pump();
    // `Confirm for 2 at 18:00`, not "Book" — the AppBar title is "Book a
    // table" and a `textContaining('Book')` finder taps that instead, silently
    // doing nothing.
    await tester.tap(find.textContaining('Confirm for'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('1 — a guest tapping a slot is sent to sign-in, selection parked', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path.contains('/availability')) return slots(<String>['18:00', '19:00']);
      if (path == '/v1/reservations/holds') throw envelope(401, 'unauthenticated');
      throw StateError('unexpected $method $path');
    });

    final container = await pumpBooking(tester, transport: transport);
    await chooseAndBook(tester);

    // The diner is on the sign-in screen…
    expect(find.text('Sign in to book'), findsOneWidget);

    // …with the selection parked, and it names the table.
    final parked = container.read(pendingBookingProvider(venueId));
    expect(parked, isNotNull);
    expect(parked!.startsAt, startsAt);
    expect(parked.slotLabel, '18:00');
    expect(parked.partySize, 2);
    expect(find.textContaining('Layali Lounge'), findsWidgets);

    // NOT an error screen. The 401 never reaches the diner as a failure.
    expect(find.textContaining('went wrong'), findsNothing);
  });

  testWidgets('2 and 3 — returning re-attempts, and a lost table lands on a refreshed grid',
      (tester) async {
    var holds = 0;
    final transport = FakeTransport((method, path, _) {
      if (path.contains('/availability')) {
        // The board MOVES between the two loads: 18:00 is gone by the time the
        // diner comes back. If the screen re-rendered the first board the
        // diner would be looking at a time nobody can book.
        return holds == 0 ? slots(<String>['18:00', '19:00']) : slots(<String>['19:00', '19:30']);
      }
      if (path == '/v1/reservations/holds') {
        holds++;
        // First attempt: not signed in. Second: signed in, but too late.
        throw holds == 1 ? envelope(401, 'unauthenticated') : envelope(409, 'slot_taken');
      }
      if (path == '/v1/auth/request-otp') {
        return <String, Object?>{'challengeId': 'stub-challenge'};
      }
      if (path == '/v1/auth/verify-otp') {
        return <String, Object?>{
          'status': 'signed_in',
          'tokens': <String, Object?>{
            'accessToken': 'a',
            'refreshToken': 'r',
            'expiresIn': 900,
            'user': <String, Object?>{
              'id': 'u1',
              'phone': '+201000000000',
              'fullName': 'Nour',
              'roles': <String>['customer'],
              'status': 'active',
              'locale': 'en',
            },
          },
        };
      }
      throw StateError('unexpected $method $path');
    });

    final container = await pumpBooking(tester, transport: transport);

    // Captured BEFORE the detour, not hardcoded. The assertion is "the same as
    // it was", which is the actual requirement — a literal date here would
    // pass on the day it was written and rot the next morning.
    final before = container.read(bookingSelectionProvider(venueId));

    await chooseAndBook(tester);
    expect(find.text('Sign in to book'), findsOneWidget);

    // Sign in for real, through the screen.
    // ONE FIELD NOW. The name moved to a third step that only appears when the
    // number turns out to belong to nobody; these stubs answer `signed_in`, so
    // it never appears here.
    await tester.enterText(find.byType(TextField).first, '01000000000');
    await tester.tap(find.text('Send me a code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Back on the booking screen.
    expect(find.text('Sign in to book'), findsNothing);

    // 2 — the same slot, date and party are still selected.
    expect(container.read(chosenSlotProvider(venueId)), startsAt);
    expect(container.read(bookingSelectionProvider(venueId)).date, before.date);
    expect(container.read(bookingSelectionProvider(venueId)).partySize, before.partySize);

    // The hold WAS re-attempted, without the diner tapping anything.
    expect(holds, 2);

    // 3 — and because it lost, the diner sees the conflict over a REFRESHED
    // board: 18:00 is gone, 19:30 has appeared.
    expect(container.read(bookingFlowProvider(venueId)), isA<BookingSlotTaken>());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('7:30'), findsOneWidget);
    expect(find.textContaining('6:00'), findsNothing);
  });

  testWidgets('4 — backing out of sign-in keeps the selection and attempts nothing',
      (tester) async {
    var holds = 0;
    final transport = FakeTransport((method, path, _) {
      if (path.contains('/availability')) return slots(<String>['18:00', '19:00']);
      if (path == '/v1/reservations/holds') {
        holds++;
        throw envelope(401, 'unauthenticated');
      }
      throw StateError('unexpected $method $path');
    });

    final container = await pumpBooking(tester, transport: transport);
    await chooseAndBook(tester);
    expect(find.text('Sign in to book'), findsOneWidget);
    expect(holds, 1);

    // Back out with the close control.
    expect(find.bySemanticsLabel('Not now'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to book'), findsNothing);

    // The selection survived — they can try again — and NOTHING was attempted.
    expect(container.read(pendingBookingProvider(venueId)), isNotNull);
    expect(container.read(chosenSlotProvider(venueId)), startsAt);
    expect(holds, 1, reason: 'backing out must not re-attempt the hold');

    // And the flow is idle, so the sign-in screen does not immediately reopen.
    expect(container.read(bookingFlowProvider(venueId)), isA<BookingIdle>());
  });

  testWidgets('5 — a restart loses the selection, and nothing is re-attempted', (tester) async {
    var holds = 0;
    final restoredSession = InMemorySessionStore();
    await restoredSession.write(
      const Session(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        fullName: 'Nour',
        phone: '+201000000000',
      ),
    );

    final transport = FakeTransport((method, path, _) {
      if (path.contains('/availability')) return slots(<String>['18:00', '19:00']);
      if (path == '/v1/reservations/holds') {
        holds++;
        return heldReservation;
      }
      throw StateError('unexpected $method $path');
    });

    // A RESTART IS A NEW CONTAINER. `PendingBooking` is process-scoped by
    // construction, so this test's whole job is to prove that the screen does
    // not compensate for it somewhere — that nothing reads a persisted
    // selection and nothing fires on build.
    final container = await pumpBooking(
      tester,
      transport: transport,
      // Even with a session restored from storage — the case where a diner
      // signed in, closed the app mid-booking and came back — there must be no
      // hold.
      extra: <Override>[
        sessionStoreProvider.overrideWithValue(restoredSession),
      ],
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(pendingBookingProvider(venueId)), isNull);
    expect(holds, 0, reason: 'a restart must never silently re-attempt a hold');
    expect(container.read(bookingFlowProvider(venueId)), isA<BookingIdle>());
  });
}
