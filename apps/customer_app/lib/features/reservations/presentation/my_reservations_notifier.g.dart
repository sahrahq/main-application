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
final myReservationsProvider = AutoDisposeFutureProvider<List<MyReservation>>.internal(
  myReservations,
  name: r'myReservationsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myReservationsHash,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'reservationDetailProvider';
}

/// One reservation, for the detail screen.
///
/// Copied from [reservationDetail].
class ReservationDetailProvider extends AutoDisposeFutureProvider<MyReservation> {
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
              const bool.fromEnvironment('dart.vm.product') ? null : _$reservationDetailHash,
          dependencies: ReservationDetailFamily._dependencies,
          allTransitiveDependencies: ReservationDetailFamily._allTransitiveDependencies,
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

class _ReservationDetailProviderElement extends AutoDisposeFutureProviderElement<MyReservation>
    with ReservationDetailRef {
  _ReservationDetailProviderElement(super.provider);

  @override
  String get id => (origin as ReservationDetailProvider).id;
}

String _$movableSlotsHash() => r'49df73584cf404caff876beae2ec00fb9e3ee84c';

/// The grid for the move sheet.
///
/// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
/// its own tables count as free, so the times either side of the current
/// booking are offered. See the repository note.
///
/// Copied from [movableSlots].
@ProviderFor(movableSlots)
const movableSlotsProvider = MovableSlotsFamily();

/// The grid for the move sheet.
///
/// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
/// its own tables count as free, so the times either side of the current
/// booking are offered. See the repository note.
///
/// Copied from [movableSlots].
class MovableSlotsFamily extends Family<AsyncValue<SlotBoard>> {
  /// The grid for the move sheet.
  ///
  /// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
  /// its own tables count as free, so the times either side of the current
  /// booking are offered. See the repository note.
  ///
  /// Copied from [movableSlots].
  const MovableSlotsFamily();

  /// The grid for the move sheet.
  ///
  /// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
  /// its own tables count as free, so the times either side of the current
  /// booking are offered. See the repository note.
  ///
  /// Copied from [movableSlots].
  MovableSlotsProvider call(
    String id,
    String date,
    int partySize,
  ) {
    return MovableSlotsProvider(
      id,
      date,
      partySize,
    );
  }

  @override
  MovableSlotsProvider getProviderOverride(
    covariant MovableSlotsProvider provider,
  ) {
    return call(
      provider.id,
      provider.date,
      provider.partySize,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'movableSlotsProvider';
}

/// The grid for the move sheet.
///
/// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
/// its own tables count as free, so the times either side of the current
/// booking are offered. See the repository note.
///
/// Copied from [movableSlots].
class MovableSlotsProvider extends AutoDisposeFutureProvider<SlotBoard> {
  /// The grid for the move sheet.
  ///
  /// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
  /// its own tables count as free, so the times either side of the current
  /// booking are offered. See the repository note.
  ///
  /// Copied from [movableSlots].
  MovableSlotsProvider(
    String id,
    String date,
    int partySize,
  ) : this._internal(
          (ref) => movableSlots(
            ref as MovableSlotsRef,
            id,
            date,
            partySize,
          ),
          from: movableSlotsProvider,
          name: r'movableSlotsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$movableSlotsHash,
          dependencies: MovableSlotsFamily._dependencies,
          allTransitiveDependencies: MovableSlotsFamily._allTransitiveDependencies,
          id: id,
          date: date,
          partySize: partySize,
        );

  MovableSlotsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.date,
    required this.partySize,
  }) : super.internal();

  final String id;
  final String date;
  final int partySize;

