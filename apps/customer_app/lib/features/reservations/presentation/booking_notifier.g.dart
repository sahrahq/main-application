// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$availableSlotsHash() => r'dd4ec129270640b1a88a647e5e40bb19074471c4';

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

/// The real, bookable slots. NOT search's `next_available`.
///
/// Copied from [availableSlots].
@ProviderFor(availableSlots)
const availableSlotsProvider = AvailableSlotsFamily();

/// The real, bookable slots. NOT search's `next_available`.
///
/// Copied from [availableSlots].
class AvailableSlotsFamily extends Family<AsyncValue<SlotBoard>> {
  /// The real, bookable slots. NOT search's `next_available`.
  ///
  /// Copied from [availableSlots].
  const AvailableSlotsFamily();

  /// The real, bookable slots. NOT search's `next_available`.
  ///
  /// Copied from [availableSlots].
  AvailableSlotsProvider call(
    String restaurantId,
  ) {
    return AvailableSlotsProvider(
      restaurantId,
    );
  }

  @override
  AvailableSlotsProvider getProviderOverride(
    covariant AvailableSlotsProvider provider,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'availableSlotsProvider';
}

/// The real, bookable slots. NOT search's `next_available`.
///
/// Copied from [availableSlots].
class AvailableSlotsProvider extends AutoDisposeFutureProvider<SlotBoard> {
  /// The real, bookable slots. NOT search's `next_available`.
  ///
  /// Copied from [availableSlots].
  AvailableSlotsProvider(
    String restaurantId,
  ) : this._internal(
          (ref) => availableSlots(
            ref as AvailableSlotsRef,
            restaurantId,
          ),
          from: availableSlotsProvider,
          name: r'availableSlotsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$availableSlotsHash,
          dependencies: AvailableSlotsFamily._dependencies,
          allTransitiveDependencies: AvailableSlotsFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  AvailableSlotsProvider._internal(
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
  Override overrideWith(
    FutureOr<SlotBoard> Function(AvailableSlotsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AvailableSlotsProvider._internal(
        (ref) => create(ref as AvailableSlotsRef),
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
  AutoDisposeFutureProviderElement<SlotBoard> createElement() {
    return _AvailableSlotsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AvailableSlotsProvider && other.restaurantId == restaurantId;
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
mixin AvailableSlotsRef on AutoDisposeFutureProviderRef<SlotBoard> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _AvailableSlotsProviderElement extends AutoDisposeFutureProviderElement<SlotBoard>
    with AvailableSlotsRef {
  _AvailableSlotsProviderElement(super.provider);

  @override
  String get restaurantId => (origin as AvailableSlotsProvider).restaurantId;
}

String _$bookingSelectionHash() => r'52c30d7699440bb3108117e52aece287b42ccbe7';

abstract class _$BookingSelection extends BuildlessAutoDisposeNotifier<BookingCriteria> {
  late final String restaurantId;

  BookingCriteria build(
    String restaurantId,
  );
}

/// See also [BookingSelection].
@ProviderFor(BookingSelection)
const bookingSelectionProvider = BookingSelectionFamily();

/// See also [BookingSelection].
class BookingSelectionFamily extends Family<BookingCriteria> {
  /// See also [BookingSelection].
  const BookingSelectionFamily();

  /// See also [BookingSelection].
  BookingSelectionProvider call(
    String restaurantId,
  ) {
    return BookingSelectionProvider(
      restaurantId,
    );
  }

  @override
  BookingSelectionProvider getProviderOverride(
    covariant BookingSelectionProvider provider,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'bookingSelectionProvider';
}

/// See also [BookingSelection].
class BookingSelectionProvider
    extends AutoDisposeNotifierProviderImpl<BookingSelection, BookingCriteria> {
  /// See also [BookingSelection].
  BookingSelectionProvider(
    String restaurantId,
  ) : this._internal(
          () => BookingSelection()..restaurantId = restaurantId,
          from: bookingSelectionProvider,
          name: r'bookingSelectionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$bookingSelectionHash,
          dependencies: BookingSelectionFamily._dependencies,
          allTransitiveDependencies: BookingSelectionFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  BookingSelectionProvider._internal(
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
  BookingCriteria runNotifierBuild(
    covariant BookingSelection notifier,
  ) {
    return notifier.build(
      restaurantId,
    );
  }

  @override
  Override overrideWith(BookingSelection Function() create) {
    return ProviderOverride(
      origin: this,
      override: BookingSelectionProvider._internal(
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
  AutoDisposeNotifierProviderElement<BookingSelection, BookingCriteria> createElement() {
    return _BookingSelectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookingSelectionProvider && other.restaurantId == restaurantId;
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
mixin BookingSelectionRef on AutoDisposeNotifierProviderRef<BookingCriteria> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _BookingSelectionProviderElement
    extends AutoDisposeNotifierProviderElement<BookingSelection, BookingCriteria>
    with BookingSelectionRef {
  _BookingSelectionProviderElement(super.provider);

  @override
  String get restaurantId => (origin as BookingSelectionProvider).restaurantId;
}

String _$bookingFlowHash() => r'88309ebf3d36320766b530284ddb7645587119e0';

abstract class _$BookingFlow extends BuildlessAutoDisposeNotifier<BookingProgress> {
  late final String restaurantId;

  BookingProgress build(
    String restaurantId,
  );
}

/// The hold → confirm sequence, the highest-risk logic in the product.
///
/// It lives in a notifier and not in a widget, so it can be unit-tested
/// without a widget tree (doc 07 §4 targets ~100% on the booking state
/// machine) and so `use_build_context_synchronously` has nothing to catch.
///
/// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
/// table off the market for five minutes and the confirm commits it. Between
/// them is where a deposit sheet goes (C-4.1) and where the diner can still
/// walk away.
///
/// Copied from [BookingFlow].
@ProviderFor(BookingFlow)
const bookingFlowProvider = BookingFlowFamily();

/// The hold → confirm sequence, the highest-risk logic in the product.
///
/// It lives in a notifier and not in a widget, so it can be unit-tested
/// without a widget tree (doc 07 §4 targets ~100% on the booking state
/// machine) and so `use_build_context_synchronously` has nothing to catch.
///
/// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
/// table off the market for five minutes and the confirm commits it. Between
/// them is where a deposit sheet goes (C-4.1) and where the diner can still
/// walk away.
///
/// Copied from [BookingFlow].
class BookingFlowFamily extends Family<BookingProgress> {
  /// The hold → confirm sequence, the highest-risk logic in the product.
  ///
  /// It lives in a notifier and not in a widget, so it can be unit-tested
  /// without a widget tree (doc 07 §4 targets ~100% on the booking state
  /// machine) and so `use_build_context_synchronously` has nothing to catch.
  ///
  /// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
  /// table off the market for five minutes and the confirm commits it. Between
  /// them is where a deposit sheet goes (C-4.1) and where the diner can still
  /// walk away.
  ///
  /// Copied from [BookingFlow].
  const BookingFlowFamily();

  /// The hold → confirm sequence, the highest-risk logic in the product.
  ///
  /// It lives in a notifier and not in a widget, so it can be unit-tested
  /// without a widget tree (doc 07 §4 targets ~100% on the booking state
  /// machine) and so `use_build_context_synchronously` has nothing to catch.
  ///
  /// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
  /// table off the market for five minutes and the confirm commits it. Between
  /// them is where a deposit sheet goes (C-4.1) and where the diner can still
  /// walk away.
  ///
  /// Copied from [BookingFlow].
  BookingFlowProvider call(
    String restaurantId,
  ) {
    return BookingFlowProvider(
      restaurantId,
    );
  }

  @override
  BookingFlowProvider getProviderOverride(
    covariant BookingFlowProvider provider,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'bookingFlowProvider';
}

/// The hold → confirm sequence, the highest-risk logic in the product.
///
/// It lives in a notifier and not in a widget, so it can be unit-tested
/// without a widget tree (doc 07 §4 targets ~100% on the booking state
/// machine) and so `use_build_context_synchronously` has nothing to catch.
///
/// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
/// table off the market for five minutes and the confirm commits it. Between
/// them is where a deposit sheet goes (C-4.1) and where the diner can still
/// walk away.
///
/// Copied from [BookingFlow].
class BookingFlowProvider extends AutoDisposeNotifierProviderImpl<BookingFlow, BookingProgress> {
  /// The hold → confirm sequence, the highest-risk logic in the product.
  ///
  /// It lives in a notifier and not in a widget, so it can be unit-tested
  /// without a widget tree (doc 07 §4 targets ~100% on the booking state
  /// machine) and so `use_build_context_synchronously` has nothing to catch.
  ///
  /// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
  /// table off the market for five minutes and the confirm commits it. Between
  /// them is where a deposit sheet goes (C-4.1) and where the diner can still
  /// walk away.
  ///
  /// Copied from [BookingFlow].
  BookingFlowProvider(
    String restaurantId,
  ) : this._internal(
          () => BookingFlow()..restaurantId = restaurantId,
          from: bookingFlowProvider,
          name: r'bookingFlowProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$bookingFlowHash,
          dependencies: BookingFlowFamily._dependencies,
          allTransitiveDependencies: BookingFlowFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  BookingFlowProvider._internal(
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
  BookingProgress runNotifierBuild(
    covariant BookingFlow notifier,
  ) {
    return notifier.build(
      restaurantId,
    );
  }

  @override
  Override overrideWith(BookingFlow Function() create) {
    return ProviderOverride(
      origin: this,
      override: BookingFlowProvider._internal(
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
  AutoDisposeNotifierProviderElement<BookingFlow, BookingProgress> createElement() {
    return _BookingFlowProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookingFlowProvider && other.restaurantId == restaurantId;
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
mixin BookingFlowRef on AutoDisposeNotifierProviderRef<BookingProgress> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _BookingFlowProviderElement
    extends AutoDisposeNotifierProviderElement<BookingFlow, BookingProgress> with BookingFlowRef {
  _BookingFlowProviderElement(super.provider);

  @override
  String get restaurantId => (origin as BookingFlowProvider).restaurantId;
}

String _$chosenSlotHash() => r'7b9fb6dd050c28d777a0e1e52225a90ed3e74665';

abstract class _$ChosenSlot extends BuildlessAutoDisposeNotifier<String?> {
  late final String restaurantId;

  String? build(
    String restaurantId,
  );
}

/// Which slot the diner has tapped, as an absolute `startsAt`.
///
/// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
/// survives a refresh that reorders the board and so nothing downstream can
/// accidentally send a wall-clock string to the booking engine.
///
/// Cleared whenever the date or party size changes: a 21:00 chosen for
/// Thursday is not a 21:00 for Friday, and leaving it selected across the
/// change is how a diner books the wrong night.
///
/// Copied from [ChosenSlot].
@ProviderFor(ChosenSlot)
const chosenSlotProvider = ChosenSlotFamily();

/// Which slot the diner has tapped, as an absolute `startsAt`.
///
/// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
/// survives a refresh that reorders the board and so nothing downstream can
/// accidentally send a wall-clock string to the booking engine.
///
/// Cleared whenever the date or party size changes: a 21:00 chosen for
/// Thursday is not a 21:00 for Friday, and leaving it selected across the
/// change is how a diner books the wrong night.
///
/// Copied from [ChosenSlot].
class ChosenSlotFamily extends Family<String?> {
  /// Which slot the diner has tapped, as an absolute `startsAt`.
  ///
  /// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
  /// survives a refresh that reorders the board and so nothing downstream can
  /// accidentally send a wall-clock string to the booking engine.
  ///
  /// Cleared whenever the date or party size changes: a 21:00 chosen for
  /// Thursday is not a 21:00 for Friday, and leaving it selected across the
  /// change is how a diner books the wrong night.
  ///
  /// Copied from [ChosenSlot].
  const ChosenSlotFamily();

  /// Which slot the diner has tapped, as an absolute `startsAt`.
  ///
  /// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
  /// survives a refresh that reorders the board and so nothing downstream can
  /// accidentally send a wall-clock string to the booking engine.
  ///
  /// Cleared whenever the date or party size changes: a 21:00 chosen for
  /// Thursday is not a 21:00 for Friday, and leaving it selected across the
  /// change is how a diner books the wrong night.
  ///
  /// Copied from [ChosenSlot].
  ChosenSlotProvider call(
    String restaurantId,
  ) {
    return ChosenSlotProvider(
      restaurantId,
    );
  }

  @override
  ChosenSlotProvider getProviderOverride(
    covariant ChosenSlotProvider provider,
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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'chosenSlotProvider';
}

/// Which slot the diner has tapped, as an absolute `startsAt`.
///
/// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
/// survives a refresh that reorders the board and so nothing downstream can
/// accidentally send a wall-clock string to the booking engine.
///
/// Cleared whenever the date or party size changes: a 21:00 chosen for
/// Thursday is not a 21:00 for Friday, and leaving it selected across the
/// change is how a diner books the wrong night.
///
/// Copied from [ChosenSlot].
class ChosenSlotProvider extends AutoDisposeNotifierProviderImpl<ChosenSlot, String?> {
  /// Which slot the diner has tapped, as an absolute `startsAt`.
  ///
  /// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
  /// survives a refresh that reorders the board and so nothing downstream can
  /// accidentally send a wall-clock string to the booking engine.
  ///
  /// Cleared whenever the date or party size changes: a 21:00 chosen for
  /// Thursday is not a 21:00 for Friday, and leaving it selected across the
  /// change is how a diner books the wrong night.
  ///
  /// Copied from [ChosenSlot].
  ChosenSlotProvider(
    String restaurantId,
  ) : this._internal(
          () => ChosenSlot()..restaurantId = restaurantId,
          from: chosenSlotProvider,
          name: r'chosenSlotProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$chosenSlotHash,
          dependencies: ChosenSlotFamily._dependencies,
          allTransitiveDependencies: ChosenSlotFamily._allTransitiveDependencies,
          restaurantId: restaurantId,
        );

  ChosenSlotProvider._internal(
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
  String? runNotifierBuild(
    covariant ChosenSlot notifier,
  ) {
    return notifier.build(
      restaurantId,
    );
  }

  @override
  Override overrideWith(ChosenSlot Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChosenSlotProvider._internal(
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
  AutoDisposeNotifierProviderElement<ChosenSlot, String?> createElement() {
    return _ChosenSlotProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChosenSlotProvider && other.restaurantId == restaurantId;
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
mixin ChosenSlotRef on AutoDisposeNotifierProviderRef<String?> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _ChosenSlotProviderElement extends AutoDisposeNotifierProviderElement<ChosenSlot, String?>
    with ChosenSlotRef {
  _ChosenSlotProviderElement(super.provider);

  @override
  String get restaurantId => (origin as ChosenSlotProvider).restaurantId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
