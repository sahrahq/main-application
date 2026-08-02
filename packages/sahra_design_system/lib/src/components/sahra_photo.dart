import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';
import 'sahra_mashrabiya.dart';

/// `docs/design/ui_kits/app/Photo.jsx` — `{src, height, radius, label,
/// gradientOverlay, cue}`.
///
/// Discovered while building the booking path: the venue hero, the search
/// result thumbnail, the booking mini-card and the confirmation ticket all
/// draw the same thing, and it is not one of the sixteen.
///
/// THE PLACEHOLDER IS THE POINT. `Photo.jsx` renders a warm dark gradient with
/// a mashrabiya lattice and a centred image cue when there is no `src`. That is
/// not a fallback bolted on — it is drawn in the reference, which means the
/// designer already answered "what does a venue with no photo look like". SAHRA
/// has no image table yet (R-2.2), so today it is the state EVERY venue is in,
/// and the screens look deliberate rather than broken because of it.
///
/// The gradient overlay exists so white text can sit on a photo at all. Note
/// that `textContrastGuideline` cannot evaluate text over an image and skips
/// it — the only guard on that is a human looking at the golden.
class SahraPhoto extends StatelessWidget {
  const SahraPhoto({
    required this.height,
    this.image,
    this.radius = 0,
    this.label,
    this.gradientOverlay = false,
    this.cue = true,
    this.child,
    super.key,
  });

  final double height;

  /// Null is the ordinary case today, not an error. See the class note.
  final ImageProvider? image;

  final double radius;

  /// A small uppercase marker in the leading-top corner.
  final String? label;

  /// Darkens the bottom 62% so overlaid text is readable.
  final bool gradientOverlay;

  /// The centred image glyph on the placeholder. Off when something else is
  /// already drawn on top.
  final bool cue;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return ClipRRect(
      borderRadius: SahraRadius.allOf(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: image == null
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[s.photoPlaceholderTop, s.photoPlaceholderBottom],
                      )
                    : null,
                image: image == null
                    ? null
                    : DecorationImage(image: image!, fit: BoxFit.cover),
              ),
            ),
            if (image == null)
              SahraMashrabiya(color: s.photoLattice, tile: 40, opacity: 1),
            if (image == null && cue)
              Center(
                child: SahraIcon(
                  'image',
                  size: _cueSize(height),
                  color: s.photoCue,
                ),
              ),
            if (gradientOverlay)
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[s.photoScrimClear, s.photoScrim],
                      ),
                    ),
                  ),
                ),
              ),
            if (label != null)
              PositionedDirectional(
                start: SahraSpace.s3,
                top: SahraSpace.s3,
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: s.onPhoto),
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// `Photo.jsx`: `Math.max(22, Math.min(40, height * 0.28))`.
double _cueSize(double height) => (height * 0.28).clamp(22.0, 40.0);
