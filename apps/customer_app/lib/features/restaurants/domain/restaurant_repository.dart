import 'venue.dart';

/// What the presentation layer is allowed to know about restaurants.
///
/// Abstract and pure Dart, so a notifier can be unit-tested without a socket
/// and without the generated client (doc 07 §1: "the domain layer stays pure
/// Dart"). The implementation lives in `data/`, and `layers_test.dart` fails
/// the build if anything under `presentation/` imports it directly.
abstract class RestaurantRepository {
  /// Discovery search (doc 06 §3).
  ///
  /// [availableOn] + [partySize] must be supplied TOGETHER or not at all — the
  /// API rejects half a filter with `invalid_availability_filter`, because
  /// unfiltered results that look availability-checked are worse than none.
  ///
  /// Throws — it does not return a Result. The notifier's `AsyncValue` already
  /// carries the error, and a second error channel means two ways to handle
  /// the same failure.
  /// [cuisine], [priceBand], [ratingMin] and [amenities] are C-2.2's filters.
  /// Every one of them has been served by the API since search shipped; the
  /// client simply never asked. Threading them through here is what the filter
  /// sheet needed — no backend change at all.
  ///
  /// NO `distance`, and that is a capability gap rather than an oversight. The
  /// API takes lat/lng and a radius, and nothing in this app collects a
  /// location: there is no permission prompt and no geocoding. A filter that
  /// silently ranked by a location we do not have would be worse than its
  /// absence.
  Future<SearchPage> search({
    String? query,
    String? neighborhood,
    String? availableOn,
    int? partySize,
    String? cursor,
    String? cuisine,
    int? priceBand,
    double? ratingMin,
    List<String> amenities = const <String>[],
  });

  /// The full profile, by id or slug (doc 06 §3).
  Future<VenueProfile> profile(String idOrSlug);
}

class SearchPage {
  const SearchPage({
    required this.results,
    required this.estimatedTotal,
    required this.availabilityFiltered,
    this.nextCursor,
  });

  final List<VenueSummary> results;
  final int estimatedTotal;

  /// True when [results] were filtered by REAL availability. False means the
  /// list answers "which venues match", not "what is free" — and the screen
  /// must not imply otherwise.
  final bool availabilityFiltered;

  /// Note that page two has NOT been availability-filtered at all
  /// (sahra_api_client/README.md §3): the post-filter covers the first page
  /// only, by design, because computing real availability for every match
  /// would put an unbounded query behind a search box.
  final String? nextCursor;
}
