import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// THE HANDSET'S PUSH ADDRESS — asked for once, and only after we have earned it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SCOPE THIS RUNS UNDER
/// ─────────────────────────────────────────────────────────────────────────
///
/// `firebase_messaging` was approved on 2026-08-10 as the third platform plugin
/// after `url_launcher` and `geolocator`. The scope is written here rather than
/// only in doc 08, because this file is what the next capability will copy —
/// the same reason `LocationSource` carries its own.
///
///   · **FCM ONLY.** No Firestore, no Firebase Auth, no Analytics, no
///     Crashlytics. doc 08 §88 rejects the first two outright and the other two
///     are a separate decision with a separate consent conversation.
///   · **THE PERMISSION IS ASKED WITH CONTEXT, NEVER ON COLD OPEN.** doc 11 §1:
///     "asked with context ('so we can remind you before your reservation'),
///     not immediately on app open — asking cold gets rejected more." On iOS
///     you get exactly one chance; on Android 13+ the same is effectively true
///     once somebody taps "don't allow" twice. **A permanent denial is the one
///     state we cannot undo from inside the app.**
///   · **NO TOKEN WITHOUT A SESSION.** A push address is only useful attached
///     to an account, and `POST /devices` requires one. Registering before
///     sign-in would be collecting a device identifier from somebody who has
///     not agreed to anything.
///   · **REVOKED ON SIGN-OUT.** A token left live sends the next
///     notification to whoever holds the handset — on a shared or resold phone
///     that is a privacy incident, not an annoyance. The server has enforced
///     this since Stage 1; this is the client half finally calling it.
///
/// ── AND WHY IT IS A PORT ─────────────────────────────────────────────────
///
/// `FirebaseMessaging.instance` is a platform channel. On a test runner it is
/// not there, so a widget touching it directly would make every golden,
/// viewport and accessibility case either throw or hang — exactly what
/// `LocationSource` was created to prevent, and for exactly the same reason.
///
/// It also means the interesting states — refused, not-determined, no Google
/// Play Services — are values a test can produce rather than platform
/// conditions a test cannot.
enum PushPermission {
  /// The diner said yes. A token can be fetched.
  granted,

  /// Not asked yet. The only state in which asking is allowed.
  notDetermined,

  /// Said no. **Do not ask again from here** — the OS will not show the dialog
  /// a second time, so a retry is a no-op that looks like a bug. Settings is
  /// the only way back and the app should say so rather than pretending.
  denied,

  /// No Google Play Services, an emulator without them, or Firebase not
  /// initialised. Not the diner's decision, and not recoverable by asking.
  unavailable,
}

class PushRegistration {
  const PushRegistration({required this.permission, this.token});

  final PushPermission permission;

  /// Null unless [permission] is [PushPermission.granted] — and possibly null
  /// even then: FCM can fail to mint one on a device with no network.
  final String? token;

  bool get canRegister => token != null && token!.isNotEmpty;
}

abstract class PushTokenSource {
  /// The current permission, WITHOUT asking for it.
  ///
  /// Separate from [request] on purpose. Every caller that needs to know
  /// whether to show a prompt must be able to ask that question without
  /// triggering the prompt as a side effect — the same split
  /// `LocationSource` uses, and the reason its "we never ask unprompted"
  /// counter can be asserted at all.
  Future<PushPermission> permission();

  /// Ask the diner, then fetch a token if they agreed.
  ///
  /// ONLY EVER CALLED FROM A PLACE WHERE THE DINER HAS JUST DONE SOMETHING
  /// THAT MAKES IT MAKE SENSE. See `push_registration.dart` for the single
  /// call site and `push_test.dart` for the counter that keeps it single.
  Future<PushRegistration> request();

  /// The current token without asking for anything. Null when not granted.
  Future<String?> currentToken();
}

/// The real one. The only importer of `firebase_messaging`.
/// Retryable FCM failures, by the substring their message carries.
///
/// ── WHY A SINGLE ATTEMPT WAS A DEFECT ────────────────────────────────────
///
/// Measured on a real Xiaomi handset, 2026-08-11:
///
///     Push token read failed: [firebase_messaging/unknown]
///     java.io.IOException: SERVICE_NOT_AVAILABLE
///
/// Google documents `SERVICE_NOT_AVAILABLE` as TRANSIENT and prescribes retry
/// with exponential backoff. We tried exactly once and gave up, which turns a
/// temporary condition into a PERMANENT one for that install: a diner whose
/// first token fetch lands on a bad moment never registers, ever, and nothing
/// tells anyone — the request never reaches the server, so there is no row to
/// be missing and no error to count.
///
/// Matched on the message rather than a code because the plugin surfaces the
/// platform exception as `[firebase_messaging/unknown]` with the real cause in
/// the text; there is no typed error to switch on.
const List<String> _retryableFcm = <String>[
  'SERVICE_NOT_AVAILABLE',
  'INTERNAL_SERVER_ERROR',
  'TOO_MANY_REGISTRATIONS',
  'AUTHENTICATION_FAILED', // transient at the GCM layer, not a config error
  'Unable to resolve host',
  'timeout',
  'timed out',
];

