import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/pending_booking.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';
import '../support/screen_harness.dart';
import '../support/fixture_dates.dart';

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
    startsAt: '${kFutureDate}T18:00:00.000Z',
    slotLabel: '20:30',
    date: kFutureDate,
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

      // THE SENTENCE FIRST, then assertions about it.
      //
      // This used to be `find.textContaining('4')` across the whole screen,
      // and it was VACUOUS: the fixture was dated the 4th of the month, so
      // "4 August" satisfied it and the party size was never read at all. The
      // message rendered "…at 18:00, # guests" for as long as that fixture
      // held its date, with this test green the entire time.
      //
      // Two things had to change. The assertion now reads the SENTENCE rather
      // than the screen, and it looks for the figure NEXT TO ITS UNIT rather
      // than anywhere at all — so no other number on the page can stand in
      // for it.
      final sentence = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          // `timeOfDay()` renders 8:30 PM / ٨:٣٠ م rather than 20:30, so the
          // sentence is located by the HOUR. This test is about the party
          // size appearing as a figure next to its unit; the time format is
          // `time_format_test.dart`'s to own.
          .firstWhere((d) => d.contains('8:30'), orElse: () => '');
      expect(sentence, isNotEmpty, reason: '[${cell.slug}] no slot sentence rendered');

      expect(
        RegExp(r'\b4\s*\S*\s*(guests?|فرد|أفراد)').hasMatch(sentence),
        isTrue,
        reason: '[${cell.slug}] the party size is not next to its unit: '
            '"$sentence"',
      );

      // And specifically NOT the two shapes the defect took: a unit word with
      // nothing in front of it, or an unsubstituted ICU marker.
      expect(
        RegExp(r'[,،]\s*(guests?|فرد|أفراد)').hasMatch(sentence),
        isFalse,
        reason: '[${cell.slug}] the unit follows the comma with no figure: '
            '"$sentence"',
      );
      expect(
        sentence.contains('#'),
        isFalse,
        reason: '[${cell.slug}] an ICU `#` reached the screen unsubstituted — '
            'gen-l10n does not replace it: "$sentence"',
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
        startsAt: '${kFutureDate}T18:00:00.000Z',
        slotLabel: '20:30',
        date: kFutureDate,
        partySize: 4,
      ),
      PendingSelection(
        restaurantId: venueId,
        venueName: 'El Fishawy',
        startsAt: '${kFutureDate}T18:00:00.000Z',
        slotLabel: '20:30',
        date: kFutureDate,
        partySize: 0,
      ),
      PendingSelection(
        restaurantId: venueId,
        venueName: 'El Fishawy',
        startsAt: '${kFutureDate}T18:00:00.000Z',
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

  testWidgets('a complete selection DOES render it — the guard is not always-off', (tester) async {
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
