import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import '../theme/sahra_typography.dart';
import 'sahra_icon.dart';

/// `docs/design/components/venue/RatingStars.d.ts` —
/// `{rating, reviews, size, showValue}`.
///
/// The meta line that appears on every venue card: `★ 4.8 (312)`.
///
/// THE STAR IS DRAWN, NOT TYPED. The reference uses the character `★`
/// (U+2605), and Poppins does not contain it — it renders as an empty box.
/// Found by looking at a golden of the contrast-audit page, where the tofu was
/// plainly visible; no assertion in the suite would have caught it, because a
/// missing glyph still has a width and still "renders".
///
/// NUMERALS stay Latin in both locales (DESIGN-RULES.md), so a Cairo diner
/// scanning a list sees 4.8 next to every other 4.8 in the market rather than
/// ٤٫٨ next to them.
class SahraRatingStars extends StatelessWidget {
  const SahraRatingStars({
    required this.rating,
    this.reviews,
    this.size = 13,
    this.showValue = true,
    this.semanticLabel,
    super.key,
  });

  final double rating;
  final int? reviews;
  final double size;
  final bool showValue;

  /// Screen readers get a sentence, not a star and two numbers. Supply the
  /// localised form; the default is a fallback for tests and previews.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    // A VENUE NOBODY HAS RATED HAS NO RATING — it does not have a rating of
    // zero.
    //
    // With `reviews: 0` this drew `★ 0.0 (0)`, which reads as "rated zero out
    // of five" on the hero of a restaurant that simply has not opened long
    // enough for anyone to review it. Found by looking at the
    // `Venue/menu-pdf-only` golden, whose fixture is deliberately unrated.
    //
    // Same class as the review card that drew one star and no figure: a
    // control that looks like it is telling you something, and is not. Absent
    // is the honest state, and the reviews section below says so in words.
    //
    // `reviews == null` still draws — that is a caller showing a rating with no
    // count beside it, which is a different thing from a count of zero.
    if (reviews == 0) return const SizedBox.shrink();

    final numeric = SahraTypography.numeric(
      TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: s.accentOnSurface),
    );

    return Semantics(
      label: semanticLabel ??
          'Rated ${rating.toStringAsFixed(1)}'
              '${reviews == null ? '' : ' from $reviews reviews'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraIcon(
            'star',
            size: size * 1.2,
            // FILLED, and terracotta per the reference — an outlined star
            // reads as an unearned rating, and gold is reserved for
            // celebration (DESIGN-RULES.md), not for every card in a list.
            filled: true,
            color: s.accentOnSurface,
          ),
          if (showValue) ...<Widget>[
            SizedBox(width: SahraSpace.s1),
            Text(rating.toStringAsFixed(1), style: numeric),
          ],
          if (reviews != null) ...<Widget>[
            SizedBox(width: SahraSpace.s1),
            Text(
              '($reviews)',
              style: SahraTypography.numeric(
                TextStyle(fontSize: size, color: s.textFaint),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
