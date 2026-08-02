// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_booking.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingBookingHash() => r'50749c67021c6bae060509bfe686f358bbf12af1';

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

abstract class _$PendingBooking extends BuildlessNotifier<PendingSelection?> {
  late final String restaurantId;

  PendingSelection? build(
    String restaurantId,
  );
}

/// Keyed by venue, so a diner who wandered between two restaurants before
/// signing in comes back to the right one.
///
/// `keepAlive`, and the round-trip test is what proved it has to be. An
/// auto-disposing notifier is disposed the moment nothing watches it — which
/// is precisely the moment the booking screen parks a selection and navigates
/// away. The selection was written and destroyed in the same frame, and the
/// sign-in screen then created a fresh one and read null out of it.
///
/// This does NOT weaken the process-scoping above. `keepAlive` binds the
/// selection to the ProviderContainer, and the container dies with the app: a
/// restart still loses it, which is still the feature.
///
/// Copied from [PendingBooking].
@ProviderFor(PendingBooking)
const pendingBookingProvider = PendingBookingFamily();

/// Keyed by venue, so a diner who wandered between two restaurants before
/// signing in comes back to the right one.
///
/// `keepAlive`, and the round-trip test is what proved it has to be. An
/// auto-disposing notifier is disposed the moment nothing watches it — which
/// is precisely the moment the booking screen parks a selection and navigates
/// away. The selection was written and destroyed in the same frame, and the
/// sign-in screen then created a fresh one and read null out of it.
///
/// This does NOT weaken the process-scoping above. `keepAlive` binds the
/// selection to the ProviderContainer, and the container dies with the app: a
/// restart still loses it, which is still the feature.
///
/// Copied from [PendingBooking].
class PendingBookingFamily extends Family<PendingSelection?> {
  /// Keyed by venue, so a diner who wandered between two restaurants before
  /// signing in comes back to the right one.
  ///
  /// `keepAlive`, and the round-trip test is what proved it has to be. An
  /// auto-disposing notifier is disposed the moment nothing watches it — which
  /// is precisely the moment the booking screen parks a selection and navigates
  /// away. The selection was written and destroyed in the same frame, and the
  /// sign-in screen then created a fresh one and read null out of it.
  ///
  /// This does NOT weaken the process-scoping above. `keepAlive` binds the
  /// selection to the ProviderContainer, and the container dies with the app: a
  /// restart still loses it, which is still the feature.
  ///
  /// Copied from [PendingBooking].
  const PendingBookingFamily();

  /// Keyed by venue, so a diner who wandered between two restaurants before
  /// signing in comes back to the right one.
  ///
  /// `keepAlive`, and the round-trip test is what proved it has to be. An
  /// auto-disposing notifier is disposed the moment nothing watches it — which
  /// is precisely the moment the booking screen parks a selection and navigates
  /// away. The selection was written and destroyed in the same frame, and the
  /// sign-in screen then created a fresh one and read null out of it.
  ///
  /// This does NOT weaken the process-scoping above. `keepAlive` binds the
  /// selection to the ProviderContainer, and the container dies with the app: a
  /// restart still loses it, which is still the feature.
  ///
  /// Copied from [PendingBooking].
  PendingBookingProvider call(
    String restaurantId,
  ) {
    return PendingBookingProvider(
      restaurantId,
    );
  }

  @override
  PendingBookingProvider getProviderOverride(
    covariant PendingBookingProvider provider,
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
  String? get name => r'pendingBookingProvider';
}

/// Keyed by venue, so a diner who wandered between two restaurants before
/// signing in comes back to the right one.
///
/// `keepAlive`, and the round-trip test is what proved it has to be. An
/// auto-disposing notifier is disposed the moment nothing watches it — which
/// is precisely the moment the booking screen parks a selection and navigates
/// away. The selection was written and destroyed in the same frame, and the
/// sign-in screen then created a fresh one and read null out of it.
///
/// This does NOT weaken the process-scoping above. `keepAlive` binds the
/// selection to the ProviderContainer, and the container dies with the app: a
/// restart still loses it, which is still the feature.
///
/// Copied from [PendingBooking].
class PendingBookingProvider
    extends NotifierProviderImpl<PendingBooking, PendingSelection?> {
  /// Keyed by venue, so a diner who wandered between two restaurants before
  /// signing in comes back to the right one.
  ///
  /// `keepAlive`, and the round-trip test is what proved it has to be. An
  /// auto-disposing notifier is disposed the moment nothing watches it — which
  /// is precisely the moment the booking screen parks a selection and navigates
  /// away. The selection was written and destroyed in the same frame, and the
  /// sign-in screen then created a fresh one and read null out of it.
  ///
  /// This does NOT weaken the process-scoping above. `keepAlive` binds the
  /// selection to the ProviderContainer, and the container dies with the app: a
  /// restart still loses it, which is still the feature.
  ///
  /// Copied from [PendingBooking].
  PendingBookingProvider(
    String restaurantId,
  ) : this._internal(
          () => PendingBooking()..restaurantId = restaurantId,
          from: pendingBookingProvider,
          name: r'pendingBookingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$pendingBookingHash,
          dependencies: PendingBookingFamily._dependencies,
          allTransitiveDependencies:
              PendingBookingFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  PendingBookingProvider._internal(
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
  PendingSelection? runNotifierBuild(
    covariant PendingBooking notifier,
  ) {
    return notifier.build(
      restaurantId,
    );
  }

  @override
  Override overrideWith(PendingBooking Function() create) {
    return ProviderOverride(
      origin: this,
      override: PendingBookingProvider._internal(
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
  NotifierProviderElement<PendingBooking, PendingSelection?> createElement() {
    return _PendingBookingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingBookingProvider &&
        other.restaurantId == restaurantId;
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
mixin PendingBookingRef on NotifierProviderRef<PendingSelection?> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _PendingBookingProviderElement
    extends NotifierProviderElement<PendingBooking, PendingSelection?>
    with PendingBookingRef {
  _PendingBookingProviderElement(super.provider);

  @override
  String get restaurantId => (origin as PendingBookingProvider).restaurantId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
