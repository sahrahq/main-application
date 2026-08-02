import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/restaurant_repository.dart';
import '../domain/venue.dart';

part 'search_notifier.g.dart';

/// What the search screen is asking for. Immutable, so a rebuild is a new
/// query rather than a mutated one.
class SearchQuery {
  const SearchQuery({this.text = '', this.tonightOnly = false, this.partySize = 2});

  final String text;

  /// The `Tonight` chip. When on, results are filtered by REAL availability
  /// for today at [partySize] — the Resy-class differentiator in C-2.2, and
  /// the reason a result can carry a `next_available` teaser at all.
  final bool tonightOnly;

  final int partySize;

  SearchQuery copyWith({String? text, bool? tonightOnly, int? partySize}) => SearchQuery(
        text: text ?? this.text,
        tonightOnly: tonightOnly ?? this.tonightOnly,
        partySize: partySize ?? this.partySize,
      );

  /// A search with nothing asked for. The screen shows its "start here" state
  /// rather than firing a bare query, because an unfiltered list of every
  /// venue in Cairo is not discovery.
  bool get isBlank => text.trim().isEmpty && !tonightOnly;
}

@riverpod
class SearchCriteria extends _$SearchCriteria {
  @override
  SearchQuery build() => const SearchQuery();

  void setText(String value) => state = state.copyWith(text: value);

  void toggleTonight() => state = state.copyWith(tonightOnly: !state.tonightOnly);
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
