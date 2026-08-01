import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';

/// The palette change of 2026-08-02, shown as real text rather than swatches.
///
/// Swatches answer "what hue is this", which is not the question. The question
/// is "can a diner read this on the surface it actually sits on", so every row
/// renders the same sentence twice — the old value on the left, the new one on
/// the right — on its real background, at the size it ships at, with the
/// measured ratio printed underneath.
///
/// This page is a REVIEW ARTEFACT, not product UI. It is the only place in the
/// package that writes colour literals, because showing a withdrawn value is
/// the entire point; the exemptions below are deliberate and counted.
class ContrastAuditPage extends StatelessWidget {
  const ContrastAuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final dark = s.brightness == Brightness.dark;

    final rows = dark ? _darkRows(s) : _lightRows(s);

    return Scaffold(
      backgroundColor: s.surfacePage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                dark ? 'الوضع الليلي — قبل وبعد' : 'Contrast fixes — before and after',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: SahraSpace.s2),
              Text(
                'WCAG AA needs 4.5:1 for body text. Left is what the reference '
                'specified; right is what shipped.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.textSoft),
              ),
              SizedBox(height: SahraSpace.s6),
              for (final row in rows) ...<Widget>[
                _AuditRow(row: row),
                SizedBox(height: SahraSpace.s5),
              ],
              _MetaLineExample(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One token, both values, on one surface.
class _Row {
  const _Row({
    required this.token,
    required this.before,
    required this.after,
    required this.surface,
    required this.surfaceName,
    required this.sample,
    this.note,
  });

  final String token;
  final Color before;
  final Color after;
  final Color surface;
  final String surfaceName;
  final String sample;
  final String? note;
}

// design-exempt: this page exists to display WITHDRAWN colour values side by
// side with their replacements. They cannot come from a token — that is the
// point of showing them.
const _oldInkFaint = Color(0xFF8A8479);
// design-exempt: as above.
const _oldWarning = Color(0xFFC48A4B);
// design-exempt: as above.
const _oldSuccess = Color(0xFF4C7A4F);
// design-exempt: as above.
const _oldError = Color(0xFFB3412A);
// design-exempt: as above.
const _oldTerracotta = Color(0xFFC64A2B);

List<_Row> _lightRows(SahraSemantics s) => <_Row>[
      _Row(
        token: 'text-faint',
        before: _oldInkFaint,
        after: s.textFaint,
        surface: s.surfaceCard,
        surfaceName: 'surface-card',
        sample: 'Levantine · Zamalek · \$\$\$',
        note: 'The caption colour. Ships on every venue card.',
      ),
      _Row(
        token: 'warning',
        before: _oldWarning,
        after: s.warning,
        surface: s.surfacePage,
        surfaceName: 'surface-page',
        sample: 'Only 2 tables left tonight',
        note: 'Was gold-dark — the value DESIGN-RULES recommended as readable.',
      ),
      _Row(
        token: 'success',
        before: _oldSuccess,
        after: s.success,
        surface: s.surfaceSunken,
        surfaceName: 'surface-sunken',
        sample: 'Your table is confirmed',
      ),
      _Row(
        token: 'accent as text',
        before: _oldTerracotta,
        after: s.accentOnSurface,
        surface: s.surfacePage,
        surfaceName: 'surface-page',
        sample: 'See the menu',
        note: 'Unchanged as a FILL behind white — only as text.',
      ),
    ];

List<_Row> _darkRows(SahraSemantics s) => <_Row>[
      _Row(
        token: 'success',
        before: _oldSuccess,
        after: s.success,
        surface: s.surfaceCard,
        surfaceName: 'surface-card',
        sample: 'Your table is confirmed',
      ),
      _Row(
        token: 'error',
        before: _oldError,
        after: s.error,
        surface: s.surfaceCard,
        surfaceName: 'surface-card',
        sample: 'That time has just been taken',
      ),
      _Row(
        token: 'accent as text',
        before: _oldTerracotta,
        after: s.accentOnSurface,
        surface: s.surfacePage,
        surfaceName: 'surface-page',
        sample: 'See the menu',
      ),
      _Row(
        token: 'text-faint',
        before: _oldInkFaint,
        after: s.textFaint,
        surface: s.surfaceCard,
        surfaceName: 'surface-card',
        sample: 'Levantine · Zamalek · \$\$\$',
        note: 'Already passed on dark; shown for comparison.',
      ),
    ];

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.row});
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${row.token}  on  ${row.surfaceName}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.textSoft),
        ),
        if (row.note != null) ...<Widget>[
          SizedBox(height: SahraSpace.s1),
          Text(
            row.note!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.textSoft),
          ),
        ],
        SizedBox(height: SahraSpace.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _Sample(
                label: 'before',
                colour: row.before,
                surface: row.surface,
                sample: row.sample,
              ),
            ),
            SizedBox(width: SahraSpace.s3),
            Expanded(
              child: _Sample(
                label: 'after',
                colour: row.after,
                surface: row.surface,
                sample: row.sample,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({
    required this.label,
    required this.colour,
    required this.surface,
    required this.sample,
  });

  final String label;
  final Color colour;
  final Color surface;
  final String sample;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final ratio = _contrast(colour, surface);
    final passes = ratio >= 4.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: SahraSpace.all(SahraSpace.s4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: SahraRadius.allOf(SahraRadius.md),
            border: Border.all(color: s.line),
          ),
          // Body size, because that is the size the failure happens at.
          child: Text(sample, style: TextStyle(color: colour, fontSize: SahraTypeScale.bodyM)),
        ),
        SizedBox(height: SahraSpace.s1),
        Text(
          '$label — ${ratio.toStringAsFixed(2)}:1  ${passes ? 'passes AA' : 'FAILS AA'}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: passes ? s.success : s.error,
              ),
        ),
      ],
    );
  }
}

/// The venue-card meta line, the one that ships everywhere.
class _MetaLineExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    return Container(
      padding: SahraSpace.all(SahraSpace.s4),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: SahraRadius.allOf(SahraRadius.lg),
        border: Border.all(color: s.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Zooba', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: SahraSpace.s1),
          // The real thing, in context: this line is why text-faint mattered.
          Row(
            children: <Widget>[
              Text('★ 4.8 ', style: TextStyle(color: s.premium, fontSize: SahraTypeScale.bodyS)),
              Text(
                '(312) · Egyptian · \$\$',
                style: TextStyle(color: s.textFaint, fontSize: SahraTypeScale.bodyS),
              ),
            ],
          ),
          SizedBox(height: SahraSpace.s3),
          Row(
            children: <Widget>[
              Text('★ 4.8 ', style: TextStyle(color: s.premium, fontSize: SahraTypeScale.bodyS)),
              Text(
                '(312) · Egyptian · \$\$',
                style: TextStyle(color: _oldInkFaint, fontSize: SahraTypeScale.bodyS),
              ),
              SizedBox(width: SahraSpace.s2),
              Text(
                '← old',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _contrast(Color fg, Color bg) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final a = lum(fg);
  final b = lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
