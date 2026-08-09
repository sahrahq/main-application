import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/restaurant_repository.dart';
import '../domain/venue.dart';

part 'search_notifier.g.dart';

/// What the search screen is asking for. Immutable, so a rebuild is a new
/// query rather than a mutated one.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.tonightOnly = false,
    this.partySize = 2,
    this.cuisine,
    this.priceBand,
    this.ratingMin,
    this.amenities = const <String>{},
  });

  final String text;

  /// The `Tonight` chip. When on, results are filtered by REAL availability
  /// for today at [partySize] — the Resy-class differentiator in C-2.2, and
  /// the reason a result can carry a `next_available` teaser at all.
  final bool tonightOnly;

  final int partySize;

  // ── C-2.2's filters, all of which the API has served since search shipped ──
  //
  // The client asked for none of them until the filter sheet. Each is nullable
  // rather than defaulted, because "any cuisine" and "cuisine = the first one
  // alphabetically" are different queries and a default would quietly make the
  // second one.

  /// One cuisine key, or null for any. SINGLE rather than a set: the API takes
  /// one, and a multi-select that silently used only the first would be a
  /// control that lies.
  final String? cuisine;

  /// 1–4, the `$`–`$$$$` band. Null for any.
  final int? priceBand;

  /// A floor, not a band. Null for any.
  final double? ratingMin;

  /// Amenity keys — outdoor, shisha, nile_view and the rest. Empty is no
  /// filter, which is not the same as a venue with no amenities.
  final Set<String> amenities;

  /// Whether anything beyond the text and the Tonight chip is narrowing the
  /// results. Drives the count on the filter button, so a diner can see they
  /// have filters on without opening the sheet — the commonest way somebody
  /// concludes an app is broken is a filter they forgot they set.
  int get activeFilterCount =>
      (cuisine == null ? 0 : 1) +
      (priceBand == null ? 0 : 1) +
      (ratingMin == null ? 0 : 1) +
      amenities.length;

  /// `copyWith` CANNOT CLEAR A FILTER, deliberately: `cuisine: null` means
  /// "leave it alone" in every `copyWith` ever written, and a sheet that could
  /// not express "any cuisine" would be a sheet with no way back. Clearing
  /// goes through [cleared] and [withFilters], which take the whole set.
  SearchQuery copyWith({String? text, bool? tonightOnly, int? partySize}) => SearchQuery(
        text: text ?? this.text,
        tonightOnly: tonightOnly ?? this.tonightOnly,
        partySize: partySize ?? this.partySize,
        cuisine: cuisine,
        priceBand: priceBand,
        ratingMin: ratingMin,
        amenities: amenities,
      );

  /// Replace every filter at once — what the sheet applies.
  SearchQuery withFilters({
    required String? cuisine,
    required int? priceBand,
    required double? ratingMin,
    required Set<String> amenities,
  }) =>
      SearchQuery(
        text: text,
        tonightOnly: tonightOnly,
        partySize: partySize,
        cuisine: cuisine,
        priceBand: priceBand,
        ratingMin: ratingMin,
        amenities: amenities,
      );

  /// Text and Tonight survive; every filter goes.
  SearchQuery get cleared => SearchQuery(
        text: text,
        tonightOnly: tonightOnly,
        partySize: partySize,
      );

  /// A search with nothing asked for. The screen shows its "start here" state
  /// rather than firing a bare query, because an unfiltered list of every
  /// venue in Cairo is not discovery.
  /// A FILTER COUNTS AS ASKING FOR SOMETHING. Without this, picking "Levantine
  /// · $$" and no text would render the "where are you eating tonight?" start
  /// state — a screen that ignored the filters the diner had just set.
  bool get isBlank =>
      text.trim().isEmpty && !tonightOnly && activeFilterCount == 0;
}

@riverpod
class SearchCriteria extends _$SearchCriteria {
  @override
  SearchQuery build() => const SearchQuery();

  void setText(String value) => state = state.copyWith(text: value);

  void toggleTonight() => state = state.copyWith(tonightOnly: !state.tonightOnly);

  void applyFilters({
    required String? cuisine,
    required int? priceBand,
    required double? ratingMin,
    required Set<String> amenities,
  }) =>
      state = state.withFilters(
        cuisine: cuisine,
        priceBand: priceBand,
        ratingMin: ratingMin,
        amenities: amenities,
      );

  void clearFilters() => state = state.cleared;
}

/// The results. One notifier per screen (doc 07 §5), side-effects only here.
///
/// `ref.watch` on the criteria means typing re-runs the search automatically —
/// and `autoDispose` (the default for `@riverpod`) means the previous query's
/// in-flight request is discarded rather than racing the new one to the screen.
@riverpod
Future<SearchPage> searchResults(Ref ref) async {
  final criteria = ref.watch(searchCriteriaProvider);
  if (criteria.isBlank) {
    // An empty page, not a request. `isEmpty` on the async view then renders
    // the "where are you eating tonight?" state — which is a different thing
    // from "nothing matched", and has to look different.
    return const SearchPage(
      results: <VenueSummary>[],
      estimatedTotal: 0,
      availabilityFiltered: false,
    );
  }

  return ref.watch(restaurantRepositoryProvider).search(
        query: criteria.text.trim().isEmpty ? null : criteria.text.trim(),
        availableOn: criteria.tonightOnly ? _today() : null,
        cuisine: criteria.cuisine,
        priceBand: criteria.priceBand,
        ratingMin: criteria.ratingMin,
        amenities: criteria.amenities.toList(),
        partySize: criteria.tonightOnly ? criteria.partySize : null,
      );
}

/// Today, on the DEVICE's clock.
///
/// An approximation, and a deliberate one: the API wants a `YYYY-MM-DD` in the
/// restaurant's own timezone, and the client cannot know that before it has
/// searched. For an Egypt-first app the device is on Africa/Cairo, so the two
/// agree; a diner searching "tonight" from Europe at 23:30 would ask about the
/// wrong day. Correct answer is a server-side `tonight` filter — noted rather
/// than faked here, because guessing the zone is how the 2–3 hour Cairo error
/// gets in.
String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
