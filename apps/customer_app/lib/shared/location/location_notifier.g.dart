// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$locationSourceHash() => r'e937c5fa89506eb97b74a283d61d18744f9083ba';

/// The plugin, behind its port. Overridden in every test.
///
/// Copied from [locationSource].
@ProviderFor(locationSource)
final locationSourceProvider = Provider<LocationSource>.internal(
  locationSource,
  name: r'locationSourceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$locationSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocationSourceRef = ProviderRef<LocationSource>;
String _$dinerLocationHash() => r'6ade8d8382ac2f22d3e47c4bb10166d194f9b9b2';

/// The diner's position for this session, or the reason there isn't one.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NULL UNTIL ASKED, AND ASKED ONLY BY A TAP
/// ─────────────────────────────────────────────────────────────────────────
///
/// The initial state is "we have not asked", not "we are asking". Building
/// this provider must never raise a permission dialog — a provider is
/// constructed by whatever reads it first, which is not a decision a diner
/// made.
///
/// So the dialog is raised by exactly one call, [request], wired to exactly
/// one control: the "near me" toggle in the filter sheet. That is the
/// agreement — *"I don't want a permission prompt in the app before there's a
/// reason for one"* — expressed as code rather than as a convention somebody
/// has to remember.
///
/// ── AND IT IS NOT PERSISTED ──────────────────────────────────────────────
///
/// `keepAlive` so it survives the sheet closing, and nothing more. A position
/// written to storage would be a stale answer to "where are you" on the next
/// launch, in a city where a diner's evening plans move them ten kilometres.
///
/// Copied from [DinerLocation].
@ProviderFor(DinerLocation)
final dinerLocationProvider = NotifierProvider<DinerLocation, LocationResult?>.internal(
  DinerLocation.new,
  name: r'dinerLocationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dinerLocationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DinerLocation = Notifier<LocationResult?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
