import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_bidi.dart';
import '../theme/sahra_semantics.dart';
import '../theme/sahra_typography.dart';
import 'sahra_badge.dart';
import 'sahra_icon.dart';
import 'sahra_photo.dart';
import 'sahra_rating_stars.dart';

/// `docs/design/ui_kits/app/SearchScreen.jsx` — the horizontal result row: a
/// 76px thumbnail, the venue name, the meta line, a next-available badge and a
/// save heart.
///
/// Discovered while building the booking path. It is NOT `SahraRestaurantCard`
/// with a different width — that one is a 244–280px vertical card built for a
/// horizontal carousel on Discover. This is its horizontal sibling, built for
/// a vertical list where the thumbnail is small and the meta line is the point.
///
/// The meta line is the DESIGN-RULES.md pattern verbatim:
/// `★ 4.8 (312) · Levantine · $$$`.
class SahraResultRow extends StatelessWidget {
  const SahraResultRow({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.meta,
    required this.semanticLabel,
    this.image,
    this.availability,
    this.distance,
    this.saved = false,
    this.onSave,
    this.saveLabel,
    this.onTap,
    super.key,
  });

  /// Pre-formatted, e.g. `1.4 km` / «1.4 كم».
  ///
  /// A STRING, not a number, and the component does no arithmetic on it. The
  /// figure comes from the server, the unit comes from the ARB, and the join
  /// happens once at the call site — so a row cannot render a distance in one
  /// unit while the filter above it says another.
  ///
  /// Null is the ordinary case: the API only computes a distance when the
  /// diner shared a position.
  final String? distance;

  final String name;
  final double rating;
  final int reviews;

  /// Everything after the stars — `Levantine · $$$`, already composed and
  /// localised. A design-system component owns no copy and no separators
  /// policy beyond the one the reference draws.
  final String meta;

  /// One sentence for a screen reader, in place of a name, two numbers, a
  /// badge and a heart read out in layout order.
  final String semanticLabel;

  final ImageProvider? image;

  /// The `Next: 9:00 PM` teaser. Null when availability was not asked for —
  /// which is different from "nothing free", and looks different too.
  final String? availability;

  final bool saved;
  final VoidCallback? onSave;
  final String? saveLabel;
  final VoidCallback? onTap;

  static const double _thumb = 76;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: s.surfaceCard,
            border: Border.all(color: s.line),
            borderRadius: SahraRadius.allOf(SahraRadius.lg),
          ),
          child: Padding(
            padding: SahraSpace.all(SahraSpace.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: _thumb,
                  child: SahraPhoto(
                    height: _thumb,
                    image: image,
                    radius: SahraRadius.md,
                    // The row is small; a centred image glyph at this size is
                    // noise rather than a cue.
                    cue: false,
                  ),
                ),
                SizedBox(width: SahraSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.headlineSmall?.copyWith(color: s.textBody),
                              ),
                            ),
                          ),
                          if (onSave != null)
                            _SaveHeart(
                              saved: saved,
                              label: saveLabel ?? name,
                              onPressed: onSave!,
                            ),
                        ],
                      ),
                      SizedBox(height: SahraSpace.s1),
                      ExcludeSemantics(
                        // A Row, not a Wrap.
                        //
                        // As a Wrap the meta dropped to a second line on a
                        // narrow card and the leading separator went with it,
                        // leaving a "·" hanging at the start of the line —
                        // mirrored to the end of it in Arabic. The reference
                        // draws one line; a long cuisine now ellipsises
                        // instead of rearranging the punctuation.
                        child: Row(
                          children: <Widget>[
                            SahraRatingStars(rating: rating, reviews: reviews, size: 12),
                            Expanded(
                              child: Text(
                                // The leading separator goes with the stars —
                                // `SahraRatingStars` draws nothing when nobody
                                // has rated the venue, and a dangling "·" at
                                // the start of the line was the exact defect
                                // that produced on the venue hero.
                                reviews == 0 ? meta : ' · $meta',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: s.textSoft),
                              ),
                            ),
                            // DISTANCE LAST, and it does not shrink.
                            //
                            // It is the shortest thing on the line and the one
                            // the diner asked for by name when they turned the
                            // filter on — so the cuisine ellipsises and this
                            // does not. `ltrRun` because "1.4 km" is a figure
                            // and a Latin-or-Arabic unit, and in an Arabic
                            // paragraph the two swap sides.
                            if (distance != null) ...<Widget>[
                              SizedBox(width: SahraSpace.s2),
                              Text(
                                ltrRun(distance!),
                                style: SahraTypography.numeric(
                                  text.bodySmall!.copyWith(
                                    color: s.textFaint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (availability != null) ...<Widget>[
                        SizedBox(height: SahraSpace.s2),
                        ExcludeSemantics(
                          child: SahraBadge(
                            label: availability!,
                            variant: SahraBadgeVariant.featured,
                          ),
                        ),
                      ],
                    ],
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

class _SaveHeart extends StatelessWidget {
  const _SaveHeart({required this.saved, required this.label, required this.onPressed});

  final bool saved;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: saved,
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
              child: SahraIcon(
                'heart',
                size: SahraTypeScale.bodyM,
                // Saved is the accent, not the faint outline — a heart that
                // barely changes colour is a toggle nobody trusts they hit.
                color: saved ? s.accentOnSurface : s.textFaint,
                filled: saved,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
