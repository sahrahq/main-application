import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/restaurant_repository.dart';

part 'discover_notifier.g.dart';

/// The one row on Discover that has real data behind it: venues with a table
/// free TONIGHT.
///
/// ── WHY THIS IS THE AVAILABILITY-FILTERED SEARCH ─────────────────────────
///
/// "Available tonight" is not a curated list and must not become one. It is
/// `GET /restaurants/search?date=today&party_size=2` with the post-filter on,
/// which is the same path the search screen uses and the same one the booking
/// engine will re-check. A separate "featured tonight" endpoint would be a
/// second opinion about what is bookable, and the two would disagree exactly
/// when it matters — a diner tapping a card the home screen promised and
/// finding nothing free.
///
/// PARTY OF TWO, and it is a real assumption rather than a neutral default:
/// two is the modal restaurant booking, and a home screen has to pick
/// something before it knows anything about the diner. The moment C-1.5's
/// "default party size" exists, it replaces this.
@riverpod
Future<SearchPage> availableTonight(Ref ref) {
  final today = ref.watch(todayProvider);

  return ref.watch(restaurantRepositoryProvider).search(
        availableOn: DateFormat('yyyy-MM-dd').format(today),
        partySize: 2,
      );
}
