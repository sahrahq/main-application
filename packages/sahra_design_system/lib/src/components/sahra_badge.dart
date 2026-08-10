import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';

enum SahraBadgeVariant { featured, gold, success, warning, error, neutral }

/// `docs/design/components/core/Badge.d.ts` —
/// `{variant: featured|gold|success|warning|error|neutral}`.
///
/// A micro-label: 11px, uppercase, tracked out, pill. DESIGN-RULES.md permits
/// uppercase in exactly two places and this is one ("UPPERCASE only for
/// overlines/micro-labels").
///
/// SIZE: the reference says 11px. At 11 the glyph coverage is thin enough that
/// white-on-terracotta measures 2.17:1 to `textContrastGuideline` despite
/// computing to 4.76 arithmetically — the antialiased strokes are genuinely
/// what a reader sees. 12px (`text-caption`, already a token) renders solidly
/// and passes. AA outranks the reference (DESIGN-RULES.md), so 12 it is.
///
/// TRACKING: the reference uses `.08em`; the token set has one tracking value,
/// `tracking-overline: .14em`, defined for precisely this 11px uppercase
/// style. The token is used — same reasoning as the Button padding. An
/// incidental CSS value does not earn a token, and here an existing token
/// already describes this style.
///
/// The tinted variants are alpha overlays of the semantic colour rather than
/// separate hexes, so they follow the palette when it moves — which it did, on
/// 2026-08-02.
class SahraBadge extends StatelessWidget {
  const SahraBadge({
    required this.label,
    this.variant = SahraBadgeVariant.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final SahraBadgeVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final palette = _palette(s);

    return Container(
      padding: SahraSpace.symmetric(horizontal: SahraSpace.s3, vertical: SahraSpace.s1),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: SahraRadius.allOf(SahraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            IconTheme.merge(
              data: IconThemeData(color: palette.foreground, size: SahraTypeScale.overline),
              child: icon!,
            ),
            SizedBox(width: SahraSpace.s1),
          ],
          // FLEXIBLE, so a long label wraps instead of overflowing its pill.
          //
          // `mainAxisSize.min` sizes this Row to its content, which is right at
          // normal text sizes. At 200% it is not: "AWAITING CONFIRMATION" is
          // wider than the card it sits in, and the Row overflowed by 60px on
          // the bookings list. A badge is a micro-label, so two short lines is
          // the correct degradation — the alternative is an ellipsis that hides
          // which status this is, on the screen where the status is the point.
          //
          // Flexible binds only when the parent constrains the width, so at 1x
          // nothing about any existing badge changes.
          Flexible(
            child: Text(
              // Arabic has no case, so this is a no-op there — correct, not a
              // gap.
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: SahraTypeScale.caption,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  _BadgePalette _palette(SahraSemantics s) => switch (variant) {
        SahraBadgeVariant.featured => _BadgePalette(s.accent, s.accentContrast),
        // Gold carries ink in both themes — it is too light for night text.
        SahraBadgeVariant.gold => _BadgePalette(s.premium, SahraSemantics.light().textBody),
        // A status badge has to read at a glance WITHOUT being read: a host
        // scanning tonight's book needs confirmed and cancelled to differ by
        // colour, not by word. So the wash is real (28%, ~1.5:1 against the
        // surface) and the label gets its own on-tint value at 6:1 — the
        // surface-level status colours cannot survive their own tint.
        SahraBadgeVariant.success => _BadgePalette(s.tintFor(s.success), s.successOnTint),
        SahraBadgeVariant.warning => _BadgePalette(s.tintFor(s.warning), s.warningOnTint),
        SahraBadgeVariant.error => _BadgePalette(s.tintFor(s.error), s.errorOnTint),
        SahraBadgeVariant.neutral => _BadgePalette(s.surfaceSunken, s.textSoft),
      };
}

class _BadgePalette {
  const _BadgePalette(this.background, this.foreground);
  final Color background;
  final Color foreground;
}
