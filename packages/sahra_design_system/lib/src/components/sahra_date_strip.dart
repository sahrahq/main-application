import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import '../theme/sahra_typography.dart';

/// One day in [SahraDateStrip]. The caller formats both lines — a
/// design-system component owns no copy and no date formatting.
class SahraDay {
  const SahraDay({
    required this.id,
    required this.label,
    required this.number,
    required this.semanticLabel,
    this.enabled = true,
  });

  /// Whatever the caller keys on, typically `YYYY-MM-DD`.
  final String id;

  /// "Tonight" / "Thu" / "الليلة" / "الخميس".
  final String label;

  /// "21" / "22". Latin digits in both locales (DESIGN-RULES.md).
  final String number;

  /// The whole date said properly, for a screen reader — "Thursday 22 August",
  /// not "Thu" then "22".
  final String semanticLabel;

  /// A closed day. Rendered visibly unavailable rather than omitted: a gap in
  /// a date strip reads as a bug, and "they're shut on Mondays" is information.
  final bool enabled;
}

/// `docs/design/ui_kits/app/BookingFlowScreen.jsx` — the horizontal day
/// picker: 64px-wide tiles, a small weekday over a large date, terracotta fill
/// when selected.
///
/// Discovered while building the booking path.
class SahraDateStrip extends StatelessWidget {
  const SahraDateStrip({
    required this.days,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<SahraDay> days;
  final String selectedId;
  final ValueChanged<String> onSelected;

  static const double _tileWidth = 64;
  static const double _tileHeight = SahraRules.minTouchTarget + SahraSpace.s4;

  @override
  Widget build(BuildContext context) {
    // A horizontal ListView needs a bounded height, and a CONSTANT one
    // overflows the moment a user turns text size up — which Egyptian users on
    // mid-range Androids do more than average (ENGINEERING-STANDARDS §4).
    // Found by `textScaleMatrix` at 2.0x, in all four cells.
    //
    // Both axes scale, not just height: at 2x, "الخميس" does not fit in 64
    // logical pixels either, and a clipped weekday is the same defect one
    // dimension over.
    final scale = MediaQuery.textScalerOf(context);

    return SizedBox(
      height: scale.scale(_tileHeight),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => SizedBox(width: SahraSpace.s2),
        itemBuilder: (context, i) => _DayTile(
          day: days[i],
          width: scale.scale(_tileWidth),
          selected: days[i].id == selectedId,
          onPressed: days[i].enabled ? () => onSelected(days[i].id) : null,
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.width,
    required this.selected,
    required this.onPressed,
  });

  final SahraDay day;
  final double width;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final text = Theme.of(context).textTheme;

    final foreground = switch ((selected, day.enabled)) {
      (true, _) => s.accentContrast,
      (false, true) => s.textSoft,
      (false, false) => s.textFaint,
    };

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: day.enabled,
        label: day.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: width,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? s.accent : null,
              borderRadius: SahraRadius.allOf(SahraRadius.md),
              border: Border.all(color: selected ? s.accent : s.line),
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    day.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: foreground),
                  ),
                  Text(
                    day.number,
                    style: SahraTypography.numeric(
                      text.labelLarge!.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
