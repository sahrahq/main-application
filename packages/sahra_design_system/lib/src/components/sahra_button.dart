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
    this.variant = SahraButtonVariant.primary,
    this.size = SahraButtonSize.md,
    this.pill = false,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  /// Shown, and announced unless [semanticLabel] overrides it.
  final String label;

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
          onTapDown: widget._enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: widget._enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: widget._enabled ? () => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            // DESIGN-RULES.md: "press scale .98; no bounces."
            scale: _pressed ? SahraRules.pressScale : 1.0,
            duration: SahraRules.motionFast,
            curve: SahraRules.motionCurve,
            child: Material(
              color: palette.background,
              shape: RoundedRectangleBorder(
                borderRadius: SahraRadius.allOf(
                  widget.pill ? SahraRadius.pill : SahraRadius.md,
                ),
                side: palette.border == null
                    ? BorderSide.none
                    : BorderSide(color: palette.border!, width: 1.5),
              ),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: SahraRadius.allOf(
                  widget.pill ? SahraRadius.pill : SahraRadius.md,
                ),
                child: ConstrainedBox(
                  // Every button clears 44pt whatever its padding says
                  // (DESIGN-RULES.md / CLAUDE.md design rule 4).
                  constraints: const BoxConstraints(
                    minHeight: SahraRules.minTouchTarget,
                    minWidth: SahraRules.minTouchTarget,
                  ),
                  child: Padding(
                    padding: SahraSpace.symmetric(
                      horizontal: metrics.horizontal,
                      vertical: metrics.vertical,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          IconTheme.merge(
                            data: IconThemeData(color: palette.foreground, size: metrics.fontSize),
                            child: widget.icon!,
                          ),
                          SizedBox(width: SahraSpace.s2),
                        ],
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

/// PROVISIONAL — see the open question in the setup-day report.
///
/// `Button.jsx` specifies `sm: 8px 14px / 13px`, `md: 12px 20px / 14px`,
/// `lg: 15px 26px / 15px`. `md` lands exactly on the token scale
/// (space-3 / space-5 / text-body-m). `sm` and `lg` do not: 14, 15 and 26 are
/// off a 4px scale and 15px is not in the type ramp.
///
/// DESIGN-RULES.md says the reference wins when it disagrees with prose, which
/// would mean adding tokens — the precedent set by `leading-arabic`. But
/// inventing three tokens to satisfy one component's padding is how a scale
/// stops being a scale, so this uses the nearest on-scale neighbours and the
/// question is raised rather than settled unilaterally. Goldens for this
/// component are cheap to regenerate once it is decided.
_Metrics _metrics(SahraButtonSize size) => switch (size) {
      SahraButtonSize.sm => const _Metrics(SahraSpace.s3, SahraSpace.s2, SahraTypeScale.bodyS),
      SahraButtonSize.md => const _Metrics(SahraSpace.s5, SahraSpace.s3, SahraTypeScale.bodyM),
      SahraButtonSize.lg => const _Metrics(SahraSpace.s6, SahraSpace.s4, SahraTypeScale.bodyL),
    };
