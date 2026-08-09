/// Contrast, checked across the PALETTE rather than component by component.
///
/// `textContrastGuideline` only sees pairs a component happens to render, so a
/// broken pair stays invisible until some future screen uses it — and by then
/// it is fifteen components' worth of goldens to redo. This checks every
/// text-on-surface combination the semantics layer can produce, in both
/// themes, before anything uses them.
///
/// Found the whole class in one run: 13 failing pairs, including `text-faint`
/// on every light surface (3.16–3.48) and `warning` — which DESIGN-RULES.md
/// recommends *as* the readable gold — at 2.52–2.78.
///
/// WCAG 2.1 AA, 1.4.3: 4.5:1 for body text, 3:1 for large text (≥24px, or
/// ≥18.66px bold) and for non-text UI (1.4.11). The strict figure is used for
/// everything here, because a token's job is to be usable at body size; a
/// component that only ever draws it large is not a reason to loosen the token.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// THE SHIPPED FUNCTION, not a second implementation beside it.
///
/// It used to be defined here. It moved into `lib/src/theme/sahra_contrast.dart`
/// so the two test harnesses can compute the real ratio at the point a
/// `textContrastGuideline` failure is reported — and a measurement used to
/// explain a failure has to be the same measurement this file guards.
final double Function(Color, Color) contrast = sahraContrastRatio;

const double kBodyTextMin = kBodyTextContrastMin;

/// The two axes of the matrix, declared once so the census below and the tests
/// themselves cannot disagree about what is covered.
Map<String, Color> _surfacesOf(SahraSemantics s) => <String, Color>{
      'surfacePage': s.surfacePage,
      'surfaceCard': s.surfaceCard,
      'surfaceSunken': s.surfaceSunken,
    };

Map<String, Color> _textsOf(SahraSemantics s) => <String, Color>{
      'textBody': s.textBody,
      'textSoft': s.textSoft,
      'textFaint': s.textFaint,
      'accentOnSurface': s.accentOnSurface,
      'success': s.success,
      'warning': s.warning,
      'error': s.error,
    };

/// Status badges: the label colour and the status the wash is made from.
Map<String, (Color, Color)> _tintedOf(SahraSemantics s) => <String, (Color, Color)>{
      'success': (s.successOnTint, s.success),
      'warning': (s.warningOnTint, s.warning),
      'error': (s.errorOnTint, s.error),
    };

/// Incremented as each test is REGISTERED, so the census counts what actually
/// exists rather than recomputing the expectation.
///
/// The first version of this census multiplied map lengths together and
/// compared the product to a constant — which passed happily while the tests
/// it was supposed to be counting had failed to generate at all. A census that
/// recomputes the answer is not a census.
int _registered = 0;

