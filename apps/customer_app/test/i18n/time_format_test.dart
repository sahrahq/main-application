import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sahra_customer_app/features/reservations/presentation/reservation_copy.dart';

/// `timeOfDay` — the one owner, and the two facts about it that a tidy-up
/// would otherwise quietly destroy.
void main() {
  // `intl` needs its locale data loaded before any non-`en` DateFormat. The
  // app does this at startup; a unit test has to do it itself or every Arabic
  // assertion below fails for a reason that has nothing to do with the claim.
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('ar_EG');
    await initializeDateFormatting('en');
  });

  Widget host(Locale locale, bool use24, void Function(BuildContext) body) => MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (BuildContext c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: use24),
            child: Builder(builder: (BuildContext c2) {
              body(c2);
              return const SizedBox();
            }),
          ),
        ),
      );

  testWidgets('THE SEPARATORS DIFFER, and that is not a defect to tidy away', (t) async {
    // Measured 2026-08-10: English separates the numeral from AM/PM with
    // U+202F (narrow no-break space); Arabic uses a plain U+0020. `DateFormat`
    // emits the right one per locale and we do not choose it.
    //
    // This test exists so a future "normalise the whitespace" change fails
    // loudly instead of silently making one locale wrong.
    final String en = DateFormat('jm', 'en').format(DateTime(2000, 1, 1, 20, 0));
    final String ar = DateFormat('jm', 'ar').format(DateTime(2000, 1, 1, 20, 0));
    expect(en.contains('\u202F'), isTrue, reason: 'en lost its narrow no-break space');
    expect(ar.contains('\u0020'), isTrue, reason: 'ar lost its plain space');
    expect(en.contains('\u202F'), isNot(ar.contains('\u202F')),
        reason: 'The two locales must NOT use the same separator.');
  });

  testWidgets('ar uses LATIN digits — ar_EG would not, which is why it is not used', (t) async {
    // The whole reason locale `ar` is passed instead of `ar_EG`.
    final String ar = DateFormat('jm', 'ar').format(DateTime(2000, 1, 1, 20, 0));
    final String arEg = DateFormat('jm', 'ar_EG').format(DateTime(2000, 1, 1, 20, 0));
    expect(RegExp(r'[0-9]').hasMatch(ar), isTrue, reason: 'ar must give Latin figures');
    expect(RegExp('[٠-٩]').hasMatch(ar), isFalse);
    // Guards the guard: if ar_EG ever stopped forcing Arabic-Indic, the
    // reasoning in `timeOfDay` would need revisiting rather than silently
    // becoming untrue.
    expect(RegExp('[٠-٩]').hasMatch(arEg), isTrue,
        reason: 'ar_EG no longer forces Arabic-Indic — revisit timeOfDay.');
  });

  testWidgets('12 vs 24 follows the DEVICE, and the result is bidi-isolated', (t) async {
    late String twelve, twentyFour;
    await t.pumpWidget(host(const Locale('ar'), false, (c) => twelve = timeOfDay('20:00', c)));
    await t.pumpWidget(host(const Locale('ar'), true, (c) => twentyFour = timeOfDay('20:00', c)));
    expect(twelve, contains('8'));
    expect(twelve, contains('م'));
    expect(twentyFour, contains('20'));
    expect(twentyFour, isNot(contains('م')));
    // U+2068 FSI … U+2069 PDI around the whole expression.
    expect(twelve.codeUnitAt(0), 0x2068);
    expect(twelve.codeUnitAt(twelve.length - 1), 0x2069);
  });

  testWidgets('unparseable input is returned unchanged rather than throwing', (t) async {
    late String out;
    await t.pumpWidget(host(const Locale('en'), false, (c) => out = timeOfDay('not-a-time', c)));
    expect(out, 'not-a-time');
  });
}
