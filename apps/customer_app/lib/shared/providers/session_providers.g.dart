// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionStoreHash() => r'5a49f5228fb9878d3419b834a927a4c33c4d8016';

/// Where the session is persisted. Overridden in tests with the in-memory
/// store, so no test ever reaches a keystore.
///
/// Copied from [sessionStore].
@ProviderFor(sessionStore)
final sessionStoreProvider = Provider<SessionStore>.internal(
  sessionStore,
  name: r'sessionStoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sessionStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SessionStoreRef = ProviderRef<SessionStore>;
String _$isSignedInHash() => r'3f68e576b8b40b14df4cd2c12eeaa265972fa07e';

/// Convenience for widgets that only care whether anyone is signed in.
///
/// Copied from [isSignedIn].
@ProviderFor(isSignedIn)
final isSignedInProvider = AutoDisposeProvider<bool>.internal(
  isSignedIn,
  name: r'isSignedInProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isSignedInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsSignedInRef = AutoDisposeProviderRef<bool>;
String _$currentSessionHash() => r'29d2de4ca9368908a64ed96524bc657a86a17df0';

/// The signed-in diner, or null.
///
/// `keepAlive`, because it is read by the transport on every request and by
/// three screens; an auto-disposing session would sign the diner out whenever
/// the last watcher was rebuilt.
///
/// The initial read from storage is DELIBERATELY not awaited into the state
/// type. `build()` returns null and then fills in: the alternative is an
/// `AsyncValue<Session?>` that every caller has to unwrap, including the
/// transport, which has no widget tree to show a spinner in. A request made in
/// the first frames goes out unauthenticated and gets a 401, which is the same
/// path a genuinely expired token takes and is therefore already handled.
///
/// Copied from [CurrentSession].
@ProviderFor(CurrentSession)
final currentSessionProvider =
    NotifierProvider<CurrentSession, Session?>.internal(
  CurrentSession.new,
  name: r'currentSessionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentSessionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentSession = Notifier<Session?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
