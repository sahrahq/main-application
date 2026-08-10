// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_registration.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pushTokenSourceHash() => r'89c886ec1219ba2bf4fa9874a9e7c945b8aa0f02';

/// See also [pushTokenSource].
@ProviderFor(pushTokenSource)
final pushTokenSourceProvider = Provider<PushTokenSource>.internal(
  pushTokenSource,
  name: r'pushTokenSourceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$pushTokenSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushTokenSourceRef = ProviderRef<PushTokenSource>;
String _$pushTapsHash() => r'049e59e2c7454177dcedce59dde726d83275ae71';

/// The tap channel. Overridden in tests with `FakePushTaps`, for the same
/// reason `pushTokenSource` is — `FirebaseMessaging` is a platform channel and
/// is not there on a test runner.
///
/// Copied from [pushTaps].
@ProviderFor(pushTaps)
final pushTapsProvider = Provider<PushTaps>.internal(
  pushTaps,
  name: r'pushTapsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product') ? null : _$pushTapsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushTapsRef = ProviderRef<PushTaps>;
String _$pushRegistrarHash() => r'904c1b2a251c339be2aa90f9441299bc09224ae0';

/// `POST /devices` and `DELETE /devices` FINALLY HAVE A CALLER.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THEY WERE BUILT, TESTED AND UNCALLED FOR EIGHT DAYS
/// ─────────────────────────────────────────────────────────────────────────
///
/// Both endpoints shipped with NOTIFY-1 Stage 1 on 2026-08-02 and nothing ever
/// called either of them, because there was no token to send. That is the exact
/// state `ENGINEERING-STANDARDS` names — *a capability that is never called is
/// indistinguishable from one that does not exist* — and it lasted right up to
/// the moment the adapter was bound.
///
/// It matters more than usual here. Binding the FCM adapter on the server makes
/// push POSSIBLE; it delivers nothing at all until a handset has registered a
/// token. **Deleting the in-app "we can't alert your phone yet" notice without
/// this file would have replaced a true statement with a false one.**
///
/// ── WHEN THE PERMISSION IS ASKED ─────────────────────────────────────────
///
/// **After a diner confirms their first booking, and nowhere else.** doc 11 §1:
/// asked with context, never on cold open. At that moment the sentence writes
/// itself — "so we can remind you before your reservation" — and the diner has
/// something to be reminded about.
///
/// Not on launch: a booking app that asks before showing anything gets denied,
/// and a denial is the one state the app cannot undo.
/// Not on sign-in: signing in is not a reason to want notifications.
/// Not on opening the notification centre: somebody who navigated there is
/// already looking at the thing they would be told about.
///
/// `push_test.dart` counts the asks and requires zero for every other path.
///
/// Copied from [PushRegistrar].
@ProviderFor(PushRegistrar)
final pushRegistrarProvider = NotifierProvider<PushRegistrar, bool>.internal(
  PushRegistrar.new,
  name: r'pushRegistrarProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$pushRegistrarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PushRegistrar = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
