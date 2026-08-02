import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';

class SahraTab {
  const SahraTab({required this.id, required this.label, required this.icon});

  final String id;

  /// Already localised.
  final String label;
  final String icon;
}

/// `docs/design/components/navigation/TabBar.d.ts` —
/// `{items, active, onChange}`.
///
/// The bottom navigation. Selected is terracotta with a dot beneath.
///
/// THE DOT IS NOT DECORATION. Selection is otherwise carried by colour alone,
/// which WCAG 1.4.1 forbids as the sole channel — a red-green colour-blind
/// diner would see five identical tabs. The dot is the second channel, and
/// `Semantics(selected:)` is the third for anyone not looking at all.
class SahraTabBar extends StatelessWidget {
  const SahraTabBar({
    required this.items,
    required this.activeId,
    required this.onChanged,
    super.key,
  });

  final List<SahraTab> items;
  final String activeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Container(
      decoration: BoxDecoration(
        color: s.surfacePage,
        border: Border(top: BorderSide(color: s.line)),
      ),
      padding: SahraSpace.inset(top: SahraSpace.s2, bottom: SahraSpace.s3),
      child: Row(
        children: <Widget>[
          for (final item in items)
            Expanded(
              child: _Tab(
                item: item,
                selected: item.id == activeId,
                onTap: () => onChanged(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final SahraTab item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final colour = selected ? s.accentOnSurface : s.textFaint;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SahraIcon(item.icon, size: SahraSpace.s5, color: colour),
                SizedBox(height: SahraSpace.s1),
                ExcludeSemantics(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colour,
                          letterSpacing: 0,
                        ),
                  ),
                ),
                SizedBox(height: SahraSpace.s1),
                // The second channel. Colour alone is not enough (1.4.1).
                Container(
                  width: SahraSpace.s1,
                  height: SahraSpace.s1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? s.accentOnSurface : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
