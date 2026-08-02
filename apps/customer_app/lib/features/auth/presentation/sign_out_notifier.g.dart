// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$signOutHash() => r'42d7231bc645c36de5838fa5f40874fc1cabbc1d';

/// Signing out. The state is "is it in flight", because that is all a screen
/// needs to know.
///
/// THE LOCAL SESSION IS CLEARED EVEN IF THE SERVER CALL FAILS, and that order
/// is deliberate. A diner who taps sign out on a phone with no signal, or
/// hands the handset to someone, must not still be signed in because a POST
/// timed out. The refresh token is revoked server-side when the call succeeds;
/// when it does not, the token remains valid until it expires — which is the
/// same exposure as a phone that is simply switched off, and strictly less bad
/// than a screen that refuses to log out.
///
/// Copied from [SignOut].
@ProviderFor(SignOut)
final signOutProvider = AutoDisposeNotifierProvider<SignOut, bool>.internal(
  SignOut.new,
  name: r'signOutProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$signOutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SignOut = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
