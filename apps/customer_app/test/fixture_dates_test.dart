import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/fixture_dates.dart';

/// THE FIXTURES HAVE TO KEEP MEANING WHAT THEY SAY.
///
/// Three assertions, and the third is the one that matters.
///
/// The first two check the two pinned dates are still on the right side of
/// now. Useful, and easy to satisfy by moving a constant.
///
/// The third SCANS for date literals that never made it into
/// `fixture_dates.dart` at all. Without it this file guards two dates and
/// implies it guards the suite — which is the shape of guard that let the
/// original bug through: a check pointed only at the cases somebody remembered.
void main() {
  DateTime at(String day) => DateTime.parse('${day}T18:00:00.000Z');

  group('the pinned dates are still on the right side of now', () {
    test('$kFutureDate is in the future', () {
      expect(
        at(kFutureDate).isAfter(DateTime.now().toUtc()),
        isTrue,
        reason: 'kFutureDate ($kFutureDate) has passed. Every fixture built on '
            'it now renders as a booking in the PAST: no modify button, and '
            'the goldens named "confirmed" no longer show a confirmed booking '
            'that can be changed. Move it forward in '
            'test/support/fixture_dates.dart and regenerate the goldens.',
      );
    });

    test('and far enough ahead to be worth trusting', () {
      final notice = DateTime.now().toUtc().add(const Duration(days: kFixtureNoticeDays));
      expect(
        at(kFutureDate).isAfter(notice),
        isTrue,
        reason: 'kFutureDate ($kFutureDate) expires within $kFixtureNoticeDays '
            'days. Move it forward now, while this is a one-line change rather '
            "than a surprise in somebody else's batch.",
      );
    });

    test('$kPastDate is still in the past', () {
      // The same failure with the opposite sign. A "completed" booking dated
      // in the future is not a thing that can have happened.
      expect(
        at(kPastDate).isBefore(DateTime.now().toUtc()),
        isTrue,
        reason: 'kPastDate ($kPastDate) is no longer in the past. Fixtures '
            'that are meant to read as history now read as upcoming.',
      );
    });

    test('and the two do not overlap', () {
      expect(at(kPastDate).isBefore(at(kFutureDate)), isTrue);
    });
  });

  group('no date literal has escaped fixture_dates.dart', () {
    /// Files allowed to contain a bare date, and why.
    ///
    /// Kept SHORT on purpose. Every entry is a place the guard cannot see, so
    /// each one is a small hole; a long list is the guard being negotiated
    /// away one file at a time.
    const allowed = <String>{
      // The constants themselves.
      'test/support/fixture_dates.dart',
      // This file names the dates it is asserting about.
      'test/fixture_dates_test.dart',
    };

    final offenders = <String>[];

    setUpAll(() {
      // ISO dates only. A `DateTime.now().add(...)` is fine and common — the
      // failure mode here is a FIXED date, silently drifting into the past.
      final iso = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');

      for (final entity in Directory('test').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (allowed.any(path.endsWith)) continue;

        for (final (i, raw) in entity.readAsLinesSync().indexed) {
          // COMMENTS ARE STRIPPED, and that is not laziness. Half the dates in
          // this repository are in comments explaining what went wrong on a
          // particular day, and those must not rot into noise that trains
          // everyone to ignore this test.
          final line = raw.replaceAll(RegExp(r'//.*$'), '');
          if (iso.hasMatch(line)) {
            offenders.add('$path:${i + 1}  ${raw.trim()}');
          }
        }
      }
    });

    test('the scan looked at a plausible number of files', () {
      // Guards the guard. A path bug or a rename would make the walk return
      // nothing, and an empty scan satisfies the assertion below perfectly.
      final scanned = Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;
      expect(
        scanned,
        greaterThanOrEqualTo(15),
        reason: 'only $scanned test files found — has the tree moved?',
      );
    });

    test('every fixture date comes from fixture_dates.dart', () {
      expect(
        offenders,
        isEmpty,
        reason: 'These pin a date in code rather than importing one from '
            'test/support/fixture_dates.dart. A fixed date drifts into the '
            'past and silently changes what its test covers — nothing fails, '
            'the picture just starts meaning something else:\n  '
            '${offenders.join('\n  ')}',
      );
    });
  });
}
