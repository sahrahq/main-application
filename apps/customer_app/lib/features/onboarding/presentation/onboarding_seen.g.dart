// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_seen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$onboardingSeenStoreHash() =>
    r'9804d94b9de354680088ba97237027295bda931f';

/// See also [onboardingSeenStore].
@ProviderFor(onboardingSeenStore)
final onboardingSeenStoreProvider = Provider<OnboardingSeenStore>.internal(
  onboardingSeenStore,
  name: r'onboardingSeenStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingSeenStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OnboardingSeenStoreRef = ProviderRef<OnboardingSeenStore>;
String _$onboardingSeenHash() => r'6e23fcbba5b43ab74b969845391e314e00b3cd4b';

/// Null while the answer is still being read from storage.
///
/// THE THREE-STATE IS THE POINT. A bare `false` default would flash onboarding
/// at every returning diner for the frame or two before storage answered —
/// which is worse than showing it, because it looks like a bug rather than a
/// welcome. The router waits for a real answer.
///
/// Copied from [OnboardingSeen].
@ProviderFor(OnboardingSeen)
final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool?>.internal(
  OnboardingSeen.new,
  name: r'onboardingSeenProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingSeenHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$OnboardingSeen = Notifier<bool?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
