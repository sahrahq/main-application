// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transportHash() => r'742439b3285e2d199aed3cdac621afc97802d6a6';

/// See also [transport].
@ProviderFor(transport)
final transportProvider = Provider<SahraTransport>.internal(
  transport,
  name: r'transportProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$transportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransportRef = ProviderRef<SahraTransport>;
String _$apiHash() => r'98b5a14285245530a853ed912d943c4f554bdedc';

/// See also [api].
@ProviderFor(api)
final apiProvider = Provider<SahraApi>.internal(
  api,
  name: r'apiProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$apiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiRef = ProviderRef<SahraApi>;
String _$restaurantRepositoryHash() =>
    r'cb74a0e174d00e7b1bfffb9a29b2ced36374c89b';

/// See also [restaurantRepository].
@ProviderFor(restaurantRepository)
final restaurantRepositoryProvider = Provider<RestaurantRepository>.internal(
  restaurantRepository,
  name: r'restaurantRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$restaurantRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RestaurantRepositoryRef = ProviderRef<RestaurantRepository>;
String _$reservationRepositoryHash() =>
    r'61fa83a8fc4b81d850a289d861af709d08bdf495';

/// See also [reservationRepository].
@ProviderFor(reservationRepository)
final reservationRepositoryProvider = Provider<ReservationRepository>.internal(
  reservationRepository,
  name: r'reservationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reservationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReservationRepositoryRef = ProviderRef<ReservationRepository>;
String _$authRepositoryHash() => r'e6f240d03549047f8f0b9cb1bab6b84f53e8d57e';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = Provider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = ProviderRef<AuthRepository>;
String _$todayHash() => r'8e8ccdab51e5893dad840fc8792f3e279bb1b541';

/// Today, as the app should treat it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// A PROVIDER RATHER THAN A CLOCK READ INSIDE A WIDGET
/// ─────────────────────────────────────────────────────────────────────────
///
/// Two screens build a seven-day strip starting from today. Read straight from
/// the system clock, that makes their pictures change every night — a golden
/// holding "8 9 10 11 12" is wrong by morning, and the failure it produces
/// says nothing at all about the code that changed.
///
/// The move sheet caught it, on its first golden. The BOOKING screen has had
/// the same widget since wave 3 and its golden never noticed, because at
/// 390x844 the date strip sits below the fold — the picture happened not to
/// contain the thing that varies. That is luck, not determinism, and luck is
/// what this replaces.
///
/// Overridden to a fixed day in `screen_registry.dart`. In the app it is the
/// real clock.
///
/// Copied from [today].
@ProviderFor(today)
final todayProvider = AutoDisposeProvider<DateTime>.internal(
  today,
  name: r'todayProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$todayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayRef = AutoDisposeProviderRef<DateTime>;
String _$localeCodeHash() => r'9d9845147b7afe5c7f5ad2ae0545e0a69164a680';

/// The active locale, as a language code.
///
/// A provider rather than a `BuildContext` read, because the transport and the
/// repositories both need it and neither has a context. Kept in step with the
/// widget tree by [LocaleSync], so there is exactly one answer in the app at
/// any moment — an app whose UI renders Arabic while asking the API for
/// English is a bug nobody notices until a venue name comes back wrong.
///
/// Copied from [LocaleCode].
@ProviderFor(LocaleCode)
final localeCodeProvider = NotifierProvider<LocaleCode, String>.internal(
  LocaleCode.new,
  name: r'localeCodeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$localeCodeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocaleCode = Notifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
