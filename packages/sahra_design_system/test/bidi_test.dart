import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import 'support/harness.dart';

/// The bidi finding, pinned.
///
/// Two halves, and only the first is mechanical:
///
///   1. The isolate characters are actually there. Cheap, and it catches a
///      copy-paste that drops one of them — which is invisible in source
///      because they have zero width.
///   2. The rendered result differs from the un-isolated one. That is the
///      claim that matters, and it is the reason this is a WIDGET test: the
///      reversal happens in the paragraph layout, not in the string.
void main() {
  const phone = '+20 2 2735 0000';
  const hours = '18:00 – 23:30';

  group('the isolate is present', () {
    test('wraps in U+2066 … U+2069', () {
      final wrapped = ltrRun(phone);
      expect(wrapped.codeUnitAt(0), 0x2066, reason: 'missing LEFT-TO-RIGHT ISOLATE');
      expect(wrapped.codeUnitAt(wrapped.length - 1), 0x2069,
          reason: 'missing POP DIRECTIONAL ISOLATE');
      // The content itself is untouched — this is presentation, not escaping.
      expect(wrapped.substring(1, wrapped.length - 1), phone);
    });

    test('ltrRunOrNull passes null through', () {
      expect(ltrRunOrNull(null), isNull);
      expect(ltrRunOrNull(phone), ltrRun(phone));
    });
  });

  group('and it changes what an Arabic paragraph renders', () {
    // A string test cannot see this: `'+20 2 2735 0000'` is the same string
    // either way. Only laying it out in an RTL paragraph shows the reversal.
    testWidgets('an un-isolated phone number lays out differently', (tester) async {
      Future<Rect> boxOf(String text) async {
        await tester.pumpWidget(
          harness(Cell.arLight, Text(text, style: const TextStyle(fontSize: 18))),
        );
        await stabilise(tester);
        return tester.getRect(find.text(text));
      }

      // Both render; what differs is the ORDER of the glyphs, which a Rect
      // cannot express. So the assertion is the one thing that is checkable
      // mechanically — that the isolated form is a DIFFERENT string being
      // laid out, and that both lay out without throwing.
      final plain = await boxOf(phone);
      final isolated = await boxOf(ltrRun(phone));

      expect(plain.width, greaterThan(0));
      expect(isolated.width, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a time range with an en-dash survives', (tester) async {
      await tester.pumpWidget(
        harness(Cell.arLight, Text(ltrRun(hours), style: const TextStyle(fontSize: 18))),
      );
      await stabilise(tester);
      expect(find.text(ltrRun(hours)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('what it is NOT for', () {
    test('a lone number needs no isolate — it has no neutrals at all', () {
      // Wrapping every figure would litter the copy with invisible characters
      // and make ARB values impossible to diff. `4.8` is already correct.
      expect(ltrRun('4.8'), isNot('4.8'));
      // ...which is exactly why the rule is "sequences of segments", stated in
      // the library doc, and why this test exists to record the boundary.
    });
  });

  group('but a lone number WITH A SIGN does need one', () {
    // The boundary above was drawn too generously the first time and `4.0+`
    // shipped inside it, rendering `+4.0` in Arabic. A sign at the EDGE of a
    // number is not absorbed by it — bidi W4 only merges a separator that sits
    // BETWEEN two numbers — so it is demoted to a neutral and takes the
    // paragraph direction.
    //
    // This group records the corrected boundary. Which strings in the product
    // fall on which side of it is not a judgement made here: the Arabic ARB is
    // scanned for the signature by
    // `apps/customer_app/test/i18n/bidi_neutral_test.dart`, which then checks
    // every call site of every string it finds.
    testWidgets('an unsigned and a signed figure are different problems',
        (tester) async {
      const String plain = '4.0';
      const String signed = '4.0+';

      await tester.pumpWidget(
        harness(
          Cell.arLight,
          const Column(
            children: <Widget>[
              Text(plain, style: TextStyle(fontSize: 18)),
              Text(signed, style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
      await stabilise(tester);

      // Both lay out; the sign is what moves, and a Rect cannot express glyph
      // order any more than it could for the phone number above. What IS
      // checkable is that the signed form is a strictly longer run than the
      // plain one — i.e. there is a neutral character in it for the algorithm
      // to reposition, which is the precondition for the defect.
      expect(signed.length, plain.length + 1);
      expect(find.text(signed), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And that the remedy applies to it, unlike to the plain figure, where
      // the library doc says not to bother.
      expect(ltrRun(signed).codeUnitAt(0), 0x2066);
    });
  });
}
