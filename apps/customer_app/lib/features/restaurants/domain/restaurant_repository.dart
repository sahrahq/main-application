import 'menu.dart';
import 'review.dart';
import 'search_sort.dart';
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
  /// [lat], [lng] and [radiusKm] are C-2.2's distance filter, and [sort] is
  /// C-2.3. They arrive together or not at all: the API needs a position for
  /// both `radius_km` and `sort=distance`, and refuses half a distance query
  /// the same way it refuses half an availability one.
  ///
  /// The caller is responsible for having a position before asking. Nothing
  /// here guesses one — a filter that silently ranked against a location we do
  /// not have would be worse than its absence, which is why it did not ship
  /// until the app could actually ask.
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
    double? lat,
    double? lng,
    double? radiusKm,
    SearchSort sort = SearchSort.relevance,
  });

  /// The full profile, by id or slug (doc 06 §3).
  Future<VenueProfile> profile(String idOrSlug);

  /// A venue's menus (doc 06 §3, R-2.3).
  ///
  /// A SEPARATE CALL from [profile], matching the API. Folding menus into the
  /// profile would make every venue open pay for a menu most diners never
  /// expand, on a Cairo mobile connection — and the profile is what the screen
  /// needs before it can draw anything at all.
  ///
  /// Empty is an ordinary answer: most venues have no menu in the system yet,
  /// because every row of one is typed in by hand.
  Future<List<Menu>> menus(String idOrSlug);

  /// A venue's published reviews, newest first (doc 06 §3, C-4.4).
  ///
  /// [cursor] is the previous page's `nextCursor`. Null asks for the first
  /// page and always returns the summary with it, so the histogram is never
  /// drawn from a page.
  Future<ReviewPage> reviews(String idOrSlug, {String? cursor, int? limit});
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
