import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sahra_api_client/sahra_api_client.dart';

import '../providers/app_providers.dart';
import '../providers/session_providers.dart';
import 'push_token_source.dart';
import 'push_taps.dart';

part 'push_registration.g.dart';

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
@Riverpod(keepAlive: true)
class PushRegistrar extends _$PushRegistrar {
  @override
  bool build() => false;

  /// Ask, and register the token if the diner agrees.
  ///
  /// **Never throws and never blocks anything.** Its caller is a diner who has
  /// just booked a table; a failure here must not colour that moment, and the
  /// booking is already committed.
  Future<void> askAfterBooking() async {
    if (state) return; // one ask per app run, whatever happens
    state = true;

    final source = ref.read(pushTokenSourceProvider);

    // ONLY WHEN IT HAS NEVER BEEN ASKED. A diner who said no is not asked
    // again: the OS will not show the dialog a second time, so a retry is a
    // no-op that looks to us like a refusal and to them like nothing at all.
    if (await source.permission() != PushPermission.notDetermined) {
      // Already granted from a previous run? Then make sure the token is
      // registered — a reinstall or a token rotation would otherwise leave a
      // diner who HAS agreed unreachable.
      await syncExistingToken();
      return;
    }

    final registration = await source.request();
    if (!registration.canRegister) return;
    await _register(registration.token!);
  }

  /// Register a token the diner has already agreed to, without asking anything.
  ///
  /// **This docblock claimed "called on sign-in and at launch" and NOTHING
  /// CALLED IT** — the only caller was `askAfterBooking`, so a diner who had
  /// already granted permission was never re-registered, and the retry below
  /// could never run on a later launch. Found 2026-08-11 while wiring that
  /// retry; the sentence describing two callers had outlived having any. It is
  /// now called from `PushTapListener`, which is the one widget that runs once
  /// per launch above every screen — and `docblockCallerClaims` now refuses a
  /// docblock that claims a caller without naming one that really calls it.
  ///
  /// FCM rotates tokens
  /// — on reinstall, on restore-from-backup, occasionally on its own — and a
  /// rotated token that nobody re-registers is a diner who silently stops
  /// receiving anything. The server upsert makes this cheap to repeat.
  Future<void> syncExistingToken() async {
    if (ref.read(currentSessionProvider) == null) return;
    final token = await ref.read(pushTokenSourceProvider).currentToken();

    // ── A DEVICE WITH NO TOKEN KEEPS TRYING, QUIETLY ────────────────────────
    //
    // This early return is what turned a transient failure into a permanent
    // one. `currentToken()` now retries with backoff for about two minutes,
    // but a handset that was offline for the whole of that window still ends
    // the run with nothing — and before today, nothing ever asked again.
    //
    // So the failure is REMEMBERED. `_tokenPending` is set here and read by
    // the account screen, which is the only place a diner (or the product
    // owner, without a cable) can see that notifications are on and this phone
    // is still not registered. The next launch calls this again and the state
    // clears itself the moment a token arrives.
    //
    // Deliberately NOT an error surfaced over a screen they did not ask about:
    // a diner who just booked a table should not be told about a background
    // registration problem they cannot act on.
    if (token == null || token.isEmpty) {
      state = state; // no-op; kept explicit so the branch is not mistaken for dead
      ref.read(pushTokenPendingProvider.notifier).state = true;
      return;
    }
    ref.read(pushTokenPendingProvider.notifier).state = false;
    await _register(token);
  }

  Future<void> _register(String token) async {
    try {
      await ref.read(apiProvider).registerDevice(
            body: RegisterDeviceDto(
              token: token,
              platform: _platform(),
              // The DEVICE's language, which is not necessarily the account's.
              // A push is drawn by the OS on a lock screen with no client
              // running, so the server picks the language and it has to be the
              // one on this handset.
              locale: ref.read(localeCodeProvider),
            ),
          );
    } catch (e) {
      // A diner whose token failed to register still has the in-app centre.
      // Surfacing this would be reporting a background failure over a screen
      // they did not ask about.
      debugPrint('Device registration failed: $e');
    }
  }

  /// Sign-out. **The client MUST call this**, and until today nothing did.
  ///
  /// A token left attached to a signed-out account sends that person's
  /// reservations to whoever holds the handset next. `DevicesService.revoke`
  /// has refused to work without both the token and the user since Stage 1,
  /// which is what makes calling it safe rather than a way to silence somebody.
  Future<void> revokeOnSignOut() async {
    try {
      final token = await ref.read(pushTokenSourceProvider).currentToken();
      if (token == null || token.isEmpty) return;
      await ref.read(apiProvider).revoke(body: RevokeDeviceDto(token: token));
    } catch (e) {
      debugPrint('Device revoke failed: $e');
    } finally {
      // Allow one ask again on the next sign-in — a different person may be
      // holding this handset now.
      state = false;
    }
  }

  /// ANDROID OR IOS, never guessed from `defaultTargetPlatform` on web.
  ///
  /// The server refuses anything outside its enum, and `web` is deliberately
  /// out of scope (doc 02 — iOS and Android only). Flutter Web is how this app
  /// is developed locally, and it must not register a device there: a token it
  /// cannot get, for a platform the server will not deliver to.
  String _platform() {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }
}

@Riverpod(keepAlive: true)
PushTokenSource pushTokenSource(Ref ref) => const FirebasePushTokenSource();

/// The tap channel. Overridden in tests with `FakePushTaps`, for the same
/// reason `pushTokenSource` is — `FirebaseMessaging` is a platform channel and
/// is not there on a test runner.
@Riverpod(keepAlive: true)
PushTaps pushTaps(Ref ref) => FirebasePushTaps();

/// TRUE when a signed-in diner has granted permission and this handset still
/// has no registered token.
///
/// The observable half of the retry. Without it, "we stopped trying" and "we
/// succeeded" are indistinguishable from outside the process — which is the
/// state that produced a handset looking registered while the `devices` table
/// was empty.
///
/// Read by the account screen. NOT persisted: it is a fact about this run, and
/// a stale `true` from a previous launch would be worse than no signal.
final pushTokenPendingProvider = StateProvider<bool>((ref) => false);
