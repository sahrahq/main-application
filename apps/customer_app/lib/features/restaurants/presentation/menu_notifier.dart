import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/menu.dart';
import '../domain/review.dart';

part 'menu_notifier.g.dart';

/// A venue's menus (R-2.3).
///
/// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
/// hero, its hours and its booking bar before this resolves, which is what
/// matters on a Cairo mobile connection: the thing a diner came for is the
/// booking button, and it must not wait behind a menu.
///
/// Empty is an ordinary answer, not an error. Every menu row in the system is
/// typed in by hand today, so most venues have none.
@riverpod
Future<List<Menu>> venueMenus(Ref ref, String idOrSlug) =>
    ref.watch(restaurantRepositoryProvider).menus(idOrSlug);

/// The first page of a venue's reviews, with the summary (C-4.4).
///
/// The summary rides on page one because the histogram is a property of the
/// whole venue, not of a page — asking for it separately would be a second
/// round trip for a number the first response already carries.
@riverpod
Future<ReviewPage> venueReviews(Ref ref, String idOrSlug) =>
    ref.watch(restaurantRepositoryProvider).reviews(idOrSlug);

/// Every review loaded so far, for the sheet that pages through them.
///
/// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
/// venue screen shows the first three and must not be rebuilt every time
/// somebody scrolls the sheet behind it.
@riverpod
class ReviewFeed extends _$ReviewFeed {
  @override
  Future<ReviewPage> build(String idOrSlug) =>
      ref.watch(restaurantRepositoryProvider).reviews(idOrSlug);

  /// Append the next page.
  ///
  /// The summary is kept from the FIRST page. Page two carries its own copy and
  /// they should agree, but taking the newer one would let the headline figure
  /// change under a diner mid-scroll if a review landed in between — a number
  /// that moves while you are reading it reads as a bug even when it is right.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null) return;

    // NOT `state = AsyncLoading()`. That would blank the list the diner is
    // reading. The extra rows arrive or they do not; the ones already on
    // screen stay either way.
    final next =
        await ref.read(restaurantRepositoryProvider).reviews(idOrSlug, cursor: current.nextCursor);

    state = AsyncData<ReviewPage>(
      ReviewPage(
        summary: current.summary,
        results: <Review>[...current.results, ...next.results],
        nextCursor: next.nextCursor,
      ),
    );
  }
}
