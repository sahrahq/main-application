import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

/// EVERY URI SCHEME THE APP LAUNCHES MUST BE DECLARED IN `<queries>`.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SAME TRAP, THREE TIMES
/// ─────────────────────────────────────────────────────────────────────────
///
/// Android 11 (API 30) tightened package visibility: an app cannot see which
/// activities handle an intent unless it declares the query. `canLaunchUrl`
/// then returns **false even where a handler exists**, and every caller in
/// this app is written to degrade quietly when it does — by design, so a
/// handset with no mail client does not crash.
///
/// Which means the failure is silent. The control stops working on every
/// modern Android while working perfectly on whichever emulator image
/// somebody happened to test, and nothing goes red.
///
///   · `mailto:` — support address, Group C
///   · `tel:`    — venue phone, Group D
///   · `geo:`    — venue directions, 2026-08-11
///
/// Three occurrences of one class. The first two were caught by hand and
/// documented in the manifest; the third was caught only because that
/// documentation existed to be read. This test is the version that does not
/// depend on somebody reading it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT IT CANNOT SEE
/// ─────────────────────────────────────────────────────────────────────────
///
/// A scheme assembled at runtime — `Uri(scheme: someVariable)` — is invisible
/// to a source scan, and no static rule can fix that. Stated rather than
/// pretended: the schemes this app uses are all literals, and if that stops
/// being true the census below is the thing that will notice, because the
/// count will not match.
///
/// `http`/`https` are exempt. Android treats a browsable web intent as
/// implicitly visible, and every launch of one in this app goes to an external
/// site rather than to a specific app.
void main() {
  final Directory lib = Directory('lib');
  final File manifest = File('android/app/src/main/AndroidManifest.xml');

  const Set<String> exempt = <String>{'http', 'https'};

  /// Schemes the source actually launches, read out of the source.
  Set<String> schemesInSource() {
    final Set<String> found = <String>{};
    for (final File f in dartSources(lib)) {
      final String src = f.readAsStringSync();
      // `Uri(scheme: 'tel', ...)`
      for (final RegExpMatch m
          in RegExp(r"""Uri\(\s*scheme:\s*['"]([a-z][a-z0-9+.-]*)['"]""").allMatches(src)) {
        found.add(m.group(1)!);
      }
      // `Uri.parse('geo:...')` — only a literal with a scheme prefix.
      for (final RegExpMatch m
          in RegExp(r"""Uri\.parse\(\s*['"]([a-z][a-z0-9+.-]*):""").allMatches(src)) {
        found.add(m.group(1)!);
      }
    }
    return found.difference(exempt);
  }

  /// Schemes declared under `<queries>`, from the XML rather than a list.
  Set<String> schemesInManifest() {
    final String xml = manifest.readAsStringSync();
    final int start = xml.indexOf('<queries>');
    final int end = xml.indexOf('</queries>');
    if (start < 0 || end < 0) return <String>{};
    final String block = xml.substring(start, end);
    return RegExp(r'<data\s+android:scheme="([^"]+)"')
        .allMatches(block)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
  }

  test('the scan read both sides — census', () {
    // An empty source scan or an unparsed manifest would make the assertion
    // below vacuous, which is how a census fails in this repo.
    expect(dartSources(lib).length, greaterThan(15));
    expect(manifest.existsSync(), isTrue);
    expect(
      schemesInSource(),
      isNotEmpty,
      reason: 'No launchable scheme found in lib/. Either nothing launches '
          'anything any more, or the patterns above went stale.',
    );
    expect(schemesInManifest(), isNotEmpty);
  });

  test('every scheme the app launches is declared under <queries>', () {
    final Set<String> used = schemesInSource();
    final Set<String> declared = schemesInManifest();
    final List<String> missing = used.difference(declared).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason: 'Launched but not declared: ${missing.join(', ')}. On Android 11+ '
          '`canLaunchUrl` returns FALSE for these even where a handler exists, '
          'and every caller degrades quietly — so the control stops working on '
          'every modern handset and nothing goes red. Add an <intent> with '
          '<data android:scheme="..."/> to <queries> in AndroidManifest.xml.',
    );
  });

  test('and nothing is declared that the app never launches', () {
    // The other direction. A stale `<queries>` entry is not a security problem
    // the way an unused permission is, but it is a claim about what the app
    // does, and a wrong one sends the next reader looking for a caller that
    // does not exist.
    final List<String> unused = schemesInManifest().difference(schemesInSource()).toList()..sort();
    expect(
      unused,
      isEmpty,
      reason: 'Declared under <queries> but never launched: ${unused.join(', ')}.',
    );
  });

  test('AND A MISSING ONE IS CAUGHT — guards the guard', () {
    // Without this, a regex that stopped matching would report a clean bill of
    // health for a manifest and a source tree it never read.
    expect(schemesInSource(), contains('geo'));
    expect(schemesInManifest(), contains('geo'));
    expect(schemesInManifest().contains('invented-for-this-test'), isFalse);
  });
}
