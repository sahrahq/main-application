import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../reservations/presentation/reservation_copy.dart';
import '../domain/review.dart';
import 'menu_notifier.dart';
import 'report_review_sheet.dart';

/// C-4.4 / C-2.6 — reviews on the venue page, and the sheet behind them.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NO REFERENCE, AGAIN
/// ─────────────────────────────────────────────────────────────────────────
///
/// `RatingStars.d.ts` is `{rating, reviews, size, showValue}` — a display of a
/// number that already exists on the hero. There is no review LIST anywhere in
/// the design package, and no composer.
///
/// So this is plain on purpose: the summary is the rating the hero already
/// shows, a histogram built from `Container`s, and a stack of cards using the
/// same `surfaceCard`, radius and hairline as every other card in the app.
/// Nothing here introduces a shape a later reference would have to undo.
///
/// ── THE ONE LINE OF COPY THAT IS NOT DECORATION ──────────────────────────
///
/// "Every review here is from a diner who booked a table and came." That is
/// the product (C-4.4: "verified-only reviews are a trust wedge vs. Google
/// Maps noise"), and a diner cannot tell it apart from any other review list
/// unless it is said. It is enforced by `reviews.reservation_id` being NOT
/// NULL — the sentence is true, which is the only reason it is on screen.

/// The block on the venue page: summary, up to three reviews, a way to all of
/// them. Absent entirely while loading or on failure — see `MenuSection` for
/// why a section inside a loaded page does not own the screen's four states.
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({required this.idOrSlug, super.key});

  final String idOrSlug;

  static const int previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final page = ref.watch(venueReviewsProvider(idOrSlug)).valueOrNull;
    if (page == null) return const SizedBox.shrink();

    // A VENUE WITH NO REVIEWS STILL GETS THE SECTION, unlike the menu.
    //
    // The difference is what the absence means. No menu is a gap in our data
    // and saying so helps nobody. No reviews is a FACT ABOUT THE VENUE that a
    // diner is entitled to — and the empty state is where the verified-only
    // rule gets explained, which is exactly when somebody is wondering why a
    // place they know is busy has none.
    final reviews = page.results.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.venueReviewsTitle,
                style: text.titleLarge?.copyWith(color: s.textBody),
              ),
            ),
            if (page.results.isNotEmpty)
              _TextAction(
                label: l10n.venueReviewsAll,
                onPressed: () => showReviewsSheet(context, idOrSlug),
              ),
          ],
        ),
        const SizedBox(height: SahraSpace.s3),
        if (page.summary.ratingCount == 0)
          SahraEmptyState(
            icon: 'star',
            title: l10n.reviewsEmptyTitle,
            message: l10n.reviewsEmptyMessage,
          )
        else ...<Widget>[
          _Summary(summary: page.summary),
          const SizedBox(height: SahraSpace.s4),
          for (final review in reviews) ...<Widget>[
            ReviewCard(review: review),
            const SizedBox(height: SahraSpace.s3),
          ],
          Text(
            l10n.reviewsVerifiedNote,
            style: text.bodySmall?.copyWith(color: s.textFaint),
          ),
        ],
      ],
    );
  }
}

Future<void> showReviewsSheet(BuildContext context, String idOrSlug) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReviewsSheet(idOrSlug: idOrSlug),
  );
}

class _ReviewsSheet extends ConsumerWidget {
  const _ReviewsSheet({required this.idOrSlug});

  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final page = ref.watch(reviewFeedProvider(idOrSlug)).valueOrNull ?? const ReviewPage.empty();

