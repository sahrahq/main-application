import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/pending_booking.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';
import '../support/screen_harness.dart';

/// WHAT THE SENTENCE ACTUALLY SAYS.
///
/// The round-trip test asserts the party size survives sign-in, and it does —
/// it reads the notifier and the value is there. It was right to pass and it
/// is not vacuous. But every assertion in it is about STATE, and the defect
/// was in the RENDERING: the correct number was handed to a plural that had
/// no `#` in it, and the screen read "…at 18:00, guests".
///
/// A value can be present, correct, and carried faithfully through four
/// layers, and still not appear. So these assertions read the screen.
void main() {
  const String venueId = '11111111-1111-4111-8111-111111111111';

  const PendingSelection full = PendingSelection(
    restaurantId: venueId,
    venueName: 'El Fishawy',
    startsAt: '2026-08-04T18:00:00.000Z',
    slotLabel: '20:30',
    date: '2026-08-04',
    partySize: 4,
  );

  Future<void> pump(WidgetTester tester, PendingSelection selection, Cell cell) async {
    await tester.pumpWidget(
      screenHarness(
        cell,
        SignInScreen(pendingRestaurantId: venueId, onClose: () {}),
        overrides: <Override>[
          transportProvider.overrideWithValue(FakeTransport((_, __, ___) => throw offline)),
          pendingBookingProvider(venueId).overrideWith(() => _Parked(selection)),
        ],
      ),
    );
    await stabilise(tester);
  }

  testWidgets('the party size appears as a NUMBER, in both locales', (tester) async {
    for (final cell in <Cell>[Cell.enLight, Cell.arLight]) {
      await pump(tester, full, cell);

      // The figure itself. Latin in both locales (DESIGN-RULES.md), so the
      // same assertion holds for Arabic.
      expect(
        find.textContaining('4'),
        findsWidgets,
        reason: '[${cell.slug}] the party size is missing from the sentence',
      );

      // And specifically NOT the shape the defect had: a unit word with
      // nothing in front of it.
      final sentence = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('20:30'), orElse: () => '');
      expect(sentence, isNotEmpty, reason: '[${cell.slug}] no slot sentence rendered');
      expect(
        RegExp(r'[,،]\s*(guests?|فرد|أفراد)').hasMatch(sentence),
        isFalse,
        reason: '[${cell.slug}] the unit follows the comma with no figure: '
            '"$sentence"',
      );
    }
  });

  testWidgets('an incomplete selection renders NO sentence at all', (tester) async {
    // Each of these is individually plausible and each used to produce a line
    // that still read as finished.
    const List<PendingSelection> partials = <PendingSelection>[
      PendingSelection(
        restaurantId: venueId,
        venueName: '',
        startsAt: '2026-08-04T18:00:00.000Z',
        slotLabel: '20:30',
        date: '2026-08-04',
        partySize: 4,
      ),
      PendingSelection(
        restaurantId: venueId,
        venueName: 'El Fishawy',
        startsAt: '2026-08-04T18:00:00.000Z',
        slotLabel: '20:30',
        date: '2026-08-04',
        partySize: 0,
      ),
      PendingSelection(
        restaurantId: venueId,
        venueName: 'El Fishawy',
        startsAt: '2026-08-04T18:00:00.000Z',
        slotLabel: '',
        date: '',
        partySize: 4,
      ),
    ];

    for (final partial in partials) {
      await pump(tester, partial, Cell.enLight);
      expect(
        find.textContaining('Your table:'),
        findsNothing,
        reason: 'a partial selection built the sentence anyway',
      );
      // The screen is still usable — this is a missing reassurance, not a
      // broken sign-in.
      expect(find.text('Sign in to book'), findsOneWidget);
    }
  });

  testWidgets('a complete selection DOES render it — the guard is not always-off',
      (tester) async {
    // Without this the test above passes on a screen that never draws the
    // sentence under any circumstances.
    await pump(tester, full, Cell.enLight);
    expect(find.textContaining('Your table:'), findsOneWidget);
  });
}

class _Parked extends PendingBooking {
  _Parked(this._selection);
  final PendingSelection _selection;

  @override
  PendingSelection build(String restaurantId) => _selection;
}
