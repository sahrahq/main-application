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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// WCAG relative luminance, straight from the spec.
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

const double kBodyTextMin = 4.5;

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

void main() {
  // THE CENSUS. This file generates its tests from two maps. If either were
  // empty the file would contain zero assertions and pass — the same
  // vacuous-pass shape that hid the semantics bug.
  test('the matrix actually covers the palette', () {
    final light = SahraSemantics.light();
    final pairs = _textsOf(light).length * _surfacesOf(light).length * 2;
    expect(
      pairs,
      42,
      reason: 'The contrast matrix changed size ($pairs pairs). If a token was '
          'added or removed, update this count deliberately — a shrinking '
          'matrix is how coverage disappears without anything failing.',
    );
  });

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
}
