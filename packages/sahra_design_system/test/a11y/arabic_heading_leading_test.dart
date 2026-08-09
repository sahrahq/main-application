import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// ARABIC HEADINGS USE THE LEADING THE ARABIC GUIDELINE DRAWS.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT THIS IS, AND WHAT IT IS NOT
/// ─────────────────────────────────────────────────────────────────────────
///
/// It is NOT a clipping test, and the reason is worth keeping.
///
/// The Arabic venue hero was reported as clipping the final «ج» of «ليالي
/// لاونج» — carried as a cosmetic flag, then scheduled as a defect to fix.
/// Enlarging the golden seven times showed the glyph is **complete**. Reem Kufi
/// is a Kufi face: its letterforms are angular and flat-bottomed by design, and
/// at 1x a flat-bottomed «ج» reads exactly like a descender that has been cut.
/// There was nothing to fix, and a test asserting "no ink on the last row"
/// would have been asserting something false about how the font is drawn.
///
/// What the investigation DID turn up is real and separate. Every heading slot
/// used `leading-tight` (1.15) for BOTH scripts, and
/// `docs/design/guidelines/type-arabic.html` draws its heading sample at
/// **1.3**. DESIGN-RULES.md is explicit that the HTML wins when it disagrees
/// with our value, and this exact call was already made once: `leading-arabic`
/// (1.7) exists because the guideline had a number tokens.json did not.
///
/// So Arabic headings moved to 1.3, and this is what keeps them there.
///
/// ── AND IT READS THE NUMBER OUT OF THE GUIDELINE ─────────────────────────
///
/// Comparing the theme to a literal `1.3` written here would be comparing our
/// value to our value. The number is parsed out of the guideline HTML, so the
/// document stays the source and editing it forces the theme to follow — the
/// same shape as `dietary_vocabulary_test.dart` reading the CHECK constraint
/// off disk rather than trusting a copy.
void main() {
  String guideline(String name) =>
      File('../../docs/design/guidelines/$name').readAsStringSync();

  /// Every `line-height:` a guideline draws.
  List<double> leadings(String html) => RegExp(r'line-height:\s*([0-9.]+)')
      .allMatches(html)
      .map((m) => double.parse(m.group(1)!))
      .toList();

  late List<double> arabicLeadings;

  setUpAll(() {
    arabicLeadings = leadings(guideline('type-arabic.html'));
  });

  test('the guideline was read and it specifies leadings — census', () {
    // Without this, a renamed file leaves the list empty and both assertions
    // below compare against nothing at all.
    expect(
      arabicLeadings,
      isNotEmpty,
      reason: 'type-arabic.html parsed to no line-height — the file moved or '
          'its markup changed, and this test is now vacuous.',
    );
    // Two samples: body at 1.7, the 32px heading at 1.3.
    expect(arabicLeadings.toSet(), containsAll(<double>[1.3, 1.7]));
  });

  test('the tokens ARE the guideline, not values of our own', () {
    expect(
      SahraTokens.leadingArabic,
      arabicLeadings.reduce((a, b) => a > b ? a : b),
      reason: 'leading-arabic must be the loosest value the Arabic guideline '
          'draws — its body line-height.',
    );
    expect(
      SahraTokens.leadingArabicDisplay,
      arabicLeadings.reduce((a, b) => a < b ? a : b),
      reason: 'leading-arabic-display must be the tightest value the Arabic '
          'guideline draws — its heading line-height. Every Arabic heading in '
          'the product was at 1.15, which is the LATIN number.',
    );
  });

  /// The eight slots that take the display treatment.
  Map<String, TextStyle?> headings(TextTheme t) => <String, TextStyle?>{
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
      };

  final TextTheme arabic = SahraTypography.arabic(const Color(0xFF000000));
  final TextTheme latin = SahraTypography.latin(const Color(0xFF000000));

  test('every heading slot exists in both themes — census', () {
    // Asserted rather than assumed because of the five-null-slots defect: an
    // unset slot silently inherits Poppins, which has no Arabic glyphs, and
    // every venue name in the list rendered as empty boxes.
    for (final t in <TextTheme>[arabic, latin]) {
      for (final e in headings(t).entries) {
        expect(e.value, isNotNull, reason: '${e.key} is unset');
      }
    }
    expect(headings(arabic).length, 8);
  });

  test('every ARABIC heading is at the Arabic heading leading', () {
    final wrong = headings(arabic)
        .entries
        .where((e) => e.value!.height != SahraTokens.leadingArabicDisplay)
        .map((e) => '${e.key} is ${e.value!.height}')
        .toList();
    expect(wrong, isEmpty);
  });

  test('and LATIN headings were not moved with them', () {
    // The two scripts have different values on purpose. The risk of a change
    // like this is somebody later collapsing it back to one number — and one of
    // the two directions is a silent redesign of every English screen.
    final wrong = headings(latin)
        .entries
        .where((e) => e.value!.height != SahraTokens.leadingTight)
        .map((e) => '${e.key} is ${e.value!.height}')
        .toList();
    expect(wrong, isEmpty);
  });

  test('the two are actually different — a guard that passed before is no guard', () {
    expect(SahraTokens.leadingArabicDisplay, isNot(SahraTokens.leadingTight));
    expect(
      SahraTokens.leadingArabicDisplay,
      greaterThan(SahraTokens.leadingTight),
    );
  });
}
