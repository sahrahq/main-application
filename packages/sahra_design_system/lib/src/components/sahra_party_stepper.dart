import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import '../theme/sahra_typography.dart';
import 'sahra_icon.dart';

/// `docs/design/ui_kits/app/BookingFlowScreen.jsx` — the party-size stepper:
/// two 40px circular buttons either side of a 32px count, clamped 1–12.
///
/// Discovered while building the booking path. `SahraBookingWidget` has an
/// internal stepper, but it is private, inline, and tied to that component's
/// own copy contract — this is the standalone control the booking SCREEN uses.
///
/// The reference draws the buttons at 40px. They are laid out at
/// [SahraRules.minTouchTarget] (48) because `androidTapTargetGuideline`
/// requires 48dp and DESIGN-RULES.md states a MINIMUM, so exceeding it is not
/// a deviation. The painted circle stays 40 — the lesson from the Button size
/// bug, where constraining the painted box instead of the hit area made all
/// three sizes render identically.
class SahraPartyStepper extends StatelessWidget {
  const SahraPartyStepper({
    required this.value,
    required this.onChanged,
    required this.unitLabel,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 1,
    this.max = 12,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// "guests" / "أفراد", already pluralised by the caller — a design-system
  /// component owns no copy.
  final String unitLabel;

  /// Screen-reader labels. An icon-only button with no label is invisible to
  /// TalkBack, and SAHRA is icon-heavy by design.
  final String decreaseLabel;
  final String increaseLabel;

  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _StepButton(
          // 'minus' is not in the SAHRA icon set — see the cosmetic flag from
          // wave 3. 'x' is a CLOSE glyph and reads as "remove", not "one
          // fewer", so the Material fallback is used here deliberately.
          icon: 'minus',
          label: decreaseLabel,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: SahraSpace.s6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              // Latin digits in both locales (DESIGN-RULES.md). `numeric`
              // pins the Latin face and tabular figures so the count does not
              // shift width between 9 and 10.
              '$value',
              style: SahraTypography.numeric(
                text.headlineLarge!.copyWith(color: s.textBody),
              ),
            ),
            Text(unitLabel, style: text.bodySmall?.copyWith(color: s.textSoft)),
          ],
        ),
        SizedBox(width: SahraSpace.s6),
        _StepButton(
          icon: 'plus',
          label: increaseLabel,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onPressed});

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  /// The reference's painted diameter. The HIT area is larger — see the class
  /// note on SahraPartyStepper.
  static const double _diameter = 40;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final enabled = onPressed != null;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SahraRules.minTouchTarget,
              minWidth: SahraRules.minTouchTarget,
            ),
            child: Center(
              child: Container(
                width: _diameter,
                height: _diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.surfaceCard,
                  border: Border.all(color: s.line),
                ),
                child: Center(
                  child: SahraIcon(
                    icon,
                    size: SahraTypeScale.bodyL,
                    // Disabled is a real state, not a missing one: at the
                    // minimum the button still occupies its space, so it has
                    // to LOOK unavailable rather than silently ignore a tap.
                    color: enabled ? s.textBody : s.textFaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
