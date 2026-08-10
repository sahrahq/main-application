import 'package:flutter/material.dart';
import '../../reservations/presentation/reservation_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../domain/restaurant_repository.dart';
import 'search_notifier.dart';
import 'venue_meta.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import 'filter_sheet.dart';

/// `docs/design/ui_kits/app/SearchScreen.jsx`.
///
/// WHAT IS NOT HERE, and why:
///
///   - **The map.** `MapCard.jsx` is Leaflet over OpenStreetMap. Flutter has no
///     map without `flutter_map` or `google_maps_flutter`, neither of which is
///     in the doc 08 stack table — and C-2.4 (map view) is **P1**, so adding a
///     dependency for it during a P0 build is the wrong trade. The list is the
///     P0 surface.
///   - **Collections / Lists / Events chips.** C-2.5 is P1 and events are P2.
///     A chip that filters nothing is worse than an absent one, so only
///     `Tonight` ships — and it is wired to the real availability filter.
///
/// Photos WERE on this list and are not any more — Group B built the image
/// table and the row thumbnail draws `venue.cover` at 64pt. A venue with no
/// photos still gets the reference's mashrabiya placeholder, which is a
/// designed state rather than a gap.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final criteria = ref.watch(searchCriteriaProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      // One wrapper, at the top of the body. See SahraPageWidth: scattering
      // MediaQuery width checks through widgets is how three screens end up
      // with three ideas of "wide".
      body: SahraPageWidth(
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: SahraSpace.inset(
                start: SahraSpace.s5,
                end: SahraSpace.s5,
                top: SahraSpace.s5,
                bottom: SahraSpace.s3,
              ),
              child: Column(
                children: <Widget>[
                  SahraSearchBar(
                    hint: l10n.searchHint,
                    location: l10n.searchLocation,
                    locationSemanticLabel:
                        l10n.searchLocationSemantic(l10n.searchLocation),
                    controller: _controller,
                    onChanged: ref.read(searchCriteriaProvider.notifier).setText,
                    semanticLabel: l10n.searchHint,
                  ),
                  const SizedBox(height: SahraSpace.s3),
                  // Tonight stays its own chip — it is the one filter that is
                  // a mode rather than a narrowing, and burying it in the
                  // sheet would hide the availability post-filter that makes
                  // this search worth anything.
                  Row(
                    children: <Widget>[
                      SahraChip(
                        label: l10n.searchFilterTonight,
                        active: criteria.tonightOnly,
                        onPressed: ref.read(searchCriteriaProvider.notifier).toggleTonight,
                      ),
                      const SizedBox(width: SahraSpace.s2),
                      SahraChip(
                        // THE COUNT IS ON THE BUTTON. A diner has to be able
                        // to see they have filters on without opening the
                        // sheet; a forgotten filter is the commonest way
                        // somebody decides an app is broken.
                        label: criteria.activeFilterCount == 0
                            ? l10n.filterOpen
                            : l10n.filterOpenWithCount(criteria.activeFilterCount),
                        active: criteria.activeFilterCount > 0,
                        onPressed: () => showFilterSheet(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SahraAsyncView<SearchPage>(
                value: results,
                onRetry: () => ref.invalidate(searchResultsProvider),
                isEmpty: (page) => page.results.isEmpty,
                loading: (_) => const _SearchSkeleton(),
                empty: (context) => criteria.isBlank
                    // Two different empty states, because they mean different
                    // things. "Nothing matched" after a search is a dead end
                    // that needs a way out; "you haven't searched yet" is an
                    // invitation.
                    ? SahraEmptyState(
                        icon: 'search',
                        title: l10n.searchStartTitle,
                        message: l10n.searchStartMessage,
                      )
                    : SahraEmptyState(
                        icon: 'lantern',
                        title: l10n.searchEmptyTitle,
                        message: l10n.searchEmptyMessage,
                        actionLabel: l10n.searchEmptyAction,
                        onAction: () {
                          _controller.clear();
                          ref.read(searchCriteriaProvider.notifier).setText('');
                        },
                      ),
                content: (context, page) => _Results(page: page, tonight: criteria.tonightOnly),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.page, required this.tonight});

  final SearchPage page;
  final bool tonight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sahra = Theme.of(context).sahra;

    return ListView.separated(
      padding: SahraSpace.inset(
        start: SahraSpace.s5,
        end: SahraSpace.s5,
        bottom: SahraSpace.s5,
      ),
      itemCount: page.results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: SahraSpace.s3),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: SahraSpace.inset(bottom: SahraSpace.s2),
            child: Text(
              // Only claims "open tonight" when the results were actually
              // availability-filtered. Saying it about an unfiltered list
              // would be the search layer pretending to be the booking engine.
              page.availabilityFiltered
                  ? l10n.searchOpenTonight(page.results.length)
                  : l10n.searchResultCount(page.estimatedTotal),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sahra.textSoft),
            ),
          );
        }

        final venue = page.results[i - 1];
        return SahraResultRow(
          // The thumbnail slot in SahraResultRow is 64pt. Saying so here is
          // what stops a search list downloading twenty hero-sized files.
          image: venueImageProvider(context, ref, venue.cover, slotWidth: 64),
          name: venue.name,
          rating: venue.rating,
          reviews: venue.ratingCount,
          meta: venueMeta(l10n, venue.cuisines, venue.priceBand, venue.neighborhood),
          // ONLY WHEN THE SERVER COMPUTED ONE. Null unless the diner shared a
          // position, so a row never shows a distance from somewhere they are
          // not. One decimal — a venue 1.4km away and one 1.43km away are the
          // same walk.
          distance: venue.distanceKm == null
              ? null
              : l10n.resultDistance(venue.distanceKm!.toStringAsFixed(1)),
          availability: venue.nextAvailable.isEmpty
              ? null
              : l10n.searchNextAvailable(timeOfDay(venue.nextAvailable.first, context)),
          semanticLabel: venueSemanticLabel(context, venue),
          onTap: () => VenueRoute(venue.slug).go(context),
        );
      },
    );
  }
}

/// Loading is shaped like what is coming, so nothing jumps when data lands.
class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: SahraSpace.all(SahraSpace.s5),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: SahraSpace.s3),
      itemBuilder: (_, __) => const SahraSkeleton(height: 100, lattice: true),
    );
  }
}
