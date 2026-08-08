import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import '../../restaurants/presentation/cuisine_copy.dart';
import '../../restaurants/presentation/venue_meta.dart';
import '../domain/saved_repository.dart';
import 'saved_notifier.dart';

/// `docs/design/ui_kits/app/SavedScreen.jsx`.
///
/// A two-column grid of `RestaurantCard` at `imageHeight: 110`, under a
/// display-size title — that is the reference and that is what this draws.
///
/// ── WHAT THE REFERENCE HAS AND THIS DOES NOT ─────────────────────────────
///
/// **The chip row.** `SavedScreen.jsx` draws `All · Date night · Rooftops ·
/// Want to try` — user-created LISTS, not filters over what is saved. There is
/// no schema for a named list, no endpoint, and no way to put a venue in one;
/// C-2.7 says "favorites/saved lists" and only the first half is built.
///
/// Four chips where three do nothing is worse than none: a diner taps
/// "Rooftops", sees the same grid, and learns the controls on this screen are
/// decorative. Reported as a gap rather than drawn dead — the same call the
/// search screen made about its Collections chips.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentSessionProvider) != null;

    return Scaffold(
      appBar: SahraAppBar(
        title: Text(l10n.savedTitle),
        leading: IconButton(
          icon: const SahraIcon('arrow-back'),
          tooltip: l10n.venueBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SahraPageWidth(
        child: signedIn ? const _Grid() : const _SignedOut(),
      ),
    );
  }
}

/// Reachable, because a session can end while this screen is open.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: SahraSpace.all(SahraSpace.s5),
      child: SahraEmptyState(
        icon: 'heart',
        title: l10n.savedSignedOutTitle,
        message: l10n.savedSignedOutMessage,
        actionLabel: l10n.bookingsSignedOutAction,
        onAction: () => const SignInRoute().go(context),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SahraAsyncView<List<SavedVenue>>(
      value: ref.watch(savedVenuesProvider),
      onRetry: () => ref.invalidate(savedVenuesProvider),
      isEmpty: (list) => list.isEmpty,
      loading: (_) => GridView.count(
        padding: SahraSpace.all(SahraSpace.s5),
        crossAxisCount: 2,
        crossAxisSpacing: SahraSpace.s3,
        mainAxisSpacing: SahraSpace.s3,
        childAspectRatio: 0.72,
        children: const <Widget>[
          SahraSkeleton(height: 200, radius: SahraRadius.lg),
          SahraSkeleton(height: 200, radius: SahraRadius.lg),
          SahraSkeleton(height: 200, radius: SahraRadius.lg),
          SahraSkeleton(height: 200, radius: SahraRadius.lg),
        ],
      ),
      // THE EMPTY STATE SENDS THEM SOMEWHERE. A saved list with nothing in it
      // is the normal state of a new account, and an empty screen with no way
      // out of it is a dead end on a tab the diner chose deliberately.
      empty: (context) => SingleChildScrollView(
        padding: SahraSpace.all(SahraSpace.s5),
        child: SahraEmptyState(
          icon: 'heart',
          title: l10n.savedEmptyTitle,
          message: l10n.savedEmptyMessage,
          actionLabel: l10n.savedEmptyAction,
          onAction: () => const SearchRoute().go(context),
        ),
      ),
      // THE CELL SIZE IS COMPUTED, NOT GUESSED.
      //
      // A fixed `childAspectRatio` was the first version and it overflowed at
      // 200% text — caught by the viewport matrix, and silent in a release
      // build, which is the whole reason that matrix exists. The image is a
      // FIXED 110pt (the reference's number) and the text block below it
      // scales, so the height is one and not the other; a single ratio cannot
      // describe both.
      //
      // Past 1.5x it also drops to ONE column. Two 170pt cards of
      // triple-height text are unreadable columns of two words each, and the
      // people running large text are exactly the people that hurts.
      content: (context, list) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = scale >= 1.5 ? 1 : 2;
          const gap = SahraSpace.s3;
          const pad = SahraSpace.s5;

          final cellWidth = (constraints.maxWidth - pad * 2 - gap * (columns - 1)) / columns;
          // 110 for the photo, and a text block that grows with the scaler.
          final cellHeight = 110 + 150 * scale;

          return GridView.builder(
            padding: SahraSpace.all(pad),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: cellWidth / cellHeight,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final saved = list[i];
              final venue = saved.venue;

              return SahraRestaurantCard(
                name: venue.name,
                rating: venue.rating,
                reviews: venue.ratingCount,
                cuisine: venue.cuisines.isEmpty
                    ? ''
                    : cuisineLabel(venue.cuisines.first, l10n) ?? venue.cuisines.first,
                price: venue.priceBand == null ? '' : priceSymbols(venue.priceBand!),
                neighbourhood: venue.neighborhood,
                // The reference's 110pt image slot, said out loud so the provider
                // fetches the 160 rendition rather than the hero.
                image: venueImageProvider(context, ref, venue.cover, slotWidth: 180),
                imageHeight: 110,
                width: double.infinity,
                saved: true,
                saveLabel: l10n.savedRemoveLabel(venue.name),
                onSave: () => toggleSavedAndReport(context, ref, restaurantId: venue.id),
                onTap: () => VenueRoute(venue.slug).go(context),
              );
            },
          );
        },
      ),
    );
  }
}
