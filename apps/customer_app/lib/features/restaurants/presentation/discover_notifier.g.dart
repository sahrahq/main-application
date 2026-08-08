// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$availableTonightHash() => r'2b525fc9608286b409a543f93f0311327f2c436d';

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
///
/// Copied from [availableTonight].
@ProviderFor(availableTonight)
final availableTonightProvider = AutoDisposeFutureProvider<SearchPage>.internal(
  availableTonight,
  name: r'availableTonightProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableTonightHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableTonightRef = AutoDisposeFutureProviderRef<SearchPage>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
