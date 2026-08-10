/// The shared scanners from `packages/sahra_lints`, applied to this package.
///
/// The same file runs in each app, so all three Flutter surfaces enforce one
/// definition of each rule instead of three copies that drift.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

Directory _lib() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() && pubspec.readAsStringSync().contains('name: sahra_design_system')) {
      return Directory('${dir.path}/lib');
    }
    dir = dir.parent;
  }
  throw StateError('lib not found');
}

void main() {
  final lib = _lib();

  // THE CENSUS. Every test below has the shape "find things, assert none are
  // bad", which a scanner that finds NOTHING satisfies trivially. Assert we
  // actually looked before believing any of them.
  test('the scanner found files and parsed lines', () {
    expect(dartSources(lib).length, greaterThanOrEqualTo(5));
    expect(scannedLineCount(lib), greaterThan(200));
  });

  test('no hardcoded colours, spacing, radii or fonts', () {
    final v = noHardcodedDesignValues(lib);
    expect(v, isEmpty, reason: describe(v, 'design-value'));
  });

  test('no direction-blind layout', () {
    final v = rtlSafe(lib);
    expect(v, isEmpty, reason: describe(v, 'rtl'));
  });

  test('no banned state-management imports', () {
    final v = bannedImports(lib);
    expect(v, isEmpty, reason: describe(v, 'banned-import'));
  });

  group('the bidi isolate constants are intact', () {
    // These two constants are the only place in the repo whose CORRECTNESS IS
    // INVISIBLE ON SCREEN: their whole value is one Unicode control character,
    // and a reviewer reading the diff cannot tell a correct one from a
    // corrupted one. Shell escaping has destroyed them once and came within
    // two commands of shipping `2066+20 2 2735 00002069` as a phone number.
    //
    // `flutter analyze` was GREEN throughout that, because the warning it had
    // been emitting was about the control characters being present — and they
    // were gone. See ENGINEERING-STANDARDS, "a guard that can be satisfied by
    // destroying the thing it guards".
    final bidi = File('${lib.path}/src/theme/sahra_bidi.dart');

    test('the guarded file is where the lint thinks it is — census', () {
      // Every assertion below is "find problems, expect none", which a scanner
      // pointed at a missing file satisfies trivially.
      expect(bidi.existsSync(), isTrue, reason: 'sahra_bidi.dart not at ${bidi.path}');
      expect(bidi.readAsStringSync().length, greaterThan(500));
    });

    test('each is exactly one code point, and the right one', () {
      final v = bidiConstantsIntact(bidi);
      expect(v, isEmpty, reason: describeBidi(v));
    });

    test('the corruption signature appears nowhere in the package', () {
      final v = noBidiCorruptionSignature(lib);
      expect(v, isEmpty, reason: describeBidi(v));
    });
  });

  test('exemption count is visible', () {
    for (final tag in <String>['design', 'rtl', 'i18n']) {
      final n = countExemptions(dartSources(lib), tag);
      // Printed, not asserted to zero: the escape hatch is legitimate, its
      // silent growth is not.
      // ignore: avoid_print
      print('  $tag-exempt: $n');
    }
  });
}
