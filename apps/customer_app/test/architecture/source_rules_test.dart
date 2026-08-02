import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

/// The shared scanners from `packages/sahra_lints`, run over this app.
///
/// Same rule, same code, as the design system — three copies of a scanner is
/// three definitions of the rule (ENGINEERING-STANDARDS §5).
void main() {
  final lib = Directory('lib');

  // Generated output is the only exempt path, and it is exempt everywhere:
  // localization/generated (gen-l10n) and *.g.dart (riverpod_generator).
  const generated = <String>['/generated/'];

  test('the scanner actually reads this app — census', () {
    // Everything below asserts a list is EMPTY. An empty list is also what a
    // scanner pointed at the wrong directory returns, so the count of files it
    // opened is asserted first. This exact failure has happened twice in this
    // repo, both times in a census.
    final files = dartSources(lib, excludePathContains: generated);
    expect(files.length, greaterThan(15),
        reason: 'Only ${files.length} sources scanned — the scanner is looking '
            'in the wrong place, and every check below is vacuous.',);
  });

  test('no hardcoded colours, spacing, radii or font families', () {
    final v = noHardcodedDesignValues(lib, excludePathContains: generated);
    expect(v, isEmpty, reason: describe(v, 'design'));
  });

  test('nothing hardcodes left or right — every screen must mirror', () {
    final v = rtlSafe(lib, excludePathContains: generated);
    expect(v, isEmpty, reason: describe(v, 'rtl'));
  });

  test('no user-facing string literals — all copy comes from ARB', () {
    final v = noHardcodedUserStrings(lib, excludePathContains: generated);
    expect(v, isEmpty, reason: describe(v, 'i18n'));
  });

  test('the layer arrows point inward', () {
    // domain/ is pure Dart; presentation/ may not reach past it into data/.
    final v = layerBoundaries(lib);
    expect(v, isEmpty, reason: describe(v, 'layers'));
  });

  test('one state library — no second system can start', () {
    final v = bannedImports(lib);
    expect(v, isEmpty, reason: describe(v, 'imports'));
  });

  test('the bidi corruption signature appears nowhere in this app', () {
    // `'2066'` / `'2069'` in a Dart string literal is what a swallowed
    // backslash leaves behind when someone tries to shell-edit the isolate
    // constants. The constants themselves live in sahra_design_system and are
    // checked there; this catches the signature spreading — a copy-paste of a
    // corrupted `ltrRun`, or the same mistake made locally in a screen.
    //
    // Scanned WITHOUT the generated exclusion: generated output is exactly
    // where nobody looks.
    final v = noBidiCorruptionSignature(lib);
    expect(v, isEmpty, reason: describeBidi(v));
  });

  test('AsyncValue is unwrapped ONLY inside SahraAsyncView', () {
    // A screen with its own `.when(` is a screen with its own loading and
    // error handling, which is how a product ends up with three different
    // empty states, one of which says "No results".
    final v = asyncValueOnlyInSharedView(lib);
    expect(v, isEmpty, reason: describe(v, 'four-states'));
  });
}
