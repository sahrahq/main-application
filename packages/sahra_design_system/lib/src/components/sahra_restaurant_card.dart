import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_badge.dart';
import 'sahra_button.dart';
import 'sahra_icon.dart';
import 'sahra_mashrabiya.dart';
import 'sahra_rating_stars.dart';

/// `docs/design/components/venue/RestaurantCard.d.ts`.
///
/// The densest thing in the system and the one that appears most: Discover,
/// Search and Saved are all lists of these. It composes [SahraBadge],
/// [SahraRatingStars], [SahraMashrabiya], [SahraIcon] and [SahraButton] —
/// which is the point of building the roots first.
///
/// THE WHOLE CARD IS ONE SEMANTIC NODE, with the save control as a second.
/// A screen reader user swiping a list of restaurants wants "Zooba, rated 4.8
/// from 312 reviews, Egyptian, Zamalek" as one stop, not eight.
class SahraRestaurantCard extends StatelessWidget {
  const SahraRestaurantCard({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.cuisine,
    this.price = r'$$$',
    this.neighbourhood,
    this.image,
    this.featured = false,
    this.featuredLabel,
    this.availability,
    this.saved = false,
    this.onSave,
    this.saveLabel,
    this.onTap,
    this.semanticLabel,
    this.width = 280,
    this.imageHeight = 160,
    super.key,
  });

  final String name;
  final double rating;
  final int reviews;

  /// Already localised — "Egyptian", "شامي".
  final String cuisine;
  final String price;
  final String? neighbourhood;
  final ImageProvider? image;

  final bool featured;

  /// Copy for the featured badge. Required in practice when [featured] is set;
  /// the badge is simply omitted without it rather than shipping English.
  final String? featuredLabel;

  /// "Tonight 7:30" — already formatted in the venue's local time.
  final String? availability;

  final bool saved;
  final VoidCallback? onSave;

  /// Accessible name for the save control — the only thing announcing it.
  final String? saveLabel;

  final VoidCallback? onTap;
  final String? semanticLabel;
  final double width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final theme = Theme.of(context);

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: s.surfaceCard,
            borderRadius: SahraRadius.allOf(SahraRadius.lg),
            border: Border.all(color: s.line),
            boxShadow: s.shadow(SahraElevation.e1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Hero(
                image: image,
                height: imageHeight,
                featured: featured,
                featuredLabel: featuredLabel,
                saved: saved,
                onSave: onSave,
                saveLabel: saveLabel,
              ),
              Padding(
                padding: SahraSpace.inset(
                  start: SahraSpace.s4,
                  end: SahraSpace.s4,
                  top: SahraSpace.s3,
                  bottom: SahraSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                    SizedBox(height: SahraSpace.s1),
                    // The meta line: ★ 4.8 (312) · Egyptian · $$$
                    Row(
                      children: <Widget>[
                        SahraRatingStars(rating: rating, reviews: reviews),
                        SizedBox(width: SahraSpace.s2),
                        Expanded(
                          child: Text(
                            <String?>[cuisine, neighbourhood, price]
                                .whereType<String>()
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: s.textFaint),
                          ),
                        ),
                      ],
                    ),
                    if (availability != null) ...<Widget>[
                      SizedBox(height: SahraSpace.s3),
                      SahraBadge(
                        label: availability!,
                        variant: SahraBadgeVariant.success,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.image,
    required this.height,
    required this.featured,
    required this.featuredLabel,
    required this.saved,
    required this.onSave,
    required this.saveLabel,
  });

  final ImageProvider? image;
  final double height;
  final bool featured;
  final String? featuredLabel;
  final bool saved;
  final VoidCallback? onSave;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The placeholder is the night ramp rather than an invented pair of
          // browns: the reference hardcodes #4A392C/#2C2018, which are close
          // to `night-overlay` and `night`, and a token that already exists
          // beats a hex that does not.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  SahraTokensBridge.nightOverlay,
                  SahraTokensBridge.night,
                ],
              ),
            ),
          ),
          if (image != null)
            Image(image: image!, fit: BoxFit.cover)
          else ...<Widget>[
            SahraMashrabiya(
              color: SahraTokensBridge.nightText.withValues(alpha: 0.09),
              tile: 38,
            ),
            Center(
              child: SahraIcon(
                'image',
                size: SahraSpace.s8,
                color: SahraTokensBridge.nightText.withValues(alpha: 0.16),
              ),
            ),
          ],
          // Scrim, so a badge or a heart stays legible over any photograph.
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: SahraSpace.s16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      SahraTokensBridge.night.withValues(alpha: 0),
                      SahraTokensBridge.night.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (featured && featuredLabel != null)
            PositionedDirectional(
              top: SahraSpace.s3,
              start: SahraSpace.s3,
              child: SahraBadge(
                label: featuredLabel!,
                variant: SahraBadgeVariant.featured,
              ),
            ),
          if (onSave != null && saveLabel != null)
            PositionedDirectional(
              top: SahraSpace.s2,
              end: SahraSpace.s2,
              child: SahraButton(
                iconOnly: true,
                size: SahraButtonSize.sm,
                variant: SahraButtonVariant.ghost,
                // Announced as its own control, separate from the card.
                label: saveLabel!,
                icon: SahraIcon(
                  'heart',
                  size: 17,
                  filled: saved,
                  color: saved ? s.premium : SahraTokensBridge.nightText,
                ),
                onPressed: onSave,
              ),
            ),
        ],
      ),
    );
  }
}

/// The hero sits on imagery, not on a themed surface, so its colours come from
/// the NIGHT ramp in both themes — a cream scrim over a photograph would be
/// invisible on light and wrong on dark.
class SahraTokensBridge {
  const SahraTokensBridge._();

  static Color get night => SahraSemantics.dark().surfacePage;
  static Color get nightOverlay => SahraSemantics.dark().surfaceSunken;
  static Color get nightText => SahraSemantics.dark().textBody;
}
