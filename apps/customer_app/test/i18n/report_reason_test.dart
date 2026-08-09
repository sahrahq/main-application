import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/restaurants/domain/report_reason.dart';

/// THE REPORT REASONS ARE DEFINED TWICE. This is what stops them drifting.
///
/// `report_reason` is a Postgres enum; `ReportReason` is a Dart enum; neither
/// can see the other. The failure is silent in the worse direction — a value the
/// database accepts and the client has no case for would either throw at the
/// `switch` or, if somebody adds a `_ =>` default, disappear from the sheet
/// entirely.
///
/// Same shape as `dietary_vocabulary_test.dart`: read the migration on disk
/// rather than keeping a third copy of the list beside the test.
void main() {
  final File migration = File(
    '../../apps/api/prisma/migrations/20260809030000_review_reports/migration.sql',
  );

  test('the migration is where we think it is', () {
    expect(migration.existsSync(), isTrue,
        reason: 'Migration not found at ${migration.path} — this file is now '
            'vacuous. It was renamed, or the relative path is wrong.',);
  });

  /// The values inside `CREATE TYPE report_reason AS ENUM ( … )`.
  List<String> reasonsFromMigration() {
    final RegExp block = RegExp(
      r'CREATE TYPE report_reason AS ENUM\s*\((.*?)\)\s*;',
      dotAll: true,
    );
    final RegExpMatch? m = block.firstMatch(migration.readAsStringSync());
    if (m == null) return <String>[];
    return RegExp("'([a-z_]+)'")
        .allMatches(m.group(1)!)
        .map((x) => x.group(1)!)
        .toList();
  }

  test('the enum was found and is not empty', () {
    final List<String> found = reasonsFromMigration();
    expect(found, isNotEmpty,
        reason: 'CREATE TYPE report_reason did not match — it was renamed or '
            'its shape changed, and until this scan is fixed nothing is '
            'comparing the two lists.',);
    expect(found.length, greaterThanOrEqualTo(4));
  });

  test('every value the database accepts has a Dart case', () {
    final Set<String> db = reasonsFromMigration().toSet();
    final Set<String> client =
        ReportReason.values.map((r) => r.wire).toSet();

    expect(
      db.difference(client),
      isEmpty,
      reason: 'These reasons can be stored and the client has no case for '
          'them — the `switch` in the sheet would throw, or silently drop '
          'them if somebody adds a default.',
    );
    expect(
      client.difference(db),
      isEmpty,
      reason: 'These have a Dart case but the database would refuse them, so '
          'the chip is unreachable and the list has drifted the other way.',
    );
  });

  test('`wire` is snake_case, not Dart `name`', () {
    // `ReportReason.notMyVisit.name` is `notMyVisit`, which the API refuses.
    // The bug this prevents is a chip that looks fine and 400s on submit.
    expect(ReportReason.notMyVisit.wire, 'not_my_visit');
    expect(ReportReason.wrongVenue.wire, 'wrong_venue');
    expect(ReportReason.notMyVisit.name, isNot(ReportReason.notMyVisit.wire));
  });

  test('`not_my_visit` exists, and is not folded into `other`', () {
    // It is the one reason that is about US: a review attached to the wrong
    // reservation is a bug in the verified-diner guarantee, not a moderation
    // question, and a moderator cannot triage it if it arrives as "other".
    expect(reasonsFromMigration(), contains('not_my_visit'));
    expect(ReportReason.values, contains(ReportReason.notMyVisit));
  });
}
