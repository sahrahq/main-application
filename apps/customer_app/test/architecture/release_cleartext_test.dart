import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/xml_wellformed.dart';

/// A RELEASE BUILD MUST NEVER PERMIT PLAIN HTTP.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THE PERMISSION EXISTS AT ALL
/// ─────────────────────────────────────────────────────────────────────────
///
/// Android 9 (API 28) blocks cleartext HTTP by default. A handset pointed at a
/// laptop's API over the LAN — `http://192.168.x.x:3000` — therefore cannot
/// connect, and the failure is uninformative: every screen shows a generic
/// network error and the product looks broken rather than unreachable.
///
/// So `usesCleartextTraffic="true"` is declared in
/// `android/app/src/debug/` and `android/app/src/profile/`, which Gradle merges
/// into those build types ONLY. A profile build is the right handset test:
/// release-like performance, cleartext allowed, and structurally impossible to
/// upload to Play.
///
/// ─────────────────────────────────────────────────────────────────────────
/// AND WHY THIS TEST GUARDS IT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The temptation, the first time a phone will not connect, is to move that one
/// attribute into `src/main/` — where it applies to every build including the
/// one that ships. It would work immediately, it would look identical, and it
/// would ship an app that accepts unencrypted traffic for the rest of its life:
/// every token, every phone number, every booking readable on any network the
/// diner joins.
///
/// This is a five-second fix with a permanent cost, which is exactly the kind
/// that needs a test rather than a comment.
void main() {
  final File main = File('android/app/src/main/AndroidManifest.xml');
  final File debug = File('android/app/src/debug/AndroidManifest.xml');
  final File profile = File('android/app/src/profile/AndroidManifest.xml');

  test('all three manifests are well-formed — census', () {
    // Every assertion below is a pattern match. See `assertWellFormedXml`.
    for (final File f in <File>[main, debug, profile]) {
      assertWellFormedXml(f);
    }
  });

  test('the MAIN manifest permits no cleartext, by flag or by config', () {
    final String s = main.readAsStringSync();
    expect(
      s.contains('usesCleartextTraffic'),
      isFalse,
      reason: 'src/main/AndroidManifest.xml declares usesCleartextTraffic, so '
          'the SHIPPED app accepts unencrypted HTTP. Put it in src/debug/ and '
          'src/profile/ instead — Gradle merges those into development builds '
          'only.',
    );
    expect(
      s.contains('networkSecurityConfig'),
      isFalse,
      reason: 'src/main/ references a network-security-config. That is the other '
          'door to the same room: a config permitting cleartext for any domain '
          'ships with the app. If one is ever genuinely needed for release, it '
          'needs its own decision, not this test relaxed.',
    );
  });

  test('and the development overlays DO permit it — otherwise the LAN test cannot work', () {
    // The other direction, and it is not symmetry for its own sake: if these
    // silently lose the flag, a handset stops connecting and the next person
    // debugs the API for an afternoon.
    for (final File f in <File>[debug, profile]) {
      expect(
        f.readAsStringSync().contains('usesCleartextTraffic="true"'),
        isTrue,
        reason: '${f.path} no longer permits cleartext, so a handset cannot '
            'reach a laptop API over http:// and the failure will look like a '
            'broken product rather than an unreachable one.',
      );
    }
  });
}