    return SahraPageWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: SahraSpace.s3),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: s.line,
              borderRadius: BorderRadius.circular(SahraRadius.pill),
            ),
          ),
          Flexible(
            child: ListView(
              padding: SahraSpace.all(SahraSpace.s5),
              shrinkWrap: true,
              children: <Widget>[
                Text(
                  l10n.reviewsSheetTitle,
                  style: text.headlineSmall?.copyWith(color: s.textBody),
                ),
                const SizedBox(height: SahraSpace.s4),
                _Summary(summary: page.summary),
                const SizedBox(height: SahraSpace.s4),
                for (final review in page.results) ...<Widget>[
                  ReviewCard(review: review, reportable: true),
                  const SizedBox(height: SahraSpace.s3),
                ],
                if (page.nextCursor != null)
                  SahraButton(
                    label: l10n.reviewsShowMore,
                    variant: SahraButtonVariant.ghost,
                    onPressed: () => ref.read(reviewFeedProvider(idOrSlug).notifier).loadMore(),
                  ),
                const SizedBox(height: SahraSpace.s3),
                Text(
                  l10n.reviewsVerifiedNote,
                  style: text.bodySmall?.copyWith(color: s.textFaint),
                ),
                const SizedBox(height: SahraSpace.s5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The figure, the count, and five bars.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              summary.rating.toStringAsFixed(1),
              style: SahraTypography.numeric(
                text.displaySmall!.copyWith(color: s.textBody),
              ),
            ),
            SahraRatingStars(
              rating: summary.rating,
              showValue: false,
              semanticLabel: l10n.reviewStarsLabel(summary.rating.toStringAsFixed(1)),
            ),
            const SizedBox(height: SahraSpace.s1),
            Text(
              l10n.reviewsCount(summary.ratingCount),
              style: text.bodySmall?.copyWith(color: s.textFaint),
            ),
          ],
        ),
        const SizedBox(width: SahraSpace.s5),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Five down to one. Descending, because that is the order the
              // number above it is read in.
              for (var stars = 5; stars >= 1; stars--)
                _BreakdownBar(
                  stars: stars,
                  share: summary.share(stars),
                  count: summary.breakdown[stars] ?? 0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.stars,
    required this.share,
    required this.count,
  });

  final int stars;
  final double share;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Semantics(
      // A bar has no accessible content at all — it is two boxes. Without this
      // the whole histogram is silent, and a screen-reader user gets the
      // average with no distribution behind it.
      label: l10n.reviewBreakdownLabel(stars, count),
      child: ExcludeSemantics(
        child: Padding(
          padding: SahraSpace.inset(bottom: SahraSpace.s1),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 12,
                child: Text(
                  '$stars',
                  style: SahraTypography.numeric(
                    text.labelSmall!.copyWith(color: s.textFaint),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: SahraSpace.s2),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SahraRadius.pill),
                  child: Stack(
                    children: <Widget>[
                      Container(height: 6, color: s.line),
                      // FractionallySizedBox rather than a computed width: the
                      // bar has to be right at every text scale and on every
                      // viewport in the matrix, and a width in logical pixels
                      // would be right on exactly one.
                      FractionallySizedBox(
                        widthFactor: share.clamp(0.0, 1.0),
                        child: Container(height: 6, color: s.premium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One review.
///
/// The REPORT control lives here rather than on the venue page's preview,
/// deliberately. A diner scanning three reviews under a booking button is
/// deciding where to eat; a diner who has opened the full list and read one is
/// the one who might have a reason to flag it. Putting it on every card in
/// every context would add a third affordance to a card whose job is to be read.
class ReviewCard extends ConsumerStatefulWidget {
  const ReviewCard({required this.review, this.reportable = false, super.key});

  final Review review;

  /// True inside the all-reviews sheet, false in the venue page's preview.
  final bool reportable;

  @override
  ConsumerState<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<ReviewCard> {
  /// Set once this diner has reported this review in this session.
  ///
  /// The API answers 200 rather than an error on a repeat, so nothing forces
  /// this — it exists so the control stops inviting a second press it will do
  /// nothing with.
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    final Review review = widget.review;
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: SahraSpace.all(SahraSpace.s4),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: BorderRadius.circular(SahraRadius.lg),
        border: Border.all(color: s.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SahraAvatar(name: review.author, size: 32),
              const SizedBox(width: SahraSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // USER CONTENT, so it carries its own direction.
                    // "Nour H." rendered ".Nour H" in the Arabic golden — the
                    // full stop took the paragraph's direction and landed on
                    // the wrong end of somebody's name.
                    Text(
                      review.author,
                      textDirection: contentDirection(review.author),
                      style: text.bodyMedium?.copyWith(
                        color: s.textBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dayAndMonth(review.createdAt.toIso8601String().substring(0, 10), context),
                      style: text.labelSmall?.copyWith(color: s.textFaint),
                    ),
                  ],
                ),
              ),
              // `showValue: true`, and it is not decoration.
              //
              // `SahraRatingStars` draws ONE star and a figure — it is the
              // meta line from a venue card, not a five-glyph row. With the
              // figure hidden, a three-star review and a five-star review
              // render as exactly the same single star, which is worse than
              // showing no rating at all: the card looks like it is telling
              // you something and it is not.
              //
              // Found by looking at the reviews golden, where three cards
              // rated 5, 4 and 5 were indistinguishable.
              SahraRatingStars(
                rating: review.rating.toDouble(),
                semanticLabel: l10n.reviewStarsLabel('${review.rating}'),
              ),
            ],
          ),
          if (review.body != null) ...<Widget>[
            const SizedBox(height: SahraSpace.s3),
            // Same again, and it matters more here: a whole paragraph written
            // by a diner in the other language, whose closing full stop would
            // otherwise sit at its start.
            Text(
              review.body!,
              textDirection: contentDirection(review.body!),
              style: text.bodyMedium?.copyWith(color: s.textSoft),
            ),
          ],
          if (review.hasSubRatings) ...<Widget>[
            const SizedBox(height: SahraSpace.s3),
            Wrap(
              spacing: SahraSpace.s3,
              runSpacing: SahraSpace.s1,
              children: <Widget>[
                if (review.foodRating != null)
                  _SubRating(label: l10n.reviewFood, value: review.foodRating!),
                if (review.serviceRating != null)
                  _SubRating(label: l10n.reviewService, value: review.serviceRating!),
                if (review.ambienceRating != null)
                  _SubRating(label: l10n.reviewAmbience, value: review.ambienceRating!),
              ],
            ),
          ],
          if (widget.reportable) ...<Widget>[
            const SizedBox(height: SahraSpace.s2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _reported
                  // Says it landed, and stops offering a press that would do
                  // nothing. The API would answer 200 either way.
                  ? Padding(
                      padding: SahraSpace.symmetric(vertical: SahraSpace.s2),
                      child: Text(
                        l10n.reviewReportAlready,
                        style: text.labelSmall?.copyWith(color: s.textFaint),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final bool sent = await showReportReviewSheet(
                          context,
                          reviewId: review.id,
                        );
                        if (!sent || !context.mounted) return;
                        setState(() => _reported = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.reviewReportSent)),
                        );
                      },
                      // `Center(widthFactor: 1)`, NOT a bare `Align`.
                      //
                      // An `Align` with no width constraint expands to fill,
                      // so the tap target became the full card width and the
                      // word rendered CENTRED under the review — reading as a
                      // heading rather than an action. Found in the golden.
                      // `widthFactor: 1` shrink-wraps to the text while the
                      // `SizedBox` keeps the full 44pt height.
                      child: SizedBox(
                        height: SahraRules.minTouchTarget,
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            l10n.reviewReport,
                            // NOT the accent. A report control that draws the
                            // eye competes with the review it sits under, and
                            // it is not the thing a diner came to do.
                            style: text.labelSmall?.copyWith(
                              color: s.textFaint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
          if (review.ownerReply != null) ...<Widget>[
            const SizedBox(height: SahraSpace.s3),
            Container(
              padding: SahraSpace.all(SahraSpace.s3),
              decoration: BoxDecoration(
                color: s.surfaceSunken,
                borderRadius: BorderRadius.circular(SahraRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.reviewOwnerReply,
                    style: text.labelSmall?.copyWith(
                      color: s.accentOnSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SahraSpace.s1),
                  Text(
                    review.ownerReply!,
                    textDirection: contentDirection(review.ownerReply!),
                    style: text.bodySmall?.copyWith(color: s.textSoft),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubRating extends StatelessWidget {
  const _SubRating({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: text.labelSmall?.copyWith(color: s.textFaint)),
        const SizedBox(width: SahraSpace.s1),
        Text(
          '$value',
          style: SahraTypography.numeric(
            text.labelSmall!.copyWith(
              color: s.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
        child: Align(
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              color: s.accentOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
