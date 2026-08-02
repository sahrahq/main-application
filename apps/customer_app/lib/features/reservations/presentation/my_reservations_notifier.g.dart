// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_reservations_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myReservationsHash() => r'ef2fc10a84ffd7ab79f582e3ded5e2abf00554f5';

/// The diner's reservations for the selected view.
///
/// WATCHES THE SESSION, and that is not incidental. Signing in on another
/// screen has to make this list appear, and signing out has to make it vanish
/// — if it only read the session once, a diner who signed in from the empty
/// state would be looking at "sign in to see your bookings" while holding a
/// valid token.
///
/// Signed out it returns EMPTY rather than calling and catching the 401. The
/// screen shows its own signed-out state; making the round trip first would put
/// an error in the log for a situation that is not an error.
///
/// Copied from [myReservations].
@ProviderFor(myReservations)
final myReservationsProvider =
    AutoDisposeFutureProvider<List<MyReservation>>.internal(
  myReservations,
  name: r'myReservationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myReservationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyReservationsRef = AutoDisposeFutureProviderRef<List<MyReservation>>;
String _$reservationDetailHash() => r'6654e421a67f15fa526a2f73ddb6525172a0519b';

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

/// One reservation, for the detail screen.
///
/// Copied from [reservationDetail].
@ProviderFor(reservationDetail)
const reservationDetailProvider = ReservationDetailFamily();

/// One reservation, for the detail screen.
///
/// Copied from [reservationDetail].
class ReservationDetailFamily extends Family<AsyncValue<MyReservation>> {
  /// One reservation, for the detail screen.
  ///
  /// Copied from [reservationDetail].
  const ReservationDetailFamily();

  /// One reservation, for the detail screen.
  ///
  /// Copied from [reservationDetail].
  ReservationDetailProvider call(
    String id,
  ) {
    return ReservationDetailProvider(
      id,
    );
  }

  @override
  ReservationDetailProvider getProviderOverride(
    covariant ReservationDetailProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'reservationDetailProvider';
}

/// One reservation, for the detail screen.
///
/// Copied from [reservationDetail].
class ReservationDetailProvider
    extends AutoDisposeFutureProvider<MyReservation> {
  /// One reservation, for the detail screen.
  ///
  /// Copied from [reservationDetail].
  ReservationDetailProvider(
    String id,
  ) : this._internal(
          (ref) => reservationDetail(
            ref as ReservationDetailRef,
            id,
          ),
          from: reservationDetailProvider,
          name: r'reservationDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$reservationDetailHash,
          dependencies: ReservationDetailFamily._dependencies,
          allTransitiveDependencies:
              ReservationDetailFamily._allTransitiveDependencies,
          id: id,
        );

  ReservationDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<MyReservation> Function(ReservationDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ReservationDetailProvider._internal(
        (ref) => create(ref as ReservationDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<MyReservation> createElement() {
    return _ReservationDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ReservationDetailRef on AutoDisposeFutureProviderRef<MyReservation> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ReservationDetailProviderElement
    extends AutoDisposeFutureProviderElement<MyReservation>
    with ReservationDetailRef {
  _ReservationDetailProviderElement(super.provider);

  @override
  String get id => (origin as ReservationDetailProvider).id;
}

String _$bookingsViewHash() => r'369a1c7c7790862f66c51d4e5fba53b4be17c48b';

/// Which half of the bookings screen is showing.
///
/// Copied from [BookingsView].
@ProviderFor(BookingsView)
final bookingsViewProvider =
    AutoDisposeNotifierProvider<BookingsView, String>.internal(
  BookingsView.new,
  name: r'bookingsViewProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bookingsViewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BookingsView = AutoDisposeNotifier<String>;
String _$acknowledgeCancellationHash() =>
    r'6f9c2c39f8e474fd6f3e2065ab379d0f60629692';

/// "I have seen that the restaurant cancelled."
///
/// A NOTIFIER RATHER THAN A CALL FROM THE WIDGET, because it has to invalidate
/// two things afterwards: the detail this was tapped on, and the list that is
/// still showing the reservation in `upcoming` because of the very flag being
/// cleared. Acknowledging on the detail screen and going back to a list that
/// still says "the restaurant cancelled — got it?" is the bug this prevents.
///
/// Copied from [AcknowledgeCancellation].
@ProviderFor(AcknowledgeCancellation)
final acknowledgeCancellationProvider =
    AutoDisposeNotifierProvider<AcknowledgeCancellation, bool>.internal(
  AcknowledgeCancellation.new,
  name: r'acknowledgeCancellationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$acknowledgeCancellationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AcknowledgeCancellation = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
