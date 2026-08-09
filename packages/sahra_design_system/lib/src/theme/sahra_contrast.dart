/// WCAG contrast, and the thing `textContrastGuideline` does not tell you.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS FILE EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// `textContrastGuideline` has failed this codebase twice with a number that
/// was not measuring the colour. Both times the reported ratio was around
/// 2–3.7:1 for text whose token pair measures 5.8–8.8:1; both times the pixel
/// it sampled was an ANTI-ALIASED EDGE — a blend of the text colour and the
/// background — rather than the core of a glyph.
///
/// The important part is not that the number is pessimistic. It is that on the
/// LIGHT surfaces, **once the sampler lands on a 50% edge, no foreground colour
/// can pass**: pure black on light `surfaceCard`, sampled at a 50% blend,
/// scores 3.92 and AA needs 4.5. A guard no colour can satisfy is not a guard,
/// it is a wall, and the reflex on hitting it is to move a layout block until
/// the sampling changes — which fixes the reading and nothing else.
///
/// **This does NOT hold on the night surfaces**, and the distinction matters:
/// near-white ink reaches 4.72–5.16 there at the same edge, so a night-theme
/// failure may be real. That correction came from asserting the claim rather
/// than writing it down — the first version of this paragraph said "our
/// surfaces" and was wrong for half of them.
///
/// So the ceiling is COMPUTABLE, and it is computed: [bestPossibleEdgeContrast]
/// gives the highest ratio any foreground could reach on a given background at
/// a given edge blend. `palette_contrast_test.dart` asserts it per surface, so
/// the claims above are measurements that re-run, not notes somebody wrote down
/// once.
///
/// [kEdgeSampledContrastCaveat] is appended to the failure by the two test
/// harnesses that run the guideline, so the next person to hit it reads this at
/// the point of failure instead of finding
/// `docs/decisions/2026-08-09-review-reports.md` §5.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

/// WCAG 2.1 relative luminance, straight from the spec.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// The WCAG 2.1 contrast ratio between two opaque colours, 1.0–21.0.
double sahraContrastRatio(Color fg, Color bg) {
  final double a = _luminance(fg);
  final double b = _luminance(bg);
  final double hi = a > b ? a : b;
  final double lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG AA for body text (1.4.3). Large text and non-text UI need 3:1.
const double kBodyTextContrastMin = 4.5;

/// [top] composited over [bottom] at [alpha]. Source-over, opaque result.
Color blendOver(Color top, Color bottom, double alpha) => Color.from(
      alpha: 1,
      red: top.r * alpha + bottom.r * (1 - alpha),
      green: top.g * alpha + bottom.g * (1 - alpha),
      blue: top.b * alpha + bottom.b * (1 - alpha),
    );

/// What [fg] on [bg] actually measures when the sampled pixel is an
/// anti-aliased edge that is only [alpha] of the way to the text colour.
double edgeSampledContrast(Color fg, Color bg, {double alpha = 0.5}) =>
    sahraContrastRatio(blendOver(fg, bg, alpha), bg);

/// THE CEILING. The best ratio ANY foreground colour can reach on [bg] when
/// the sampled pixel is an [alpha] edge.
///
/// The extremes of the colour space bound it: nothing is darker than black or
/// lighter than white, and contrast is monotonic in luminance either side of
/// the background. If this is below [kBodyTextContrastMin], a
/// `textContrastGuideline` failure on that background CANNOT be fixed by
/// changing the colour, and treating it as a colour problem will waste the next
/// reader's afternoon.
double bestPossibleEdgeContrast(Color bg, {double alpha = 0.5}) {
  // design-exempt: the ENDS OF THE COLOUR SPACE, not design values. Nothing is
  // darker than #000 or lighter than #FFF, which is precisely why they bound
  // the ceiling — substituting a token here would compute the best a TOKEN can
  // do, which is a different and much weaker claim.
  const Color black = Color(0xFF000000);
  // design-exempt: as above.
  const Color white = Color(0xFFFFFFFF);
  return math.max(
    edgeSampledContrast(black, bg, alpha: alpha),
    edgeSampledContrast(white, bg, alpha: alpha),
  );
}

/// Appended to every `textContrastGuideline` failure by the test harnesses.
///
/// Deliberately says what to do FIRST and what it means SECOND — somebody
/// reading this has a red test and wants the next step, not the history.
const String kEdgeSampledContrastCaveat = '''

─────────────────────────────────────────────────────────────────────────────
BEFORE YOU CHANGE A COLOUR — read the reported ratio sceptically.
─────────────────────────────────────────────────────────────────────────────
`textContrastGuideline` samples RENDERED PIXELS, and it frequently lands on an
anti-aliased glyph edge rather than on the core of a letter. When it does, the
number it reports is the contrast of a BLEND of your text colour and the
background, not of the text colour.

Do this, in order:

  1. Compute the real pair with `sahraContrastRatio(fg, bg)`. If that clears
     4.5:1, the token is fine and the reported number is a sampling artefact.
  2. Compute `bestPossibleEdgeContrast(bg)`. If THAT is below 4.5, no colour
     whatsoever can pass this check on that background, so darkening the token
     cannot work and moving the widget only changes which pixel gets sampled.
     On the LIGHT surfaces it always is: the ceiling is 3.85–3.93 and pure
     black scores 3.92 on `surfaceCard`.
  3. On the NIGHT surfaces the ceiling is 4.84–5.29, so a failure there is NOT
     automatically an artefact — check step 1 before assuming.
  4. Either way the failure is usually telling you something true: the text has
     more edge than core. That is thin, small text — most often Arabic at 13pt
     in a light weight. The fix is MORE INK (a heavier weight, a larger size,
     or a stronger token such as `textSoft` in place of `textFaint`), not a
     different hue.

Both previous occurrences were this, both on a light surface. The first was
worked around by moving a layout block, which is why the second one happened.
Full analysis: docs/decisions/2026-08-09-review-reports.md §5.
─────────────────────────────────────────────────────────────────────────────
''';
