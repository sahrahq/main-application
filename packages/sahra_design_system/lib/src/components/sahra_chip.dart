import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';

/// `docs/design/components/core/Chip.d.ts` — `{active, icon, children, onClick}`.
///
/// The filter control on Discover and Search. Selected is a terracotta fill;
/// unselected is a hairline outline, never a grey fill — a row of chips has to
/// read as "one of these is on" at a glance, on a phone, in Cairo sunlight.
class SahraChip extends StatefulWidget {
  const SahraChip({
    required this.label,
    required this.onPressed,
    this.active = false,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final Widget? icon;
  final String? semanticLabel;

  @override
  State<SahraChip> createState() => _SahraChipState();
}

class _SahraChipState extends State<SahraChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final on = widget.active;
    final foreground = on ? s.accentContrast : s.textSoft;

    return MergeSemantics(
      child: Semantics(
        button: true,
        // Announced as "selected". Colour alone communicates nothing to
        // someone who cannot see it.
        selected: on,
        enabled: widget.onPressed != null,
        label: widget.semanticLabel ?? widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SahraRules.minTouchTarget,
              minWidth: SahraRules.minTouchTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedScale(
                scale: _pressed ? SahraRules.pressScale : 1.0,
                duration: SahraRules.motionFast,
                curve: SahraRules.motionCurve,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: on ? s.accent : null,
                    borderRadius: SahraRadius.allOf(SahraRadius.pill),
                    border: Border.all(color: on ? s.accent : s.line),
                  ),
                  child: Padding(
                    padding: SahraSpace.symmetric(
                      horizontal: SahraSpace.s4,
                      vertical: SahraSpace.s2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          IconTheme.merge(
                            data: IconThemeData(
                              color: foreground,
                              size: SahraTypeScale.bodyS,
                            ),
                            child: widget.icon!,
                          ),
                          SizedBox(width: SahraSpace.s1),
                        ],
                        ExcludeSemantics(
                          child: Text(
                            widget.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
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
}
