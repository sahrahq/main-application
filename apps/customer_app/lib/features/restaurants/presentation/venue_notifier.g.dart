// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$venueProfileHash() => r'592860aaa6a8459b4cad071482bf67e043536ef8';

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

/// The full profile behind a search result (doc 06 §3).
///
/// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
/// lands on the same provider as a tap from search, with no branch anywhere
/// for "did we come from a list or from a URL".
///
/// Copied from [venueProfile].
@ProviderFor(venueProfile)
const venueProfileProvider = VenueProfileFamily();

/// The full profile behind a search result (doc 06 §3).
///
/// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
/// lands on the same provider as a tap from search, with no branch anywhere
/// for "did we come from a list or from a URL".
///
/// Copied from [venueProfile].
class VenueProfileFamily extends Family<AsyncValue<VenueProfile>> {
  /// The full profile behind a search result (doc 06 §3).
  ///
  /// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
  /// lands on the same provider as a tap from search, with no branch anywhere
  /// for "did we come from a list or from a URL".
  ///
  /// Copied from [venueProfile].
  const VenueProfileFamily();

  /// The full profile behind a search result (doc 06 §3).
  ///
  /// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
  /// lands on the same provider as a tap from search, with no branch anywhere
  /// for "did we come from a list or from a URL".
  ///
  /// Copied from [venueProfile].
  VenueProfileProvider call(
    String idOrSlug,
  ) {
    return VenueProfileProvider(
      idOrSlug,
    );
  }

  @override
  VenueProfileProvider getProviderOverride(
    covariant VenueProfileProvider provider,
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
  String? get name => r'venueProfileProvider';
}

/// The full profile behind a search result (doc 06 §3).
///
/// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
/// lands on the same provider as a tap from search, with no branch anywhere
/// for "did we come from a list or from a URL".
///
/// Copied from [venueProfile].
class VenueProfileProvider extends AutoDisposeFutureProvider<VenueProfile> {
  /// The full profile behind a search result (doc 06 §3).
  ///
  /// A `family` on `idOrSlug` so a deep link — `sahra.app/r/{slug}`, doc 07 §3 —
  /// lands on the same provider as a tap from search, with no branch anywhere
  /// for "did we come from a list or from a URL".
  ///
  /// Copied from [venueProfile].
  VenueProfileProvider(
    String idOrSlug,
  ) : this._internal(
          (ref) => venueProfile(
            ref as VenueProfileRef,
            idOrSlug,
          ),
          from: venueProfileProvider,
          name: r'venueProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$venueProfileHash,
          dependencies: VenueProfileFamily._dependencies,
          allTransitiveDependencies:
              VenueProfileFamily._allTransitiveDependencies,
          idOrSlug: idOrSlug,
        );

  VenueProfileProvider._internal(
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
    FutureOr<VenueProfile> Function(VenueProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VenueProfileProvider._internal(
        (ref) => create(ref as VenueProfileRef),
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
  AutoDisposeFutureProviderElement<VenueProfile> createElement() {
    return _VenueProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VenueProfileProvider && other.idOrSlug == idOrSlug;
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
mixin VenueProfileRef on AutoDisposeFutureProviderRef<VenueProfile> {
  /// The parameter `idOrSlug` of this provider.
  String get idOrSlug;
}

class _VenueProfileProviderElement
    extends AutoDisposeFutureProviderElement<VenueProfile>
    with VenueProfileRef {
  _VenueProfileProviderElement(super.provider);

  @override
  String get idOrSlug => (origin as VenueProfileProvider).idOrSlug;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
