// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedVenuesHash() => r'dcf8e32ec8c68c02f0934f71f36e3c482b07d43d';

/// The diner's saved venues.
///
/// WATCHES THE SESSION, like `myReservations` and for the same reason: signing
/// in on another screen has to make this list appear, and signing out has to
/// make it vanish. Signed out it returns EMPTY rather than calling and
/// catching the 401 — the screen shows its own signed-out state, and making
/// the round trip first would log an error for a situation that is not one.
///
/// Copied from [savedVenues].
@ProviderFor(savedVenues)
final savedVenuesProvider =
    AutoDisposeFutureProvider<List<SavedVenue>>.internal(
  savedVenues,
  name: r'savedVenuesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$savedVenuesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedVenuesRef = AutoDisposeFutureProviderRef<List<SavedVenue>>;
String _$savedVenueIdsHash() => r'c325d61e054282dee7969eb2f3086caad18c8f49';

/// Which venue ids are saved, for the heart on a card.
///
/// DERIVED FROM THE ONE LIST, not fetched per card. A `savedIds` that made its
/// own request would be a second source of truth for the same fact, and the
/// two would disagree for exactly as long as one of them was stale — which is
/// the window in which a diner taps a filled heart and it fills again.
///
/// Copied from [savedVenueIds].
@ProviderFor(savedVenueIds)
final savedVenueIdsProvider = AutoDisposeProvider<Set<String>>.internal(
  savedVenueIds,
  name: r'savedVenueIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$savedVenueIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedVenueIdsRef = AutoDisposeProviderRef<Set<String>>;
String _$saveToggleHash() => r'956d361015cb8fdf7be1f549d7f61cc2bb69363b';

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

abstract class _$SaveToggle extends BuildlessAutoDisposeNotifier<bool> {
  late final String restaurantId;

  bool build(
    String restaurantId,
  );
}

/// Save and unsave, for one venue.
///
/// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
///
/// The heart fills on tap, before the server answers. A save that waited for a
/// round trip on a Cairo mobile connection would feel broken, and the diner
/// would tap again — which is exactly why both endpoints are idempotent.
///
/// But an optimistic update that cannot roll back is a lie: if the call fails,
/// the heart stays filled and the venue is not saved, and the diner finds out
/// when the list is empty. So the failure path puts the list back.
///
/// Copied from [SaveToggle].
@ProviderFor(SaveToggle)
const saveToggleProvider = SaveToggleFamily();

/// Save and unsave, for one venue.
///
/// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
///
/// The heart fills on tap, before the server answers. A save that waited for a
/// round trip on a Cairo mobile connection would feel broken, and the diner
/// would tap again — which is exactly why both endpoints are idempotent.
///
/// But an optimistic update that cannot roll back is a lie: if the call fails,
/// the heart stays filled and the venue is not saved, and the diner finds out
/// when the list is empty. So the failure path puts the list back.
///
/// Copied from [SaveToggle].
class SaveToggleFamily extends Family<bool> {
  /// Save and unsave, for one venue.
  ///
  /// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
  ///
  /// The heart fills on tap, before the server answers. A save that waited for a
  /// round trip on a Cairo mobile connection would feel broken, and the diner
  /// would tap again — which is exactly why both endpoints are idempotent.
  ///
  /// But an optimistic update that cannot roll back is a lie: if the call fails,
  /// the heart stays filled and the venue is not saved, and the diner finds out
  /// when the list is empty. So the failure path puts the list back.
  ///
  /// Copied from [SaveToggle].
  const SaveToggleFamily();

  /// Save and unsave, for one venue.
  ///
  /// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
  ///
  /// The heart fills on tap, before the server answers. A save that waited for a
  /// round trip on a Cairo mobile connection would feel broken, and the diner
  /// would tap again — which is exactly why both endpoints are idempotent.
  ///
  /// But an optimistic update that cannot roll back is a lie: if the call fails,
  /// the heart stays filled and the venue is not saved, and the diner finds out
  /// when the list is empty. So the failure path puts the list back.
  ///
  /// Copied from [SaveToggle].
  SaveToggleProvider call(
    String restaurantId,
  ) {
    return SaveToggleProvider(
      restaurantId,
    );
  }

  @override
  SaveToggleProvider getProviderOverride(
    covariant SaveToggleProvider provider,
  ) {
    return call(
      provider.restaurantId,
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
  String? get name => r'saveToggleProvider';
}

/// Save and unsave, for one venue.
///
/// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
///
/// The heart fills on tap, before the server answers. A save that waited for a
/// round trip on a Cairo mobile connection would feel broken, and the diner
/// would tap again — which is exactly why both endpoints are idempotent.
///
/// But an optimistic update that cannot roll back is a lie: if the call fails,
/// the heart stays filled and the venue is not saved, and the diner finds out
/// when the list is empty. So the failure path puts the list back.
///
/// Copied from [SaveToggle].
class SaveToggleProvider
    extends AutoDisposeNotifierProviderImpl<SaveToggle, bool> {
  /// Save and unsave, for one venue.
  ///
  /// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
  ///
  /// The heart fills on tap, before the server answers. A save that waited for a
  /// round trip on a Cairo mobile connection would feel broken, and the diner
  /// would tap again — which is exactly why both endpoints are idempotent.
  ///
  /// But an optimistic update that cannot roll back is a lie: if the call fails,
  /// the heart stays filled and the venue is not saved, and the diner finds out
  /// when the list is empty. So the failure path puts the list back.
  ///
  /// Copied from [SaveToggle].
  SaveToggleProvider(
    String restaurantId,
  ) : this._internal(
          () => SaveToggle()..restaurantId = restaurantId,
          from: saveToggleProvider,
          name: r'saveToggleProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveToggleHash,
          dependencies: SaveToggleFamily._dependencies,
          allTransitiveDependencies:
              SaveToggleFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  SaveToggleProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.restaurantId,
  }) : super.internal();

  final String restaurantId;

  @override
  bool runNotifierBuild(
    covariant SaveToggle notifier,
  ) {
    return notifier.build(
      restaurantId,
    );
  }

  @override
  Override overrideWith(SaveToggle Function() create) {
    return ProviderOverride(
      origin: this,
      override: SaveToggleProvider._internal(
        () => create()..restaurantId = restaurantId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        restaurantId: restaurantId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SaveToggle, bool> createElement() {
    return _SaveToggleProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveToggleProvider && other.restaurantId == restaurantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, restaurantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SaveToggleRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _SaveToggleProviderElement
    extends AutoDisposeNotifierProviderElement<SaveToggle, bool>
    with SaveToggleRef {
  _SaveToggleProviderElement(super.provider);

  @override
  String get restaurantId => (origin as SaveToggleProvider).restaurantId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