/// Exported so the classification can be asserted directly. The BACKOFF is a
/// judgement call; WHICH failures are retried is a contract, and the two
/// belong in different places for that reason.
bool isRetryableFcmError(Object e) {
  final String m = e.toString();
  return _retryableFcm.any((String s) => m.toLowerCase().contains(s.toLowerCase()));
}

/// BOUNDED, JITTERED, AND SHORT.
///
/// Four attempts over about two minutes. `SERVICE_NOT_AVAILABLE` normally
/// clears in seconds; anything still failing at two minutes will not clear at
/// five, and a longer loop only spends a diner's battery restating the same
/// fact. The NEXT APP LAUNCH is what covers the longer horizon — see
/// `PushRegistrar.syncExistingToken`.
///
/// Jittered so a venue's worth of handsets rejoining wifi do not retry in
/// lockstep and make the transient condition worse.
const List<Duration> _backoff = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 8),
  Duration(seconds: 30),
  Duration(seconds: 90),
];

class FirebasePushTokenSource implements PushTokenSource {
  const FirebasePushTokenSource();

  /// `getToken()` with backoff, for the retryable failures only.
  ///
  /// A permanent error — a missing Play Services, a broken configuration —
  /// returns immediately. Retrying it burns battery describing a fact that
  /// will not change without a different device or a different build.
  Future<String?> _tokenWithRetry() async {
    Object? last;
    for (var attempt = 0; attempt <= _backoff.length; attempt++) {
      try {
        return await FirebaseMessaging.instance.getToken();
      } catch (e) {
        last = e;
        if (!isRetryableFcmError(e) || attempt == _backoff.length) break;
        final Duration base = _backoff[attempt];
        // +/-25% jitter.
        final int ms = base.inMilliseconds;
        final int jittered = ms - (ms ~/ 4) + Random().nextInt(ms ~/ 2 + 1);
        debugPrint(
          'Push token attempt ${attempt + 1} failed (${isRetryableFcmError(e) ? "retryable" : "permanent"}); '
          'retrying in ${jittered}ms: $e',
        );
        await Future<void>.delayed(Duration(milliseconds: jittered));
      }
    }
    debugPrint('Push token unavailable after ${_backoff.length + 1} attempts: $last');
    return null;
  }

  @override
  Future<PushPermission> permission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return _map(settings.authorizationStatus);
    } catch (e) {
      // Firebase not initialised, or no Play Services. Never rethrown: a diner
      // on a Huawei handset must still be able to use the app.
      debugPrint('Push permission unavailable: $e');
      return PushPermission.unavailable;
    }
  }

  @override
  Future<PushRegistration> request() async {
    try {
      // `provisional: false` — provisional authorisation is an iOS feature that
      // delivers quietly to the notification centre without ringing. It sounds
      // generous and it is wrong for this product: the notifications that
      // matter here are a cancelled table tonight and a table that frees for
      // ten minutes, and a quiet one is a missed one.
      final settings = await FirebaseMessaging.instance.requestPermission();
      final permission = _map(settings.authorizationStatus);
      if (permission != PushPermission.granted) {
        return PushRegistration(permission: permission);
      }
      return PushRegistration(
        permission: permission,
        // Retried: the first fetch after a permission grant is exactly when
        // `SERVICE_NOT_AVAILABLE` shows up, and it is transient.
        token: await _tokenWithRetry(),
      );
    } catch (e) {
      debugPrint('Push registration failed: $e');
      return const PushRegistration(permission: PushPermission.unavailable);
    }
  }

  @override
  Future<String?> currentToken() async {
    try {
      if (await permission() != PushPermission.granted) return null;
      return await _tokenWithRetry();
    } catch (e) {
      debugPrint('Push token read failed: $e');
      return null;
    }
  }

  PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized => PushPermission.granted,
        // PROVISIONAL COUNTS AS GRANTED for registration purposes: a token
        // exists and quiet delivery is better than none. The decision not to
        // ASK for it provisionally is in `request` above.
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
        AuthorizationStatus.denied => PushPermission.denied,
      };
}

/// For tests and for every golden. Answers whatever it was built with, and
/// COUNTS what it was asked — `push_test.dart` reads those counters to prove
/// the app never asks unprompted.
class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource({
    this.state = PushPermission.notDetermined,
    this.tokenValue = 'fake-fcm-token',
  });

  PushPermission state;
  String? tokenValue;

  int permissionChecks = 0;
  int requests = 0;

  @override
  Future<PushPermission> permission() async {
    permissionChecks++;
    return state;
  }

  @override
  Future<PushRegistration> request() async {
    requests++;
    if (state == PushPermission.notDetermined) state = PushPermission.granted;
    if (state != PushPermission.granted) return PushRegistration(permission: state);
    return PushRegistration(permission: state, token: tokenValue);
  }

  @override
  Future<String?> currentToken() async => state == PushPermission.granted ? tokenValue : null;
}