  @override
  Override overrideWith(
    FutureOr<SlotBoard> Function(MovableSlotsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MovableSlotsProvider._internal(
        (ref) => create(ref as MovableSlotsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        date: date,
        partySize: partySize,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<SlotBoard> createElement() {
    return _MovableSlotsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MovableSlotsProvider &&
        other.id == id &&
        other.date == date &&
        other.partySize == partySize;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);
    hash = _SystemHash.combine(hash, partySize.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MovableSlotsRef on AutoDisposeFutureProviderRef<SlotBoard> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `date` of this provider.
  String get date;

  /// The parameter `partySize` of this provider.
  int get partySize;
}

class _MovableSlotsProviderElement extends AutoDisposeFutureProviderElement<SlotBoard>
    with MovableSlotsRef {
  _MovableSlotsProviderElement(super.provider);

  @override
  String get id => (origin as MovableSlotsProvider).id;
  @override
  String get date => (origin as MovableSlotsProvider).date;
  @override
  int get partySize => (origin as MovableSlotsProvider).partySize;
}

String _$bookingsViewHash() => r'369a1c7c7790862f66c51d4e5fba53b4be17c48b';

/// Which half of the bookings screen is showing.
///
/// Copied from [BookingsView].
@ProviderFor(BookingsView)
final bookingsViewProvider = AutoDisposeNotifierProvider<BookingsView, String>.internal(
  BookingsView.new,
  name: r'bookingsViewProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bookingsViewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BookingsView = AutoDisposeNotifier<String>;
String _$acknowledgeCancellationHash() => r'6f9c2c39f8e474fd6f3e2065ab379d0f60629692';

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
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$acknowledgeCancellationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AcknowledgeCancellation = AutoDisposeNotifier<bool>;
String _$moveDraftHash() => r'0db97d9236f9bd5fdf9965b892027c8247bfb548';

abstract class _$MoveDraft extends BuildlessAutoDisposeNotifier<MoveSelection> {
  late final String id;
  late final String date;
  late final int partySize;

  MoveSelection build(
    String id,
    String date,
    int partySize,
  );
}

/// See also [MoveDraft].
@ProviderFor(MoveDraft)
const moveDraftProvider = MoveDraftFamily();

/// See also [MoveDraft].
class MoveDraftFamily extends Family<MoveSelection> {
  /// See also [MoveDraft].
  const MoveDraftFamily();

  /// See also [MoveDraft].
  MoveDraftProvider call(
    String id,
    String date,
    int partySize,
  ) {
    return MoveDraftProvider(
      id,
      date,
      partySize,
    );
  }

  @override
  MoveDraftProvider getProviderOverride(
    covariant MoveDraftProvider provider,
  ) {
    return call(
      provider.id,
      provider.date,
      provider.partySize,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'moveDraftProvider';
}

/// See also [MoveDraft].
class MoveDraftProvider extends AutoDisposeNotifierProviderImpl<MoveDraft, MoveSelection> {
  /// See also [MoveDraft].
  MoveDraftProvider(
    String id,
    String date,
    int partySize,
  ) : this._internal(
          () => MoveDraft()
            ..id = id
            ..date = date
            ..partySize = partySize,
          from: moveDraftProvider,
          name: r'moveDraftProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$moveDraftHash,
          dependencies: MoveDraftFamily._dependencies,
          allTransitiveDependencies: MoveDraftFamily._allTransitiveDependencies,
          id: id,
          date: date,
          partySize: partySize,
        );

  MoveDraftProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.date,
    required this.partySize,
  }) : super.internal();

  final String id;
  final String date;
  final int partySize;

  @override
  MoveSelection runNotifierBuild(
    covariant MoveDraft notifier,
  ) {
    return notifier.build(
      id,
      date,
      partySize,
    );
  }

  @override
  Override overrideWith(MoveDraft Function() create) {
    return ProviderOverride(
      origin: this,
      override: MoveDraftProvider._internal(
        () => create()
          ..id = id
          ..date = date
          ..partySize = partySize,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        date: date,
        partySize: partySize,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<MoveDraft, MoveSelection> createElement() {
    return _MoveDraftProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MoveDraftProvider &&
        other.id == id &&
        other.date == date &&
        other.partySize == partySize;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);
    hash = _SystemHash.combine(hash, partySize.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MoveDraftRef on AutoDisposeNotifierProviderRef<MoveSelection> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `date` of this provider.
  String get date;

  /// The parameter `partySize` of this provider.
  int get partySize;
}

class _MoveDraftProviderElement extends AutoDisposeNotifierProviderElement<MoveDraft, MoveSelection>
    with MoveDraftRef {
  _MoveDraftProviderElement(super.provider);

  @override
  String get id => (origin as MoveDraftProvider).id;
  @override
  String get date => (origin as MoveDraftProvider).date;
  @override
  int get partySize => (origin as MoveDraftProvider).partySize;
}

String _$reservationActionHash() => r'aa4ebe4300133ff11dc782935a763e2bfdc58fa4';

abstract class _$ReservationAction extends BuildlessAutoDisposeNotifier<ReservationActionState> {
  late final String id;

  ReservationActionState build(
    String id,
  );
}

/// Cancel and modify for one reservation (C-3.4, C-3.5).
///
/// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
/// thing that actually needs coordinating: while either is in flight, neither
/// button may be tapped. Two notifiers would each know only their own half.
///
/// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
/// was cancelled or moved is wrong in both places, and the list is the screen
/// the diner returns to — leaving it stale shows the old time on the card they
/// just changed, which reads as the change having failed.
///
/// Copied from [ReservationAction].
@ProviderFor(ReservationAction)
const reservationActionProvider = ReservationActionFamily();

/// Cancel and modify for one reservation (C-3.4, C-3.5).
///
/// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
/// thing that actually needs coordinating: while either is in flight, neither
/// button may be tapped. Two notifiers would each know only their own half.
///
/// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
/// was cancelled or moved is wrong in both places, and the list is the screen
/// the diner returns to — leaving it stale shows the old time on the card they
/// just changed, which reads as the change having failed.
///
/// Copied from [ReservationAction].
class ReservationActionFamily extends Family<ReservationActionState> {
  /// Cancel and modify for one reservation (C-3.4, C-3.5).
  ///
  /// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
  /// thing that actually needs coordinating: while either is in flight, neither
  /// button may be tapped. Two notifiers would each know only their own half.
  ///
  /// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
  /// was cancelled or moved is wrong in both places, and the list is the screen
  /// the diner returns to — leaving it stale shows the old time on the card they
  /// just changed, which reads as the change having failed.
  ///
  /// Copied from [ReservationAction].
  const ReservationActionFamily();

  /// Cancel and modify for one reservation (C-3.4, C-3.5).
  ///
  /// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
  /// thing that actually needs coordinating: while either is in flight, neither
  /// button may be tapped. Two notifiers would each know only their own half.
  ///
  /// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
  /// was cancelled or moved is wrong in both places, and the list is the screen
  /// the diner returns to — leaving it stale shows the old time on the card they
  /// just changed, which reads as the change having failed.
  ///
  /// Copied from [ReservationAction].
  ReservationActionProvider call(
    String id,
  ) {
    return ReservationActionProvider(
      id,
    );
  }

  @override
  ReservationActionProvider getProviderOverride(
    covariant ReservationActionProvider provider,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'reservationActionProvider';
}

/// Cancel and modify for one reservation (C-3.4, C-3.5).
///
/// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
/// thing that actually needs coordinating: while either is in flight, neither
/// button may be tapped. Two notifiers would each know only their own half.
///
/// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
/// was cancelled or moved is wrong in both places, and the list is the screen
/// the diner returns to — leaving it stale shows the old time on the card they
/// just changed, which reads as the change having failed.
///
/// Copied from [ReservationAction].
class ReservationActionProvider
    extends AutoDisposeNotifierProviderImpl<ReservationAction, ReservationActionState> {
  /// Cancel and modify for one reservation (C-3.4, C-3.5).
  ///
  /// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
  /// thing that actually needs coordinating: while either is in flight, neither
  /// button may be tapped. Two notifiers would each know only their own half.
  ///
  /// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
  /// was cancelled or moved is wrong in both places, and the list is the screen
  /// the diner returns to — leaving it stale shows the old time on the card they
  /// just changed, which reads as the change having failed.
  ///
  /// Copied from [ReservationAction].
  ReservationActionProvider(
    String id,
  ) : this._internal(
          () => ReservationAction()..id = id,
          from: reservationActionProvider,
          name: r'reservationActionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$reservationActionHash,
          dependencies: ReservationActionFamily._dependencies,
          allTransitiveDependencies: ReservationActionFamily._allTransitiveDependencies,
          id: id,
        );

  ReservationActionProvider._internal(
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
  ReservationActionState runNotifierBuild(
    covariant ReservationAction notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(ReservationAction Function() create) {
    return ProviderOverride(
      origin: this,
      override: ReservationActionProvider._internal(
        () => create()..id = id,
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
  AutoDisposeNotifierProviderElement<ReservationAction, ReservationActionState> createElement() {
    return _ReservationActionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationActionProvider && other.id == id;
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
mixin ReservationActionRef on AutoDisposeNotifierProviderRef<ReservationActionState> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ReservationActionProviderElement
    extends AutoDisposeNotifierProviderElement<ReservationAction, ReservationActionState>
    with ReservationActionRef {
  _ReservationActionProviderElement(super.provider);

  @override
  String get id => (origin as ReservationActionProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
