// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchResultsHash() => r'df242a220f61ba75d00412f91e298aad22a696a4';

/// The results. One notifier per screen (doc 07 §5), side-effects only here.
///
/// `ref.watch` on the criteria means typing re-runs the search automatically —
/// and `autoDispose` (the default for `@riverpod`) means the previous query's
/// in-flight request is discarded rather than racing the new one to the screen.
///
/// Copied from [searchResults].
@ProviderFor(searchResults)
final searchResultsProvider = AutoDisposeFutureProvider<SearchPage>.internal(
  searchResults,
  name: r'searchResultsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$searchResultsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SearchResultsRef = AutoDisposeFutureProviderRef<SearchPage>;
String _$searchCriteriaHash() => r'23a5665d4450fc366ee0de539c3408745081131e';

/// See also [SearchCriteria].
@ProviderFor(SearchCriteria)
final searchCriteriaProvider = AutoDisposeNotifierProvider<SearchCriteria, SearchQuery>.internal(
  SearchCriteria.new,
  name: r'searchCriteriaProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$searchCriteriaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchCriteria = AutoDisposeNotifier<SearchQuery>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
