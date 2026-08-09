import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';

/// A row of five tappable stars.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THERE IS NO REFERENCE FOR THIS ONE
/// ─────────────────────────────────────────────────────────────────────────
///
/// `RatingStars.d.ts` is `{rating, reviews, size, showValue}` — display only,
/// no `onChange`. None of the fourteen screen references contains a review
/// composer, so this is invented rather than matched, and it is deliberately
/// the most boring thing that could work: the same star glyph
/// `SahraRatingStars` already draws, at a bigger size, in a row, each one a
/// button.
///
/// The product owner's instruction where a reference is missing was "keep it
/// plain and boring; a menu that looks like the rest of the app is worth more
/// than a menu that looks designed". Same applies here. No animation, no
/// half-stars, no drag-across gesture — a drag would make the control
/// impossible to operate with a screen reader and would need its own hit
/// testing to be no better than five buttons.
///
/// ── WHY EACH STAR IS 44 WIDE ─────────────────────────────────────────────
///
/// Five 44dp targets is 220dp, which fits the narrowest phone in the matrix
/// (320) with room either side. The GLYPH is 30; the target around it is the
/// full minimum. Pagination dots on the onboarding screen failed exactly this
/// check at 24×48 and it is the same mistake to make twice.
///
/// ── AND WHY THERE IS NO ZERO ─────────────────────────────────────────────
///
/// [value] of 0 means "not rated yet" and draws five empty stars, but there is
/// no gesture that returns to it. Tapping the first star sets 1. A diner who
/// opened the sheet by accident closes it; a control that can be un-set
/// invites the question of what an un-set rating means on a form whose submit
/// button requires one.
class SahraStarInput extends StatelessWidget {
  const SahraStarInput({
    required this.value,
    required this.onChanged,
    required this.semanticLabelFor,
    this.size = 30,
    super.key,
  });

  /// 0 means unrated. 1–5 otherwise.
  final int value;

  final ValueChanged<int> onChanged;

  /// Localised "n of 5 stars", per star. A row of five buttons all announcing
  /// "star" tells a screen-reader user nothing about which one they are on.
  final String Function(int star) semanticLabelFor;

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var star = 1; star <= 5; star++)
          Semantics(
            button: true,
            // `selected`, not `checked`. A screen reader then says "selected"
            // for the stars up to and including the current rating, which is
            // what the row means visually.
            selected: star <= value,
            label: semanticLabelFor(star),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(star),
              child: SizedBox(
                width: SahraRules.minTouchTarget,
                height: SahraRules.minTouchTarget,
                child: Center(
                  child: SahraIcon(
                    // ONE GLYPH, two states. `SahraIcon.filled` is exactly this
                    // distinction, and its own doc says an outlined star "reads
                    // as not rated" — which here is precisely what an unchosen
                    // star means. A separate outline icon would be a second
                    // drawing of the same shape to keep in step.
                    'star',
                    filled: star <= value,
                    size: size,
                    color: star <= value ? s.premium : s.line,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
