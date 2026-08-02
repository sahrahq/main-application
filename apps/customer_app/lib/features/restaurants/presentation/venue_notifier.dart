import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/venue.dart';

part 'venue_notifier.g.dart';

/// The full profile behind a search result (doc 06 §3).
///
/// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
/// lands on the same provider as a tap from search, with no branch anywhere
/// for "did we come from a list or from a URL".
@riverpod
Future<VenueProfile> venueProfile(Ref ref, String idOrSlug) =>
    ref.watch(restaurantRepositoryProvider).profile(idOrSlug);
