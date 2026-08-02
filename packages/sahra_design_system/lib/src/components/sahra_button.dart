import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';

/// `docs/design/components/core/Button.d.ts`:
/// `{variant, size, pill, disabled, icon, children, onClick}`.
enum SahraButtonVariant { primary, secondary, ghost, gold }

enum SahraButtonSize { sm, md, lg }

/// The primary action control.
///
/// Copy is a PROP, never a literal inside the widget. A design-system component
/// owns no strings — it is handed them by a screen that read them from ARB.
/// That is why the no-hardcoded-strings scanner (§1) targets app widget trees
/// and not this package.
///
/// SEMANTICS: [label] doubles as the accessible name. An icon-only button
/// therefore still announces its purpose, because there is no way to construct
/// one without a label — `labeledTapTargetGuideline` cannot be failed by
/// accident here, only by passing an empty string.
class SahraButton extends StatefulWidget {
  const SahraButton({
    required this.label,
    required this.onPressed,
    this.iconOnly = false,
    this.variant = SahraButtonVariant.primary,
    this.size = SahraButtonSize.md,
    this.pill = false,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  /// Shown, and announced unless [semanticLabel] overrides it.
  ///
  /// When [iconOnly] is set the label is NOT drawn but is still the accessible
  /// name — it is required rather than optional precisely so an icon-only
  /// control cannot ship unannounced.
  final String label;

  /// Draw the icon alone, in a circle.
  ///
  /// Added for wave 3: BookingWidget's party stepper, RestaurantCard's save
  /// heart and DiningTrail all need a small circular icon control, and no
  /// component among the sixteen provides one. Rather than inline a one-off in
  /// each composite — which is how three subtly different buttons appear in a
  /// design system — it lives here. See the wave-3 report.
  final bool iconOnly;

  /// Null disables the button. Matches Flutter's convention rather than a
  /// separate `disabled` flag, so a disabled button cannot also carry a live
  /// callback.
  final VoidCallback? onPressed;

  final SahraButtonVariant variant;
  final SahraButtonSize size;

  /// Full-radius, per the reference's `pill` prop.
  final bool pill;

  final Widget? icon;

  /// For when the visible label is not the whole story ("Save" → "Save Zooba
  /// to your list").
  final String? semanticLabel;

  bool get _enabled => onPressed != null;

  @override
  State<SahraButton> createState() => _SahraButtonState();
}

class _SahraButtonState extends State<SahraButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final palette = _palette(s);
    final metrics = _metrics(widget.size);
    final circle = widget.iconOnly;

    // NOT `excludeSemantics: true`. That strips the InkWell's tap ACTION along
    // with the child's label, which has two consequences, both found by
    // deliberately breaking this on day one:
    //   1. A screen reader announces the button and cannot activate it.
    //   2. Every tap-target and label guideline SKIPS a node with no tap
    //      action — so they passed vacuously and proved nothing.
    // The label is de-duplicated by excluding the Text instead (below), and
    // `a11yMatrix` now asserts the tap action survives.
    // MergeSemantics matters as much as the Semantics node itself: without it
    // the LABEL sits on this node and the TAP ACTION sits on the InkWell's
    // child node, and `labeledTapTargetGuideline` — which looks for a label on
    // the node that is tappable — fails. Merging puts both on one node, which
    // is also what a screen reader needs to announce and activate one control.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget._enabled,
        label: widget.semanticLabel ?? widget.label,
        child: GestureDetector(
          // Opaque so the whole 48dp box below is tappable, including the
          // transparent margin around a small button.
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: widget._enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: widget._enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: widget._enabled ? () => setState(() => _pressed = false) : null,
          child: ConstrainedBox(
            // The TOUCH TARGET is 48dp — not the button.
            //
            // Constraining the painted box instead made all three sizes render
            // at the same height, so `sm` was not small and the size scale did
            // nothing. Caught by looking at the goldens, which is the entire
            // reason they exist. The hit area grows; the visual stays the size
            // the reference asks for.
            constraints: const BoxConstraints(
              minHeight: SahraRules.minTouchTarget,
              minWidth: SahraRules.minTouchTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedScale(
                // DESIGN-RULES.md: "press scale .98; no bounces."
                scale: _pressed ? SahraRules.pressScale : 1.0,
                duration: SahraRules.motionFast,
                curve: SahraRules.motionCurve,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: SahraRadius.allOf(
                      widget.pill || circle ? SahraRadius.pill : SahraRadius.md,
                    ),
                    border: palette.border == null
                        ? null
                        : Border.all(color: palette.border!, width: 1.5),
                  ),
                  child: Padding(
                    padding: circle
                        ? SahraSpace.all(metrics.vertical)
                        : SahraSpace.symmetric(
                            horizontal: metrics.horizontal,
                            vertical: metrics.vertical,
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          IconTheme.merge(
                            data: IconThemeData(
                              color: palette.foreground,
                              size: circle ? metrics.fontSize * 1.4 : metrics.fontSize,
                            ),
                            child: widget.icon!,
                          ),
                          if (!circle) SizedBox(width: SahraSpace.s2),
                        ],
                        if (!circle)
                          Flexible(
                            // Excluded so the visible label does not announce
                            // twice; the Semantics above owns the accessible name.
                            child: ExcludeSemantics(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: palette.foreground,
                                      fontSize: metrics.fontSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Palette _palette(SahraSemantics s) {
    if (!widget._enabled) {
      // Reference: disabled is `--border` on `--ink-faint`, in every variant.
      return _Palette(background: s.line, foreground: s.textFaint);
    }
    return switch (widget.variant) {
      SahraButtonVariant.primary => _Palette(
          background: s.accent,
          foreground: s.accentContrast,
        ),
      // Text uses accentOnSurface, not accent: terracotta as TEXT fails WCAG
      // AA on both surfaces (4.45 light / 3.86 dark). The 1.5px border stays
      // accent — non-text UI only needs 3:1 and it clears that comfortably.
      SahraButtonVariant.secondary => _Palette(
          background: Colors.transparent,
          foreground: s.accentOnSurface,
          border: s.accent,
        ),
      SahraButtonVariant.ghost => _Palette(
          background: Colors.transparent,
          foreground: s.textBody,
        ),
      // Gold is celebration only, never a second primary (DESIGN-RULES.md).
      // Its foreground is `ink` in both themes — gold is light enough that
      // night-text on it would fail contrast.
      SahraButtonVariant.gold => _Palette(
          background: s.premium,
          foreground: SahraSemantics.light().textBody,
        ),
    };
  }
}

class _Palette {
  const _Palette({required this.background, required this.foreground, this.border});
  final Color background;
  final Color foreground;
  final Color? border;
}

class _Metrics {
  const _Metrics(this.horizontal, this.vertical, this.fontSize);
  final double horizontal;
  final double vertical;
  final double fontSize;
}

/// `Button.jsx` specifies `sm: 8px 14px / 13px`, `md: 12px 20px / 14px`,
/// `lg: 15px 26px / 15px`. `md` lands exactly on the token scale; `sm` and
/// `lg` do not — 14, 15 and 26 are off the 4px scale and 15px is not in the
/// type ramp.
///
/// DECIDED 2026-08-02: round to the nearest on-scale neighbour. Those are
/// incidental CSS values with no intent behind them, unlike `leading-arabic`
/// where 1.7 was a deliberate typographic choice about how Arabic reads.
/// Adding off-scale tokens to preserve a rounding error would break the 4px
/// system permanently, and a scale with exceptions is not a scale.
///
/// Checked by eye against the goldens afterwards: the three sizes read as
/// distinct and correctly proportioned.
_Metrics _metrics(SahraButtonSize size) => switch (size) {
      SahraButtonSize.sm => const _Metrics(SahraSpace.s3, SahraSpace.s2, SahraTypeScale.bodyS),
      SahraButtonSize.md => const _Metrics(SahraSpace.s5, SahraSpace.s3, SahraTypeScale.bodyM),
      SahraButtonSize.lg => const _Metrics(SahraSpace.s6, SahraSpace.s4, SahraTypeScale.bodyL),
    };
