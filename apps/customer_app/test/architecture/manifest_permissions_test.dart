import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

/// EVERY PERMISSION THE APP ASKS FOR AT RUNTIME MUST BE DECLARED.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// Android 13 (API 33) made notifications a runtime permission. Without
/// `POST_NOTIFICATIONS` in the manifest the prompt **cannot be shown** — not
/// "is denied", cannot be shown. `requestPermission()` returns denied
/// immediately and no dialog ever appears.
///
/// Found on 2026-08-10, after NOTIFY-1 had shipped the FCM adapter, device
/// registration, the send-path platform gate and an ask-after-booking prompt,
/// all built, all tested, all verified — and all silent on any modern handset.
/// A capability that cannot be reached is indistinguishable from one that does
/// not exist.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE CATALOGUE IS THE SOURCE, NOT A LIST BESIDE IT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The requesters are found by scanning `lib/` for the calls that actually
/// trigger a system prompt. A hardcoded list of "permissions we use" would
/// drift the first time somebody adds a plugin, and drift silently, which is
/// the failure this test exists to prevent rather than reproduce.
///
/// The API-call → permission-string mapping IS a table, unavoidably: nothing
/// in the Dart source names `android.permission.POST_NOTIFICATIONS`. It is
/// kept to the two entries the app has, and adding a third without adding its
/// permission fails the census below.
void main() {
  final Directory lib = Directory('lib');
  final File manifest = File('android/app/src/main/AndroidManifest.xml');

  /// The call that raises a system dialog → the permission it needs.
  const Map<String, ({String permission, String why})> requesters =
      <String, ({String permission, String why})>{
    'Geolocator.requestPermission': (
      permission: 'android.permission.ACCESS_COARSE_LOCATION',
      why: 'LocationSource asks for it to sort venues by distance',
    ),
    'FirebaseMessaging.instance.requestPermission': (
      permission: 'android.permission.POST_NOTIFICATIONS',
      why: 'PushTokenSource asks after a booking is confirmed',
    ),
  };

  /// `uses-permission` lines only — a name appearing in a COMMENT does not
  /// declare anything, and this file has long comments naming permissions it
  /// deliberately does NOT request (ACCESS_BACKGROUND_LOCATION).
  Set<String> declared() {
    final String xml = manifest.readAsStringSync();
    return RegExp(r'<uses-permission\s+android:name="([^"]+)"')
        .allMatches(xml)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  String allSource() => dartSources(lib).map((File f) => f.readAsStringSync()).join('\n');

  test('the scan read the app and the manifest — census', () {
    // Both halves. An empty source scan makes every check below vacuous, and
    // an unreadable manifest would make `declared()` empty and fail
    // everything for the wrong reason.
    expect(dartSources(lib).length, greaterThan(15));
    expect(manifest.existsSync(), isTrue);
    expect(declared(), isNotEmpty);
  });

  test('every runtime request the source makes is declared in the manifest', () {
    final String src = allSource();
    final Set<String> have = declared();
    final List<String> missing = <String>[];
    var found = 0;

    for (final MapEntry<String, ({String permission, String why})> e in requesters.entries) {
      if (!src.contains(e.key)) continue; // not used by this app (yet)
      found++;
      if (!have.contains(e.value.permission)) {
        missing.add('${e.key}() is called (${e.value.why}) but '
            '${e.value.permission} is not in AndroidManifest.xml — on '
            'Android 13+ the prompt cannot be shown at all');
      }
    }

    // Counted, not assumed: if a refactor renamed both calls, this test would
    // otherwise pass while checking nothing.
    expect(
      found,
      greaterThan(0),
      reason: 'No runtime permission request was found in lib/. Either the '
          'app stopped asking for anything, or the detection strings above '
          'are stale — both need a human.',
    );
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('and nothing is declared that the app never asks for', () {
    // The other direction, and it is a privacy claim rather than a
    // correctness one: a permission in the manifest is visible on the store
    // listing whether or not a line of code uses it.
    final String src = allSource();
    final Set<String> asked = requesters.entries
        .where((MapEntry<String, ({String permission, String why})> e) => src.contains(e.key))
        .map((MapEntry<String, ({String permission, String why})> e) => e.value.permission)
        .toSet();

    // INTERNET is implicit in every Flutter app and is not runtime-requested.
    const Set<String> implicit = <String>{'android.permission.INTERNET'};
    final List<String> unused =
        declared().where((String p) => !asked.contains(p) && !implicit.contains(p)).toList();

    expect(
      unused,
      isEmpty,
      reason: 'Declared but never requested at runtime: ${unused.join(', ')}. '
          'Either the code that used it was removed, or the app is asking a '
          'diner to trust it with something it does not use.',
    );
  });

  test('AND A MISSING ONE IS CAUGHT — guards the guard', () {
    // Without this, a regex that stopped matching `uses-permission` would
    // report a clean bill of health for a manifest it never parsed.
    expect(declared(), contains('android.permission.POST_NOTIFICATIONS'));
    expect(declared().contains('android.permission.INVENTED_FOR_THIS_TEST'), isFalse);
  });
}
