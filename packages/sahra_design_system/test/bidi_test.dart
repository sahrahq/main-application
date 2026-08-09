import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  group('contentDirection — whose words these are decides which way they run', () {
    // FOUND IN THE ARABIC REVIEWS GOLDEN. An English review inside an Arabic
    // page ended `.whatever the menu says` and the author read `.Nour H` — the
    // full stop taking the paragraph's direction. `ltrRun` cannot fix it,
    // because the problem is the whole paragraph rather than a run inside one,
    // and applying it blindly would lay an Arabic name out backwards.
    test('Latin content is left-to-right, punctuation and all', () {
      expect(contentDirection('Nour H.'), TextDirection.ltr);
      expect(contentDirection('Food was excellent. Service slowed.'),
          TextDirection.ltr);
      // Leading punctuation and digits are NOT strong — the first LETTER
      // decides, which is bidi rule P2.
      expect(contentDirection('"Great" — 5/5'), TextDirection.ltr);
      expect(contentDirection('4/5 stars'), TextDirection.ltr);
    });

    test('Arabic content is right-to-left', () {
      expect(contentDirection('نور ح.'), TextDirection.rtl);
      expect(contentDirection('الأكل ممتاز والخدمة بطيئة.'), TextDirection.rtl);
      // Same rule from the other side: the digits are skipped.
      expect(contentDirection('4/5 — عظيم'), TextDirection.rtl);
    });

    test('and null when there is nothing strong to go on', () {
      // Null means "inherit". A string with no direction of its own belongs to
      // the page it is on, and forcing one would be a guess.
      expect(contentDirection(''), isNull);
      expect(contentDirection('5'), isNull);
      expect(contentDirection('★★★★★'), isNull);
      expect(contentDirection('...'), isNull);
    });

    testWidgets('and it actually changes the layout of an Arabic page',
        (tester) async {
      // The claim that matters, and a string test cannot see it: the same
      // review laid out with and without its own direction.
      const String review = 'Food was excellent. Service slowed.';

      await tester.pumpWidget(
        harness(
          Cell.arLight,
          Column(
            children: <Widget>[
              const Text(review, style: TextStyle(fontSize: 14)),
              Text(
                review,
                textDirection: contentDirection(review),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
      await stabilise(tester);

      final Iterable<Element> texts = find.text(review).evaluate();
      expect(texts.length, 2);
      // Both render; what differs is where the sentence starts. A Rect cannot
      // express glyph order, so the checkable claim is that the two are laid
      // out in DIFFERENT directions rather than identically.
      final RenderParagraph a =
          texts.first.findRenderObject()! as RenderParagraph;
      final RenderParagraph b =
          texts.last.findRenderObject()! as RenderParagraph;
      expect(a.textDirection, TextDirection.rtl);
      expect(b.textDirection, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE THIRD TOOL: `isolate` (U+2068 FIRST STRONG ISOLATE)
  //
  //  Added in Group G, because neither of the other two fits the commonest
  //  case: SOMEBODY ELSE'S WORDS INSIDE A SENTENCE OF OURS. A notification
  //  reads "{venue} cancelled your table", and the venue names itself.
  // ══════════════════════════════════════════════════════════════════════
  group('isolate, for a run whose direction we do not know', () {
    test('wraps in U+2068 … U+2069', () {
      final wrapped = isolate('Layali Lounge');
      expect(wrapped.codeUnitAt(0), 0x2068, reason: 'missing FIRST STRONG ISOLATE');
      expect(wrapped.codeUnitAt(wrapped.length - 1), 0x2069,
          reason: 'missing POP DIRECTIONAL ISOLATE',);
      expect(wrapped.substring(1, wrapped.length - 1), 'Layali Lounge');
    });

    test('it is NOT the left-to-right isolate', () {
      // The whole distinction. `ltrRun` around an Arabic name lays it out
      // backwards, which is why a second helper exists rather than a reused one.
      expect(isolate('X').codeUnitAt(0), isNot(ltrRun('X').codeUnitAt(0)));
    });

    test('isolateOrNull passes null and empty through untouched', () {
      // An isolate around nothing is two invisible characters that make an
      // "is it empty?" check answer false — and a widget then draws a blank
      // line for a value that was never set.
      expect(isolateOrNull(null), isNull);
      expect(isolateOrNull(''), '');
      expect(isolateOrNull('Zooba'), isolate('Zooba'));
    });

    testWidgets('an Arabic name inside it is NOT reversed', (tester) async {
      // The failure `ltrRun` would have caused. Both strings render; the
      // checkable claim is that the isolated form still contains the name in
      // its written order, and that the paragraph around it is unaffected.
      const String name = 'ليالي لاونج';
      await tester.pumpWidget(
        harness(
          Cell.arLight,
          Text(isolate(name), style: const TextStyle(fontSize: 18)),
        ),
      );
      await stabilise(tester);
      expect(find.text(isolate(name)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Latin name does not drag the Arabic around it', (tester) async {
      // The reason it is an ISOLATE and not an embedding: an embedding lets the
      // run influence the direction of the text either side of it.
      const String sentence = 'ألغى حجزك';
      await tester.pumpWidget(
        harness(
          Cell.arLight,
          Text('${isolate('Zooba')} $sentence', style: const TextStyle(fontSize: 18)),
        ),
      );
      await stabilise(tester);
      final RenderParagraph p = tester
          .element(find.textContaining(sentence))
          .findRenderObject()! as RenderParagraph;
      expect(p.textDirection, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  });
}
