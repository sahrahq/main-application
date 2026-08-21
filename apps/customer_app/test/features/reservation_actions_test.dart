import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/routes/routes.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/fakes.dart';

/// C-3.4 and C-3.5 from the diner's side — the two buttons that shipped
/// disabled for a batch and are now real.
///
/// DRIVEN THROUGH THE SCREEN, not the notifier. Every one of these is a
/// property of what a thumb can reach: that cancelling asks first, that the
/// sheet stays open when the server refuses, that a booking whose time has
/// passed offers no move button. A notifier test would assert the states and
/// pass while no button was wired to any of them.
///
/// THE REQUEST BODIES ARE ASSERTED, not just the responses. A modify that
/// posted the wrong field would still redraw correctly from the reply it was
/// handed, so the fake records what actually went out.
void main() {
  const id = '22222222-2222-4222-8222-222222222222';
  const venueId = '11111111-1111-4111-8111-111111111111';

  /// Far enough ahead that `canMove` is true whenever this runs.
  final DateTime soon = DateTime.now().toUtc().add(const Duration(days: 2));
  final String startsAt = soon.toIso8601String();
  final String date = startsAt.substring(0, 10);

  Map<String, Object?> reservation({
    String status = 'confirmed',
    int partySize = 2,
    String? cancelledBy,
    String? at,
    bool canReview = false,
  }) =>
      <String, Object?>{
        'id': id,
        'code': 'SAH-7K2M',
        'status': status,
        'source': 'app',
        'starts_at': at ?? startsAt,
        'ends_at': (at == null ? soon : DateTime.parse(at))
            .add(const Duration(minutes: 90))
            .toIso8601String(),
        'date': (at ?? startsAt).substring(0, 10),
        'time': '19:00',
        'party_size': partySize,
        'special_requests': null,
        'occasion': null,
        'cancelled_by': cancelledBy,
        'cancelled_at': cancelledBy == null ? null : startsAt,
        'cancel_reason': null,
        'needs_acknowledgement': false,
        // Group D. The SERVER decides this; a fixture that
        // omitted it would be testing a response shape the API
        // never sends.
        'can_review': canReview,
        'review_id': null,
        'restaurant': <String, Object?>{
          'id': venueId,
          'slug': 'layali-lounge',
          'name_en': 'Layali Lounge',
          'name_ar': 'ليالي لاونج',
          'city': 'Cairo',
          'neighborhood': 'Zamalek',
          'timezone': 'Africa/Cairo',
        },
      };

  Map<String, Object?> slots(List<String> times) => <String, Object?>{
        'date': date,
        'partySize': 2,
        'timezone': 'Africa/Cairo',
        'slots': <Object>[
          for (final t in times)
            <String, Object?>{
              'time': t,
              'startsAt': '${date}T${t.split(':').first}:00:00.000Z',
              'zones': <String>['indoor'],
            },
        ],
      };

  Future<ProviderContainer> pumpDetail(
    WidgetTester tester, {
    required FakeTransport transport,
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(transport),
        sessionStoreProvider.overrideWithValue(
          InMemorySessionStore(
            const Session(
              accessToken: 'a',
              refreshToken: 'r',
              userId: 'u1',
              fullName: 'Nour Hassan',
              phone: '+201000000000',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/bookings/$id',
      routes: buildRouter().configuration.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: SahraTheme.light(locale: locale),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...SahraTheme.localizationsDelegates,
          ],
        ),
      ),
    );
    // TWICE, and not for luck. The session restore is async, and
    // `reservationDetailProvider` watches it — so the first settle finishes the
    // restore, which invalidates the provider, and the second finishes the
    // fetch it triggers.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('the two buttons are LIVE — not disabled, and no apology line', (tester) async {
    // The regression that matters most in this file: they shipped disabled
    // under "Not available yet — call the restaurant", and a line explaining
    // why a button does nothing outlives the reason unless something checks.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);

    final modify = tester.widget<SahraButton>(
      find.widgetWithText(SahraButton, 'Change time or party'),
    );
    final cancel = tester.widget<SahraButton>(
      find.widgetWithText(SahraButton, 'Cancel booking'),
    );
    expect(modify.onPressed, isNotNull, reason: 'modify is still disabled');
    expect(cancel.onPressed, isNotNull, reason: 'cancel is still disabled');
    expect(find.textContaining('Not available yet'), findsNothing);
  });

  testWidgets('CANCEL ASKS FIRST — one tap does not destroy the booking', (tester) async {
    var cancelCalls = 0;
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/cancel') {
        cancelCalls++;
        return reservation(status: 'cancelled_by_user', cancelledBy: 'user');
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Cancel booking'));
    await tester.pumpAndSettle();

    // The sheet is open and NOTHING has been sent.
    expect(find.text('Cancel this booking?'), findsOneWidget);
    expect(cancelCalls, 0, reason: 'the first tap cancelled without asking');

    // The way out leaves the booking alone.
    await tester.tap(find.widgetWithText(SahraButton, 'Keep my booking'));
    await tester.pumpAndSettle();
    expect(cancelCalls, 0);
    expect(find.text('Cancel this booking?'), findsNothing);
  });

  testWidgets('confirming sends the reason the diner typed', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/cancel') {
        return reservation(status: 'cancelled_by_user', cancelledBy: 'user');
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Cancel booking'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Plans changed');
    // The sheet's own confirm, not the detail screen's button of the same name.
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(SahraButton, 'Cancel booking'),
      ),
    );
    await tester.pumpAndSettle();

    final body = transport.bodyFor('/v1/reservations/$id/cancel')! as Map<String, Object?>;
    expect(body['reason'], 'Plans changed');
    // The sheet closed, because it worked.
    expect(find.text('Cancel this booking?'), findsNothing);
  });

  testWidgets('AN EMPTY REASON IS SENT AS NULL, not as an empty string', (tester) async {
    // an empty string would be stored and shown to the venue as a reason that is not one.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/cancel') {
        return reservation(status: 'cancelled_by_user', cancelledBy: 'user');
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(SahraButton, 'Cancel booking'),
      ),
    );
    await tester.pumpAndSettle();

    final body = transport.bodyFor('/v1/reservations/$id/cancel')! as Map<String, Object?>;
    expect(body['reason'], isNull);
  });

  testWidgets('A REFUSED CANCEL KEEPS THE SHEET OPEN AND SAYS WHY', (tester) async {
    // A sheet that pops on failure takes the message with it, and the diner is
    // returned to a booking that still looks live with no account of what
    // happened.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/cancel') {
        throw envelope(409, 'invalid_status_transition');
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(SahraButton, 'Cancel booking'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Cancel this booking?'),
      findsOneWidget,
      reason: 'the sheet closed on a failure and hid the reason',
    );
    expect(
      find.textContaining('already moved on'),
      findsOneWidget,
      reason: 'the refusal was swallowed',
    );
  });

  testWidgets('THE MOVE SHEET READS ITS OWN GRID, not the public one', (tester) async {
    // The whole reason `/reservations/:id/available-slots` exists. Hitting
    // `/restaurants/:id/availability` would hide the slots this booking is
    // itself blocking — which is most of the times a diner wants.
    final paths = <String>[];
    final transport = FakeTransport((method, path, _) {
      paths.add(path);
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00', '20:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Change time or party'));
    await tester.pumpAndSettle();

    expect(find.text('Change your booking'), findsOneWidget);
    expect(paths, contains('/v1/reservations/$id/available-slots'));
    expect(
      paths.any((p) => p.contains('/availability')),
      isFalse,
      reason: 'the move sheet fell back to the public grid',
    );
  });

  testWidgets("THE DATE STRIP CONTAINS THE BOOKING'S OWN DATE", (tester) async {
    // Caught in the walk-through, not by a test: the strip was copied from the
    // booking screen, which offers the next seven days from TODAY. A booking
    // further out than that opened a sheet whose date row could not contain
    // the reservation's own date, and nothing was selected in it.
    //
    // `soon` is two days out, so the window is centred three days earlier —
    // clamped to today — and the booking's day is in the middle of the row.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00', '20:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Change time or party'));
    await tester.pumpAndSettle();

    final strip = tester.widget<SahraDateStrip>(find.byType(SahraDateStrip));
    expect(
      strip.days.map((d) => d.id),
      contains(date),
      reason: "the move sheet cannot offer the booking's own date",
    );
    expect(strip.selectedId, date);

    // AND NEVER A DAY IN THE PAST. An offered day the server would refuse is
    // a picker that lies.
    final todayId = DateTime.now().toIso8601String().substring(0, 10);
    expect(
      strip.days.every((d) => d.id.compareTo(todayId) >= 0),
      isTrue,
      reason: 'the strip offers a day that has already gone',
    );
  });

  testWidgets('SAVE IS DEAD UNTIL SOMETHING ACTUALLY CHANGES', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00', '20:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Change time or party'));
    await tester.pumpAndSettle();

    final before = tester.widget<SahraButton>(
      find.widgetWithText(SahraButton, 'Save changes'),
    );
    expect(before.onPressed, isNull, reason: 'save was live with nothing to save');

    await tester.tap(find.textContaining('8:00'));
    await tester.pumpAndSettle();

    final after = tester.widget<SahraButton>(
      find.widgetWithText(SahraButton, 'Save changes'),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('moving the time sends startsAt and NOT partySize', (tester) async {
    // A PATCH touches what it names. Re-asserting an unchanged party size
    // would re-run allocation for nothing.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id' && method == 'GET') return reservation();
      if (path == '/v1/reservations/$id' && method == 'PATCH') return reservation();
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00', '20:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Change time or party'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SahraButton, 'Save changes'));
    await tester.pumpAndSettle();

    final body = transport.sent.lastWhere((c) => c.method == 'PATCH').body! as Map<String, Object?>;
    expect(body['startsAt'], '${date}T20:00:00.000Z');
    expect(
      body.containsKey('partySize'),
      isFalse,
      reason: 'an unchanged party size was re-asserted',
    );
  });

  testWidgets('a slot_taken refusal keeps the sheet open with the alternatives', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id' && method == 'GET') return reservation();
      if (path == '/v1/reservations/$id' && method == 'PATCH') {
        throw envelope(409, 'slot_taken');
      }
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00', '20:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);
    await tester.tap(find.widgetWithText(SahraButton, 'Change time or party'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SahraButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Change your booking'), findsOneWidget);
    // The grid is still there, so the next choice is one tap away rather than
    // behind a re-open.
    expect(find.text('\u20687:00 PM\u2069'), findsOneWidget);
  });

  testWidgets('NO MOVE BUTTON ON A BOOKING THAT HAS ALREADY STARTED', (tester) async {
    // The server answers `reservation_not_modifiable`, so a visible button
    // could only ever fail. Cancel stays, because a late cancel is better for
    // the venue than the no-show it replaces.
    final past = DateTime.now().toUtc().subtract(const Duration(hours: 2));
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') {
        return reservation(at: past.toIso8601String());
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);

    expect(find.widgetWithText(SahraButton, 'Change time or party'), findsNothing);
    expect(find.widgetWithText(SahraButton, 'Cancel booking'), findsOneWidget);
  });

  testWidgets('a CANCELLED booking offers neither', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') {
        return reservation(status: 'cancelled_by_user', cancelledBy: 'user');
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport);

    expect(find.widgetWithText(SahraButton, 'Change time or party'), findsNothing);
    expect(find.widgetWithText(SahraButton, 'Cancel booking'), findsNothing);
  });

  testWidgets('both sheets open in Arabic with Arabic copy', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/reservations/$id') return reservation();
      if (path == '/v1/reservations/$id/available-slots') {
        return slots(<String>['19:00']);
      }
      if (path.contains('/restaurants/')) return <String, Object?>{};
      throw StateError('unexpected $method $path');
    });

    await pumpDetail(tester, transport: transport, locale: const Locale('ar'));

    await tester.tap(find.widgetWithText(SahraButton, 'إلغاء الحجز'));
    await tester.pumpAndSettle();
    expect(find.text('تلغي الحجز ده؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(SahraButton, 'خليك على الحجز'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SahraButton, 'غيّر الميعاد أو العدد'));
    await tester.pumpAndSettle();
    expect(find.text('غيّر حجزك'), findsOneWidget);
  });
}
