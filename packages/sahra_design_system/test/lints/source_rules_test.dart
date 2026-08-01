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
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: sahra_design_system')) {
      return Directory('${dir.path}/lib');
    }
    dir = dir.parent;
  }
  throw StateError('lib not found');
}

void main() {
  final lib = _lib();

  test('there is something to scan', () {
    expect(dartSources(lib), isNotEmpty);
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
