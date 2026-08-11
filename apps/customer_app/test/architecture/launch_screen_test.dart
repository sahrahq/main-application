import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// THE NATIVE LAUNCH BACKGROUND MUST BE THE SAME COLOUR AS THE FIRST FLUTTER
/// FRAME.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS IS A TEST AND NOT A COMMENT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The OS paints `windowBackground` before any Dart has run. If that colour is
/// not the Dart splash's `Scaffold.backgroundColor`, the app opens on a flash
/// of the wrong colour and snaps. The scaffold shipped
/// `@android:color/white`, so every cold start began with a white flash and
/// then cream — and in dark mode, white then near-black.
///
/// The value HAS to be duplicated: Android needs it before a token can be
/// read, so there is no way to reference `tokens.json` at that moment. What
/// can be prevented is the duplicate drifting, which is what this does — it
/// parses the XML and compares against the generated Dart token, so changing
/// one without the other is a red test rather than a flash nobody notices
/// because most people develop in light mode.
///
/// Verified red-first: changing the light hex by one digit fails this.
void main() {
  final Directory res = Directory('android/app/src/main/res');

  int? hexFrom(String path, String name) {
    final File f = File('${res.path}/$path');
    if (!f.existsSync()) return null;
    final RegExpMatch? m =
        RegExp('<color name="$name">#([0-9A-Fa-f]{6,8})</color>').firstMatch(f.readAsStringSync());
    if (m == null) return null;
    final String h = m.group(1)!;
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }

  test('both launch colour files exist and parse — census', () {
    // An unparsed file yields null, and a null compared to a null would pass
    // while checking nothing.
    expect(hexFrom('values/launch_colors.xml', 'launch_background'), isNotNull);
    expect(hexFrom('values-night/launch_colors.xml', 'launch_background'), isNotNull);
  });

  test('light launch background == SahraTokens.surfacePage', () {
    expect(
      hexFrom('values/launch_colors.xml', 'launch_background'),
      // ignore: deprecated_member_use
      SahraTokens.surfacePage.value,
      reason: 'The OS would paint one colour and Flutter another — a visible '
          'flash on every cold start. Update both, or neither.',
    );
  });

  test('dark launch background == SahraNightTokens.surfacePage', () {
    expect(
      hexFrom('values-night/launch_colors.xml', 'launch_background'),
      // ignore: deprecated_member_use
      SahraNightTokens.surfacePage.value,
      reason: 'Dark mode would flash the light colour, or white, before a '
          'near-black app. The case nobody sees, because most development '
          'happens in light mode.',
    );
  });

  test('the launch drawable carries NO bitmap', () {
    // The Dart splash draws a TEXT wordmark, not an image. A logo here would
    // be replaced by different content a few hundred milliseconds later — a
    // visible swap instead of an invisible handover.
    for (final String p in <String>['drawable', 'drawable-night']) {
      final File f = File('${res.path}/$p/launch_background.xml');
      expect(f.existsSync(), isTrue, reason: '$p/launch_background.xml is missing.');
      expect(
        f.readAsStringSync().contains('<bitmap'),
        isFalse,
        reason: '$p draws a bitmap the first Flutter frame does not, so the '
            'handover is a visible swap.',
      );
    }
  });

  test('no theme still points at the scaffold default', () {
    for (final String p in <String>['values/styles.xml', 'values-night/styles.xml']) {
      final String s = File('${res.path}/$p').readAsStringSync();
      expect(
        s.contains('?android:colorBackground'),
        isFalse,
        reason: '$p still uses the platform background, which is white.',
      );
      expect(s.contains('@android:color/white'), isFalse, reason: '$p still flashes white.');
    }
  });
}
