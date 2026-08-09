// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$venueMenusHash() => r'8454e1e28790b77e26ec902c1ba7ed50dc04254d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// A venue's menus (R-2.3).
///
/// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
/// hero, its hours and its booking bar before this resolves, which is what
/// matters on a Cairo mobile connection: the thing a diner came for is the
/// booking button, and it must not wait behind a menu.
///
/// Empty is an ordinary answer, not an error. Every menu row in the system is
/// typed in by hand today, so most venues have none.
///
/// Copied from [venueMenus].
@ProviderFor(venueMenus)
const venueMenusProvider = VenueMenusFamily();

/// A venue's menus (R-2.3).
///
/// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
/// hero, its hours and its booking bar before this resolves, which is what
/// matters on a Cairo mobile connection: the thing a diner came for is the
/// booking button, and it must not wait behind a menu.
///
/// Empty is an ordinary answer, not an error. Every menu row in the system is
/// typed in by hand today, so most venues have none.
///
/// Copied from [venueMenus].
class VenueMenusFamily extends Family<AsyncValue<List<Menu>>> {
  /// A venue's menus (R-2.3).
  ///
  /// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
  /// hero, its hours and its booking bar before this resolves, which is what
  /// matters on a Cairo mobile connection: the thing a diner came for is the
  /// booking button, and it must not wait behind a menu.
  ///
  /// Empty is an ordinary answer, not an error. Every menu row in the system is
  /// typed in by hand today, so most venues have none.
  ///
  /// Copied from [venueMenus].
  const VenueMenusFamily();

  /// A venue's menus (R-2.3).
  ///
  /// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
  /// hero, its hours and its booking bar before this resolves, which is what
  /// matters on a Cairo mobile connection: the thing a diner came for is the
  /// booking button, and it must not wait behind a menu.
  ///
  /// Empty is an ordinary answer, not an error. Every menu row in the system is
  /// typed in by hand today, so most venues have none.
  ///
  /// Copied from [venueMenus].
  VenueMenusProvider call(
    String idOrSlug,
  ) {
    return VenueMenusProvider(
      idOrSlug,
    );
  }

  @override
  VenueMenusProvider getProviderOverride(
    covariant VenueMenusProvider provider,
  ) {
    return call(
      provider.idOrSlug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'venueMenusProvider';
}

/// A venue's menus (R-2.3).
///
/// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
/// hero, its hours and its booking bar before this resolves, which is what
/// matters on a Cairo mobile connection: the thing a diner came for is the
/// booking button, and it must not wait behind a menu.
///
/// Empty is an ordinary answer, not an error. Every menu row in the system is
/// typed in by hand today, so most venues have none.
///
/// Copied from [venueMenus].
class VenueMenusProvider extends AutoDisposeFutureProvider<List<Menu>> {
  /// A venue's menus (R-2.3).
  ///
  /// SEPARATE FROM THE PROFILE, matching the API. The venue screen can draw its
  /// hero, its hours and its booking bar before this resolves, which is what
  /// matters on a Cairo mobile connection: the thing a diner came for is the
  /// booking button, and it must not wait behind a menu.
  ///
  /// Empty is an ordinary answer, not an error. Every menu row in the system is
  /// typed in by hand today, so most venues have none.
  ///
  /// Copied from [venueMenus].
  VenueMenusProvider(
    String idOrSlug,
  ) : this._internal(
          (ref) => venueMenus(
            ref as VenueMenusRef,
            idOrSlug,
          ),
          from: venueMenusProvider,
          name: r'venueMenusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$venueMenusHash,
          dependencies: VenueMenusFamily._dependencies,
          allTransitiveDependencies:
              VenueMenusFamily._allTransitiveDependencies,
          idOrSlug: idOrSlug,
        );

  VenueMenusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.idOrSlug,
  }) : super.internal();

  final String idOrSlug;