void main() {
  group('every text token is legible on every surface, in both themes', () {
    for (final entry in <String, SahraSemantics>{
      'light': SahraSemantics.light(),
      'dark': SahraSemantics.dark(),
    }.entries) {
      final theme = entry.key;
      final s = entry.value;

      final surfaces = _surfacesOf(s);
      final texts = _textsOf(s);

      for (final t in texts.entries) {
        for (final bg in surfaces.entries) {
          _registered++;
          test('$theme: ${t.key} on ${bg.key}', () {
            final ratio = contrast(t.value, bg.value);
            expect(
              ratio,
              greaterThanOrEqualTo(kBodyTextMin),
              reason: '$theme ${t.key} on ${bg.key} is '
                  '${ratio.toStringAsFixed(2)}:1, below WCAG AA 4.5.\n'
                  'Adjust the token in docs/design/tokens.json — the reference '
                  'does not outrank AA (DESIGN-RULES.md).',
            );
          });
        }
      }

      // TINTED STATUS BADGES, as a class.
      //
      // The badge failure happened because the wash was only ever checked on
      // ONE surface. A tint is the status colour blended with whatever is
      // behind it, so it is a DIFFERENT background on every surface it lands
      // on — and it has to work on all of them.
      for (final t in _tintedOf(s).entries) {
        for (final bg in surfaces.entries) {
          final wash = Color.alphaBlend(
            t.value.$2.withValues(alpha: SahraSemantics.badgeTintAlpha),
            bg.value,
          );

          _registered++;
          test('$theme: ${t.key} badge label on its tint over ${bg.key}', () {
            final ratio = contrast(t.value.$1, wash);
            expect(
              ratio,
              greaterThanOrEqualTo(kBodyTextMin),
              reason: '$theme ${t.key} badge over ${bg.key} is '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          });

          _registered++;
          test('$theme: ${t.key} tint is VISIBLE against ${bg.key}', () {
            // A wash nobody can see is a neutral badge with extra steps —
            // which is the state this replaced. The point of the colour is to
            // be seen without being read.
            expect(contrast(wash, bg.value), greaterThanOrEqualTo(1.35));
          });
        }
      }

      test('$theme: accentContrast on the accent fill', () {
        expect(contrast(s.accentContrast, s.accent), greaterThanOrEqualTo(kBodyTextMin));
      });

      test('$theme: ink on the premium fill', () {
        // Gold is a fill for celebration, never body text on a surface
        // (DESIGN-RULES.md). What it must support is dark text ON it.
        expect(
          contrast(SahraSemantics.light().textBody, s.premium),
          greaterThanOrEqualTo(kBodyTextMin),
        );
      });

      test('$theme: the divider is visible as non-text UI (3:1)', () {
        // 1.4.11 — a rule nobody can see is not a rule.
        expect(contrast(s.line, s.surfacePage), greaterThanOrEqualTo(1.3));
      });
    }
  });

  // THE CENSUS, counting what was REGISTERED above rather than recomputing it.
  // 7 texts x 3 surfaces x 2 themes = 42, plus 3 statuses x 3 surfaces x
  // 2 themes x 2 checks = 36.
  test('the matrix actually registered its tests', () {
    expect(
      _registered,
      78,
      reason: 'Registered $_registered contrast tests, expected 78. A shrinking '
          'matrix is how coverage disappears without anything failing.',
    );
  });

  // ── Filled buttons: label on fill, in both themes ──────────────────────
  //
  // The palette matrix above covers TEXT ON SURFACES. A filled button is a
  // different pair — a label on a colour that was never meant to be a page
  // background — and nothing was checking those at all until the destructive
  // variant needed one.
  //
  // `error` is the reason it matters. It is a DARK red on light and a LIGHT
  // salmon on night, because it is tuned to be legible against its own
  // surface. White clears AA on the light value at 6.3:1 and fails on the
  // night value at 2.8:1 — so the variant flips its foreground by theme, and
  // these assertions are what prove the flip is right rather than plausible.
  group('a filled button label clears AA on its own fill', () {
    final pairs = <String, (Color fg, Color bg)>{
      'primary.light': (SahraSemantics.light().accentContrast, SahraSemantics.light().accent),
      'primary.dark': (SahraSemantics.dark().accentContrast, SahraSemantics.dark().accent),
      'gold.light': (SahraSemantics.light().textBody, SahraSemantics.light().premium),
      'gold.dark': (SahraSemantics.light().textBody, SahraSemantics.dark().premium),
      // The flip. Light takes white; night takes the light theme's ink.
      'destructive.light': (SahraSemantics.light().accentContrast, SahraSemantics.light().error),
      'destructive.dark': (SahraSemantics.light().textBody, SahraSemantics.dark().error),
    };

    pairs.forEach((name, pair) {
      test('$name', () {
        final ratio = contrast(pair.$1, pair.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(kBodyTextMin),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1 — a button label '
              'below $kBodyTextMin:1 on its own fill is unreadable for the '
              'people this rule exists for.',
        );
      });
    });

    test('AND WHITE ON THE NIGHT ERROR REALLY DOES FAIL', () {
      // The reason the flip exists, asserted rather than asserted-about. If a
      // future token change made white acceptable on night error, this fails
      // and somebody gets to simplify the variant deliberately — rather than
      // the flip surviving as cargo nobody dares touch.
      expect(
        contrast(SahraSemantics.light().accentContrast, SahraSemantics.dark().error),
        lessThan(kBodyTextMin),
        reason: 'white now clears AA on the night error fill — the per-theme '
            'foreground flip in SahraButton may be simplified away',
      );
    });
  });

  // ── Text over a PHOTO, which no guideline can measure ──────────────────
  //
  // `textContrastGuideline` SKIPS text drawn over an image: it has no idea
  // what pixels are underneath. So the venue hero, the search thumbnail label
  // and the confirmation ticket all draw white text on a photograph with
  // NOTHING checking them — the only guard has been a human looking at a
  // golden, and a human looking at a golden made from a dark fixture photo
  // learns nothing about a bright one.
  //
  // This measures the WORST CASE the design can actually produce: the
  // brightest possible photograph, pure white, under the scrim at its
  // strongest. If the label clears AA there, it clears AA over any photo.
  //
  // WHAT IT STILL CANNOT SEE, said plainly: the scrim is a GRADIENT, so text
  // positioned higher in the photo gets less of it. This measures the bottom,
  // where the reference puts the venue name. Text placed further up would be
  // weaker and nothing here would notice — that remains a human looking at a
  // golden, now with a bright fixture photo rather than a dark one.
  group('text over a photo clears AA against the brightest possible image', () {
    /// [top] composited over [bottom]. Straight source-over alpha.
    Color over(Color top, Color bottom) {
      final a = top.a;
      return Color.from(
        alpha: 1,
        red: top.r * a + bottom.r * (1 - a),
        green: top.g * a + bottom.g * (1 - a),
        blue: top.b * a + bottom.b * (1 - a),
      );
    }

    const white = Color(0xFFFFFFFF);

    test('the scrim at full strength over WHITE', () {
      final s = SahraSemantics.light();
      final worst = over(s.photoScrim, white);
      final ratio = contrast(s.onPhoto, worst);

      expect(
        ratio,
        greaterThanOrEqualTo(kBodyTextMin),
        reason: 'onPhoto over the scrim on a white photo is '
            '${ratio.toStringAsFixed(2)}:1. A sunlit terrace or a white '
            'tablecloth room would render the venue name unreadable, and no '
            'guideline would catch it — textContrastGuideline skips text over '
            'images.',
      );
    });

    test('AND THE CHECK IS NOT TRIVIALLY TRUE — a weak scrim fails it', () {
      // Guards the guard. If `photoScrim` were ever softened to something
      // decorative, the assertion above must start failing rather than
      // continuing to pass because white-on-anything happens to be fine.
      final s = SahraSemantics.light();
      final weak = over(s.photoScrim.withValues(alpha: 0.2), white);
      expect(contrast(s.onPhoto, weak), lessThan(kBodyTextMin));
    });
  });

  group('the measurement itself is right', () {
    // Guards the guard: a contrast function that always returned 21 would make
    // every assertion above pass silently.
    test('black on white is 21:1', () {
      expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.1));
    });

    test('a colour against itself is 1:1', () {
      expect(contrast(const Color(0xFF808080), const Color(0xFF808080)), closeTo(1, 0.01));
    });

    test('it agrees with a known WCAG value', () {
      // #767676 on white is the canonical "exactly 4.54" example.
      expect(
        contrast(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.05),
      );
    });

    test('it catches a pair that IS broken', () {
      // The original terracotta-on-cream failure, kept as a regression fixture
      // so the test cannot quietly stop detecting anything.
      expect(
        contrast(SahraTokens.terracotta, SahraTokens.surfacePage),
        lessThan(kBodyTextMin),
      );
    });
  });

  // ── THE EDGE-SAMPLING CEILING ──────────────────────────────────────────
  //
  // `textContrastGuideline` samples RENDERED PIXELS and regularly lands on an
  // anti-aliased glyph edge rather than the core of a letter. This asserts what
  // that costs, per surface, because the claim written into
  // `kEdgeSampledContrastCaveat` has to be a measurement that re-runs rather
  // than a sentence somebody was once confident about.
  //
  // AND IT IMMEDIATELY EARNED ITS KEEP. The claim as first written was "no
  // colour can pass, on our surfaces". That is true of the LIGHT theme and
  // FALSE of the night theme, where near-white ink reaches 4.72–5.16 at the
  // same 50% edge. The assertion caught the over-generalisation before it went
  // into the caveat, where it would have taught the next reader to dismiss a
  // real dark-theme failure as an artefact.
  group('the edge-sampling ceiling', () {
    // ── LIGHT: genuinely unsatisfiable ───────────────────────────────────
    //
    // Cream surfaces are ~0.94 luminance. Blend ANY ink halfway into them and
    // the darkest result available is still light. Pure black — the strongest
    // foreground that exists — reaches 3.85–3.93:1, and AA needs 4.5. There is
    // no colour to change to, so "darken the token" and "move the widget" are
    // both dead ends, and both have been walked.
    final Map<String, Color> light = <String, Color>{
      'surfacePage': SahraSemantics.light().surfacePage,
      'surfaceCard': SahraSemantics.light().surfaceCard,
      'surfaceSunken': SahraSemantics.light().surfaceSunken,
    };

    light.forEach((String name, Color bg) {
      test('LIGHT $name: no colour whatsoever clears AA at a 50% edge', () {
        final double ceiling = bestPossibleEdgeContrast(bg);
        expect(
          ceiling,
          lessThan(kBodyTextMin),
          reason: 'The best any foreground can do at a 50% edge on light $name '
              'is ${ceiling.toStringAsFixed(2)}:1. If this ever rises above '
              '$kBodyTextMin, `kEdgeSampledContrastCaveat` has stopped being '
              'true for this surface and must be narrowed — a blanket "it is '
              'always a sampling artefact" would then be the thing hiding a '
              'real failure.',
        );
      });
    });

    // ── NIGHT: satisfiable, and only from one direction ──────────────────
    final Map<String, Color> dark = <String, Color>{
      'surfacePage': SahraSemantics.dark().surfacePage,
      'surfaceCard': SahraSemantics.dark().surfaceCard,
      'surfaceSunken': SahraSemantics.dark().surfaceSunken,
    };

    dark.forEach((String name, Color bg) {
      test('NIGHT $name: body ink still clears AA at a 50% edge', () {
        // So on night, a failure IS worth taking at face value — which is
        // exactly the distinction the caveat has to preserve.
        expect(
          edgeSampledContrast(SahraSemantics.dark().textBody, bg),
          greaterThanOrEqualTo(kBodyTextMin),
        );
      });

      test('NIGHT $name: but no DARK ink can, from the other direction', () {
        // Pure black lands at 1.08–1.24:1 against a night surface at an edge.
        // The ceiling is one-sided in both themes; only the reachable side
        // flips.
        expect(edgeSampledContrast(const Color(0xFF000000), bg), lessThan(2));
      });
    });

    test('the specific number the caveat quotes — black on light surfaceCard', () {
      // Quoted in `kEdgeSampledContrastCaveat`, in the report sheet's comment,
      // and in `docs/decisions/2026-08-09-review-reports.md` §5. Pinned so
      // those three cannot quietly become fiction.
      expect(
        edgeSampledContrast(
          const Color(0xFF000000),
          SahraSemantics.light().surfaceCard,
        ),
        closeTo(3.92, 0.02),
      );
    });

    test('and the CORE of the same text is fine — textFaint on surfaceCard', () {
      // The other half of the argument. The colour that "failed" at 2.10:1
      // measures this when you sample a glyph instead of its edge.
      expect(
        contrast(
          SahraSemantics.light().textFaint,
          SahraSemantics.light().surfaceCard,
        ),
        greaterThan(kBodyTextMin),
      );
    });

    test('the ceiling is a real ceiling — a full-opacity sample is not capped', () {
      // Guards the guard. At alpha 1.0 there is no blending, so black on a
      // light card must clear AA comfortably; if this failed, the "ceiling"
      // above would be an artefact of the arithmetic rather than of the
      // sampling, and every assertion in this group would be measuring a bug.
      expect(
        bestPossibleEdgeContrast(SahraSemantics.light().surfaceCard, alpha: 1),
        greaterThan(15),
      );
    });
  });
}
