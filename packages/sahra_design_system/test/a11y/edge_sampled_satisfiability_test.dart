import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// THE SKIP DECISION ITSELF, WITH BOTH BRANCHES EXERCISED.
///
/// `expectContrast` in the two harnesses skips `textContrastGuideline` when
/// `edgeSampledGuidelineIsSatisfiable` says no. That predicate is the only
/// thing standing between "we moved a check that cannot pass" and "we quietly
/// stopped checking contrast", so it gets its own test — and it is not enough
/// to show it returns false for our palette. **A predicate that returns false
/// for every input is not a decision, it is a disabled check**, and with the
/// shipped tokens the false branch is the only one that ever runs.
///
/// So the true branch is exercised against a SYNTHETIC surface below. That is
/// the difference between knowing the skip is conditional and assuming it.
void main() {
  final SahraSemantics light = SahraSemantics.light();
  final SahraSemantics dark = SahraSemantics.dark();

  List<Color> textsOf(SahraSemantics s) =>
      <Color>[s.textBody, s.textSoft, s.textFaint, s.accentOnSurface];

  group('the guideline is unsatisfiable on the shipped palette — the FALSE branch', () {
    test('light: pure black itself cannot reach AA, so no colour can', () {
      // The number that settles the whole argument. Requirement is 4.5.
      expect(bestPossibleEdgeContrast(light.surfacePage), lessThan(kBodyTextContrastMin));
      expect(edgeSampledGuidelineIsSatisfiable(textsOf(light), light.surfacePage), isFalse);
    });

    test('dark: the ceiling clears AA, but design-valid tokens still cannot', () {
      // Deliberately distinguished from the light case. Skipping dark is NOT
      // justified by an unreachable ceiling — 5.29 is reachable. It is
      // justified because `textSoft` (11.45 designed) samples 3.72, so the
      // guideline would be grading which token a component picked.
      expect(bestPossibleEdgeContrast(dark.surfacePage), greaterThan(kBodyTextContrastMin));
      expect(edgeSampledContrast(dark.textSoft, dark.surfacePage), lessThan(kBodyTextContrastMin));
      expect(sahraContrastRatio(dark.textSoft, dark.surfacePage),
          greaterThanOrEqualTo(kBodyTextContrastMin));
      expect(edgeSampledGuidelineIsSatisfiable(textsOf(dark), dark.surfacePage), isFalse);
    });
  });

  group('and it says YES when a palette can actually pass — the TRUE branch', () {
    // WHY THE SYNTHETIC CASE IS LIGHT-ON-DARK AND NOT BLACK-ON-WHITE.
    //
    // The first draft used pure black on pure white and FAILED at 3.98. The
    // edge model blends the glyph 50% into its background, and on a light
    // background that blend destroys the ratio no matter how dark the text
    // is — so 3.98 is the ceiling for white backgrounds, full stop. On a dark
    // background the same blend lands mid-grey against near-black, which
    // clears AA comfortably.
    //
    // That asymmetry is the reason light mode can never pass and dark mode
    // can, and it is recorded here because the failing first draft was more
    // informative than the passing version would have been on its own.
    // design-exempt: the ends of the colour space, chosen BECAUSE they are not
    // design values — the point is a case our tokens do not produce, so the
    // true branch executes rather than being assumed.
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    test('white text on a black surface samples above AA, so the check runs', () {
      expect(edgeSampledContrast(white, black), greaterThanOrEqualTo(kBodyTextContrastMin));
      expect(edgeSampledGuidelineIsSatisfiable(<Color>[white], black), isTrue);
    });

    test('ONE token below the bar flips it to false — every token must clear it', () {
      // design-exempt: a deliberately weak grey, to prove the predicate is an
      // `every` and not an `any`. If it were `any`, a palette containing one
      // strong token would switch the guideline on for all the weak ones.
      const Color tooDim = Color(0xFF3A3A3A);
      expect(edgeSampledContrast(tooDim, black), lessThan(kBodyTextContrastMin));
      expect(edgeSampledGuidelineIsSatisfiable(<Color>[white, tooDim], black), isFalse);
    });
  });

  test('an EMPTY palette is refused rather than vacuously satisfied', () {
    // `every` on an empty iterable is true, which would turn the guideline back
    // on for a surface nothing was measured against — the vacuous-pass shape
    // this repo keeps finding.
    expect(edgeSampledGuidelineIsSatisfiable(<Color>[], const Color(0xFFFFFFFF)), isFalse);
  });
}