  @override
  Override overrideWith(
    FutureOr<List<Menu>> Function(VenueMenusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VenueMenusProvider._internal(
        (ref) => create(ref as VenueMenusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        idOrSlug: idOrSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Menu>> createElement() {
    return _VenueMenusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VenueMenusProvider && other.idOrSlug == idOrSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, idOrSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VenueMenusRef on AutoDisposeFutureProviderRef<List<Menu>> {
  /// The parameter `idOrSlug` of this provider.
  String get idOrSlug;
}

class _VenueMenusProviderElement
    extends AutoDisposeFutureProviderElement<List<Menu>> with VenueMenusRef {
  _VenueMenusProviderElement(super.provider);

  @override
  String get idOrSlug => (origin as VenueMenusProvider).idOrSlug;
}

String _$venueReviewsHash() => r'da6f41ce77d126ea28ae84195d9a44feddeb4679';

/// The first page of a venue's reviews, with the summary (C-4.4).
///
/// The summary rides on page one because the histogram is a property of the
/// whole venue, not of a page — asking for it separately would be a second
/// round trip for a number the first response already carries.
///
/// Copied from [venueReviews].
@ProviderFor(venueReviews)
const venueReviewsProvider = VenueReviewsFamily();

/// The first page of a venue's reviews, with the summary (C-4.4).
///
/// The summary rides on page one because the histogram is a property of the
/// whole venue, not of a page — asking for it separately would be a second
/// round trip for a number the first response already carries.
///
/// Copied from [venueReviews].
class VenueReviewsFamily extends Family<AsyncValue<ReviewPage>> {
  /// The first page of a venue's reviews, with the summary (C-4.4).
  ///
  /// The summary rides on page one because the histogram is a property of the
  /// whole venue, not of a page — asking for it separately would be a second
  /// round trip for a number the first response already carries.
  ///
  /// Copied from [venueReviews].
  const VenueReviewsFamily();

  /// The first page of a venue's reviews, with the summary (C-4.4).
  ///
  /// The summary rides on page one because the histogram is a property of the
  /// whole venue, not of a page — asking for it separately would be a second
  /// round trip for a number the first response already carries.
  ///
  /// Copied from [venueReviews].
  VenueReviewsProvider call(
    String idOrSlug,
  ) {
    return VenueReviewsProvider(
      idOrSlug,
    );
  }

  @override
  VenueReviewsProvider getProviderOverride(
    covariant VenueReviewsProvider provider,
  ) {
    return call(
      provider.idOrSlug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'venueReviewsProvider';
}

/// The first page of a venue's reviews, with the summary (C-4.4).
///
/// The summary rides on page one because the histogram is a property of the
/// whole venue, not of a page — asking for it separately would be a second
/// round trip for a number the first response already carries.
///
/// Copied from [venueReviews].
class VenueReviewsProvider extends AutoDisposeFutureProvider<ReviewPage> {
  /// The first page of a venue's reviews, with the summary (C-4.4).
  ///
  /// The summary rides on page one because the histogram is a property of the
  /// whole venue, not of a page — asking for it separately would be a second
  /// round trip for a number the first response already carries.
  ///
  /// Copied from [venueReviews].
  VenueReviewsProvider(
    String idOrSlug,
  ) : this._internal(
          (ref) => venueReviews(
            ref as VenueReviewsRef,
            idOrSlug,
          ),
          from: venueReviewsProvider,
          name: r'venueReviewsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$venueReviewsHash,
          dependencies: VenueReviewsFamily._dependencies,
          allTransitiveDependencies:
              VenueReviewsFamily._allTransitiveDependencies,
          idOrSlug: idOrSlug,
        );

  VenueReviewsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.idOrSlug,
  }) : super.internal();

  final String idOrSlug;

  @override
  Override overrideWith(
    FutureOr<ReviewPage> Function(VenueReviewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VenueReviewsProvider._internal(
        (ref) => create(ref as VenueReviewsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        idOrSlug: idOrSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ReviewPage> createElement() {
    return _VenueReviewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VenueReviewsProvider && other.idOrSlug == idOrSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, idOrSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VenueReviewsRef on AutoDisposeFutureProviderRef<ReviewPage> {
  /// The parameter `idOrSlug` of this provider.
  String get idOrSlug;
}

class _VenueReviewsProviderElement
    extends AutoDisposeFutureProviderElement<ReviewPage> with VenueReviewsRef {
  _VenueReviewsProviderElement(super.provider);

  @override
  String get idOrSlug => (origin as VenueReviewsProvider).idOrSlug;
}

String _$reviewFeedHash() => r'43bbfaac20cadcc96102167778e053739368053b';

abstract class _$ReviewFeed
    extends BuildlessAutoDisposeAsyncNotifier<ReviewPage> {
  late final String idOrSlug;

  FutureOr<ReviewPage> build(
    String idOrSlug,
  );
}

/// Every review loaded so far, for the sheet that pages through them.
///
/// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
/// venue screen shows the first three and must not be rebuilt every time
/// somebody scrolls the sheet behind it.
///
/// Copied from [ReviewFeed].
@ProviderFor(ReviewFeed)
const reviewFeedProvider = ReviewFeedFamily();

/// Every review loaded so far, for the sheet that pages through them.
///
/// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
/// venue screen shows the first three and must not be rebuilt every time
/// somebody scrolls the sheet behind it.
///
/// Copied from [ReviewFeed].
class ReviewFeedFamily extends Family<AsyncValue<ReviewPage>> {
  /// Every review loaded so far, for the sheet that pages through them.
  ///
  /// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
  /// venue screen shows the first three and must not be rebuilt every time
  /// somebody scrolls the sheet behind it.
  ///
  /// Copied from [ReviewFeed].
  const ReviewFeedFamily();

  /// Every review loaded so far, for the sheet that pages through them.
  ///
  /// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
  /// venue screen shows the first three and must not be rebuilt every time
  /// somebody scrolls the sheet behind it.
  ///
  /// Copied from [ReviewFeed].
  ReviewFeedProvider call(
    String idOrSlug,
  ) {
    return ReviewFeedProvider(
      idOrSlug,
    );
  }

  @override
  ReviewFeedProvider getProviderOverride(
    covariant ReviewFeedProvider provider,
  ) {
    return call(
      provider.idOrSlug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'reviewFeedProvider';
}

/// Every review loaded so far, for the sheet that pages through them.
///
/// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
/// venue screen shows the first three and must not be rebuilt every time
/// somebody scrolls the sheet behind it.
///
/// Copied from [ReviewFeed].
class ReviewFeedProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ReviewFeed, ReviewPage> {
  /// Every review loaded so far, for the sheet that pages through them.
  ///
  /// A separate notifier from [venueReviews] rather than a `copyWith` on it: the
  /// venue screen shows the first three and must not be rebuilt every time
  /// somebody scrolls the sheet behind it.
  ///
  /// Copied from [ReviewFeed].
  ReviewFeedProvider(
    String idOrSlug,
  ) : this._internal(
          () => ReviewFeed()..idOrSlug = idOrSlug,
          from: reviewFeedProvider,
          name: r'reviewFeedProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$reviewFeedHash,
          dependencies: ReviewFeedFamily._dependencies,
          allTransitiveDependencies:
              ReviewFeedFamily._allTransitiveDependencies,
          idOrSlug: idOrSlug,
        );

  ReviewFeedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.idOrSlug,
  }) : super.internal();

  final String idOrSlug;

  @override
  FutureOr<ReviewPage> runNotifierBuild(
    covariant ReviewFeed notifier,
  ) {
    return notifier.build(
      idOrSlug,
    );
  }

  @override
  Override overrideWith(ReviewFeed Function() create) {
    return ProviderOverride(
      origin: this,
      override: ReviewFeedProvider._internal(
        () => create()..idOrSlug = idOrSlug,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        idOrSlug: idOrSlug,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ReviewFeed, ReviewPage>
      createElement() {
    return _ReviewFeedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewFeedProvider && other.idOrSlug == idOrSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, idOrSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ReviewFeedRef on AutoDisposeAsyncNotifierProviderRef<ReviewPage> {
  /// The parameter `idOrSlug` of this provider.
  String get idOrSlug;
}

class _ReviewFeedProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ReviewFeed, ReviewPage>
    with ReviewFeedRef {
  _ReviewFeedProviderElement(super.provider);

  @override
  String get idOrSlug => (origin as ReviewFeedProvider).idOrSlug;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
