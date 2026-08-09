import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';
import 'package:sahra_customer_app/features/notifications/domain/app_notification.dart';
import 'package:sahra_customer_app/features/notifications/presentation/notification_copy.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';

import '../support/fixture_dates.dart';

/// The renderer that turns a `type` + `data` into words.
///
/// ─────────────────────────────────────────────────────────────────────────
/// EVERY KIND, IN BOTH LANGUAGES, ENUMERATED FROM THE ENUM
/// ─────────────────────────────────────────────────────────────────────────
///
/// Not a list of kinds beside the test. `NotificationKind.values` is the
/// catalogue, so a kind added tomorrow is covered by these assertions the
/// moment it exists — the rule this codebase settled on after the
/// `updated_at` sweep: a test must enumerate from the catalogue, never from a
/// list kept next to it.
void main() {
  /// Renders [n] inside a real localised tree, as the screen would.
  Future<NotificationCopy?> render(
    WidgetTester tester,
    AppNotification n, {
    required String locale,
  }) async {
    NotificationCopy? out;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...SahraTheme.localizationsDelegates,
        ],
        home: Builder(
          builder: (context) {
            out = notificationCopy(n, context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return out;
  }

  AppNotification make(NotificationKind kind, [Map<String, String>? data]) =>
      AppNotification(
        id: 'n1',
        kind: kind,
        data: data ??
            <String, String>{
              'reservation_id': 'r1',
              'venue': 'Layali Lounge',
              'venue_ar': 'ليالي لاونج',
              'date': kFutureDate,
              'time': '21:00',
              'party': '4',
              'code': 'SHR-8241',
            },
        createdAt: DateTime(2026, 8, 4),
        readAt: null,
      );

  final List<NotificationKind> real = NotificationKind.values
      .where((k) => k != NotificationKind.unknown)
      .toList();

  group('every kind renders in both languages', () {
    for (final kind in real) {
      for (final locale in <String>['en', 'ar']) {
        testWidgets('${kind.wire} [$locale]', (tester) async {
          final copy = await render(tester, make(kind), locale: locale);

          expect(copy, isNotNull, reason: '${kind.wire} produced no copy');
          expect(copy!.title.trim(), isNotEmpty);

          // NO UNSUBSTITUTED PLACEHOLDER. An ARB value whose placeholder name
          // does not match the call renders the literal `{venue}` on screen,
          // and nothing else in the pipeline objects.
          expect(copy.title, isNot(contains('{')));
          expect(copy.body, isNot(contains('{')));
        });
      }
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE ICON MUST BE ONE THE SET ACTUALLY HAS.
  //
  //  `SahraIcon` falls back to `Icons.help_outline` for a name it does not
  //  know, so an invented name renders as a QUESTION MARK IN A CIRCLE. Beside
  //  a cancellation that reads "we don't know what happened".
  //
  //  This is not hypothetical: the first draft used `x-circle` and `info`,
  //  neither of which exists, and it was found by enlarging an Arabic golden
  //  rather than by any test. Now it is a test.
  // ══════════════════════════════════════════════════════════════════════
  group('every icon exists', () {
    final Set<String> known = <String>{
      ...SahraIcon.drawnIcons,
      ...SahraIcon.fallbackIcons,
    };

    test('the icon set was read and is not empty — census', () {
      // Without this, an empty `known` would make every assertion below pass
      // by finding nothing to disagree with.
      expect(known.length, greaterThan(15));
    });

    for (final kind in real) {
      testWidgets('${kind.wire} uses a real icon', (tester) async {
        final copy = await render(tester, make(kind), locale: 'en');
        expect(
          known,
          contains(copy!.icon),
          reason: '"${copy.icon}" is not in SahraIcon — it will render as a '
              'question mark. Pick an existing name, or add it to the set '
              'deliberately.',
        );
      });
    }
  });

  group('a notification with almost nothing in it still renders', () {
    // The screen a diner opens to find out their table was cancelled has to
    // work on the day something is wrong with the payload. Every field absent
    // is the worst case, and it must produce a vaguer sentence — never a blank
    // row and never a throw.
    for (final kind in real) {
      for (final locale in <String>['en', 'ar']) {
        testWidgets('${kind.wire} with empty data [$locale]', (tester) async {
          final copy =
              await render(tester, make(kind, <String, String>{}), locale: locale);
          expect(copy, isNotNull);
          expect(copy!.title.trim(), isNotEmpty);
          expect(copy.title, isNot(contains('{')));
        });
      }
    }
  });

  testWidgets('an unknown kind renders NOTHING, and does not throw', (tester) async {
    // The row is skipped. A newer server must cost a diner one invisible entry,
    // not an error state over their whole history.
    expect(await render(tester, make(NotificationKind.unknown), locale: 'ar'), isNull);
  });

  group('the venue name is isolated, not forced left-to-right', () {
    // `ltrRun` around «ليالي لاونج» would lay an Arabic name out backwards.
    // U+2068 FIRST STRONG ISOLATE lets the run pick its own direction.
    // Escapes, never the literal characters — a literal isolate in source
    // reorders the source line itself, which is the defect this file is about.
    const String fsi = '\u2068';
    const String lri = '\u2066';

    testWidgets('an Arabic venue name in the Arabic app', (tester) async {
      final copy = await render(tester, make(NotificationKind.waitlistOffer),
          locale: 'ar',);
      expect(copy!.title, contains(fsi));
      expect(
        copy.title,
        isNot(contains('$lriل')),
        reason: 'the Arabic name is inside a LEFT-TO-RIGHT isolate, which lays '
            'it out backwards',
      );
    });

    testWidgets('a Latin venue name in the Arabic app', (tester) async {
      final copy = await render(
        tester,
        make(NotificationKind.waitlistOffer, <String, String>{
          'venue': 'Zooba',
          'venue_ar': 'Zooba',
          'date': kFutureDate,
          'time': '21:00',
        }),
        locale: 'ar',
      );
      expect(copy!.title, contains('${fsi}Zooba'));
    });
  });

  testWidgets('the cancellation reason is a QUOTE, not part of our sentence',
      (tester) async {
    // A whole clause somebody at the venue typed. Interpolated into an Arabic
    // line it wraps mid-phrase and reads across two edges; on its own line with
    // its own direction it reads.
    final copy = await render(
      tester,
      make(NotificationKind.reservationCancelledByVenue, <String, String>{
        'venue': 'Layali Lounge',
        'date': kFutureDate,
        'time': '21:00',
        'reason': 'A burst pipe in the kitchen',
      }),
      locale: 'ar',
    );
    expect(copy!.quote, 'A burst pipe in the kitchen');
    expect(copy.body, isNot(contains('burst')));
  });

  testWidgets('no reason means no quote line at all', (tester) async {
    final copy = await render(
      tester,
      make(NotificationKind.reservationCancelledByVenue, <String, String>{
        'venue': 'Layali Lounge',
        'date': kFutureDate,
        'time': '21:00',
        'reason': '   ',
      }),
      locale: 'en',
    );
    // Whitespace is not a reason. An empty quote line would be a blank gap the
    // diner reads as a rendering fault.
    expect(copy!.quote, isNull);
  });

  testWidgets('the clock time is isolated so bidi cannot move it', (tester) async {
    final copy =
        await render(tester, make(NotificationKind.reservationReminder2h), locale: 'ar');
    expect(copy!.body, contains('\u206621:00'));
  });

  testWidgets('the Arabic app prefers the Arabic name, and falls back', (tester) async {
    final arabic = await render(tester, make(NotificationKind.waitlistOffer), locale: 'ar');
    expect(arabic!.title, contains('ليالي لاونج'));

    // Only an English name recorded — better a name in the wrong script than a
    // notification about "the restaurant".
    final fallback = await render(
      tester,
      make(NotificationKind.waitlistOffer, <String, String>{
        'venue': 'Layali Lounge',
        'date': kFutureDate,
        'time': '21:00',
      }),
      locale: 'ar',
    );
    expect(fallback!.title, contains('Layali Lounge'));
  });

  testWidgets('the waitlist offer does NOT promise a claim window', (tester) async {
    // The table is not held (docs/decisions/2026-08-09-group-g-split.md §3.1).
    // doc 11 draws "claim in 10 min"; saying that would send a diner to a slot
    // somebody else already took. If withholding ever lands, this assertion is
    // where the copy has to be revisited.
    for (final locale in <String>['en', 'ar']) {
      final copy =
          await render(tester, make(NotificationKind.waitlistOffer), locale: locale);
      expect(copy!.body, isNot(contains('10')));
      expect(copy.body.toLowerCase(), isNot(contains('claim')));
    }
  });
}
