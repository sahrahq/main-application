import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_button.dart';
import 'sahra_icon.dart';
import 'sahra_mashrabiya.dart';

/// `docs/design/components/social/EmptyState.d.ts` —
/// `{icon, title, message, actionLabel, onAction}`.
///
/// The empty AND error state. DESIGN-RULES.md: "Every list screen implements
/// loading, empty, error. No screen ships without all three."
///
/// THE ACTION IS THE POINT. An empty state that only says "No results" is a
/// dead end, and a dead end is the thing `SahraAsyncView.onRetry` was made
/// non-nullable to prevent. Here it is a prop rather than a compile error
/// because a genuinely empty list ("you have not saved anything yet") has
/// nowhere to retry to — but an ERROR state without one is a bug, and
/// SahraAsyncView is what enforces that.
class SahraEmptyState extends StatelessWidget {
  const SahraEmptyState({
    required this.title,
    this.message,
    this.icon = 'spark',
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Already localised — this component owns no copy.
  final String title;
  final String? message;
  final String icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Semantics(
      // One announcement for the whole block: a screen reader user wants "no
      // saved restaurants yet, browse Discover", not a tour of the layout.
      container: true,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned.fill(
            child: SahraMashrabiya(
              color: s.textBody.withValues(alpha: 0.045),
              tile: 46,
              fade: true,
            ),
          ),
          Padding(
            padding: SahraSpace.symmetric(
              horizontal: SahraSpace.s6,
              vertical: SahraSpace.s10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: SahraSpace.s16 - SahraSpace.s2,
                  height: SahraSpace.s16 - SahraSpace.s2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.surfaceSunken,
                  ),
                  alignment: Alignment.center,
                  child: SahraIcon(icon, size: SahraSpace.s6, color: s.accentOnSurface),
                ),
                SizedBox(height: SahraSpace.s4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (message != null) ...<Widget>[
                  SizedBox(height: SahraSpace.s2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.textSoft),
                    ),
                  ),
                ],
                if (actionLabel != null) ...<Widget>[
                  SizedBox(height: SahraSpace.s4),
                  SahraButton(
                    label: actionLabel!,
                    size: SahraButtonSize.sm,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
