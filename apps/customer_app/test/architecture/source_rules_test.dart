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

  test('NO SHOWN BOOKING TIME IS DERIVED FROM startsAt VIA toLocal()', () {
    /// The rule existed as prose and was violated anyway.
    ///
    /// `my_reservation.dart` has said this since the field was added:
    ///
    ///   > USE THESE, not `DateTime.parse(startsAt).toLocal()`. A diner in
    ///   > Cairo gets the same answer either way; a diner who booked from
    ///   > Dubai and is reading the list on the plane does not, and the number
    ///   > they need is the one the restaurant will be looking at.
    ///
    /// `confirmed_screen.dart` did exactly that anyway, and carried a comment
    /// asserting it was "the ONE place a local rendering is right" — the wrong
    /// belief, written down, sitting three files from the right one. The
    /// result: the ticket a diner screenshots and shows at the door displayed
    /// a different hour from the same booking in their bookings list, whenever
    /// their phone timezone differed from the venue's. Invisible in Egypt,
    /// because there the two agree.
    ///
    /// A RULE IN A COMMENT IS NOT A CONTROL. This is the control.
    ///
    /// `startsAt`/`endsAt` are absolute instants and exist for arithmetic —
    /// "is this in the future", "how long until the hold expires". `date` and
    /// `time` are the venue's wall clock and are the only things a diner may
    /// be SHOWN. The distinction is doc 06 §4 and it must not blur.
    ///
    /// SCOPED TO BOOKING INSTANTS. `toLocal()` on `createdAt`/`readAt` in the
    /// notifications repository is correct and stays: "2 hours ago" is a fact
    /// about the reader, not about a restaurant. The scan therefore keys on
    /// startsAt/endsAt rather than banning the method outright — a blanket ban
    /// would have to be exempted immediately, and an exemption list is how a
    /// rule starts drifting.
    final List<String> offenders = <String>[];
    for (final File f in dartSources(lib, excludePathContains: generated)) {
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        if (!line.contains('toLocal()')) continue;
        if (RegExp(r'(startsAt|endsAt|starts_at|ends_at)').hasMatch(line)) {
          offenders.add('${f.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'A shown time was derived from an absolute instant via toLocal(): '
          '${offenders.join(' | ')}'
          '  ——  Show the wall clock the server computed in the venue timezone '
          '(date / time / Slot.label), not the device clock of whoever is '
          'reading. See my_reservation.dart and doc 06 section 4.',
    );
  });

  test('AND THE SCAN CATCHES ONE — guards the guard', () {
    // Without this, a regex that silently stopped matching would report a
    // clean bill of health for a tree it never checked.
    const String planted = 'final when = DateTime.parse(startsAt).toLocal();';
    expect(planted.contains('toLocal()'), isTrue);
    expect(RegExp(r'(startsAt|endsAt|starts_at|ends_at)').hasMatch(planted), isTrue);
    // And a legitimate use is NOT caught.
    const String allowed = 'createdAt: DateTime.parse(r.createdAt).toLocal(),';
    expect(RegExp(r'(startsAt|endsAt|starts_at|ends_at)').hasMatch(allowed), isFalse);
  });

  test('AsyncValue is unwrapped ONLY inside SahraAsyncView', () {
    // A screen with its own `.when(` is a screen with its own loading and
    // error handling, which is how a product ends up with three different
    // empty states, one of which says "No results".
    final v = asyncValueOnlyInSharedView(lib);
    expect(v, isEmpty, reason: describe(v, 'four-states'));
  });
}
