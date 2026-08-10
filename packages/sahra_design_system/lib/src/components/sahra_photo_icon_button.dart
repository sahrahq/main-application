import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';

/// `docs/design/ui_kits/app/VenueDetailScreen.jsx` — the local `IconBtn`:
/// a 38px circle of `rgba(20,12,8,.5)` with a blur, floating over the hero
/// photo. Back, share and save all use it.
///
/// Discovered while building the booking path. Three uses on one screen, and
/// the confirmation screen wants the same affordance.
///
/// It exists as a component because of what sits UNDER it. An icon over a
/// photograph is the one contrast case `textContrastGuideline` cannot evaluate
/// — it skips text drawn over an image — so the translucent well is the entire
/// mechanism keeping the glyph readable against a bright sky or a white
/// tablecloth. Inlining it means each screen decides that separately, and one
/// of them eventually decides wrong.
class SahraPhotoIconButton extends StatelessWidget {
  const SahraPhotoIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final String icon;

  /// Required, not optional. This button is icon-only in every use, so without
  /// it a screen reader announces nothing at all.
  final String semanticLabel;

  final VoidCallback? onPressed;

  /// Saved/favourited — the gold state from the reference.
  final bool active;

  static const double _diameter = 38;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: active,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            // 48, not the reference's 38: the painted circle stays 38 and the
            // hit box grows around it.
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
                  color: s.photoControlWell,
                ),
                child: Center(
                  child: SahraIcon(
                    icon,
                    size: SahraTypeScale.bodyL,
                    color: active ? s.premium : s.onPhoto,
                    filled: active,
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
