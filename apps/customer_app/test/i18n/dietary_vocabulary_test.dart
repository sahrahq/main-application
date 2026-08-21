import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/menu_copy.dart';

/// THE VOCABULARY IS DEFINED IN TWO PLACES. This is what stops them drifting.
///
/// ─────────────────────────────────────────────────────────────────────────
///
/// `menu_items.dietary_tags` is `TEXT[]` with a CHECK constraint naming nine
/// values. `dietaryLabel` maps those nine to copy. Neither can see the other,
/// and the failure is silent in the worst direction: a tag the database accepts
/// but the client has no copy for is **dropped at render time**, because the
/// widget skips unknown keys the same way it skips unknown amenities.
///
/// So a diner with a nut allergy would see a dish with no warning on it, and
/// nothing anywhere would have failed.
///
/// This reads the migration — the real one, on disk — extracts the constraint's
/// list, and compares it to the client's. It is deliberately a scan rather than
/// a hand-copied expectation, because a hand-copied expectation is a third
/// place for the list to live.
void main() {
  final File migration = File(
    '../../apps/api/prisma/migrations/20260809010000_menus_and_reviews/migration.sql',
  );

  test('the migration is where we think it is', () {
    // Without this the extraction below returns an empty list and every
    // comparison passes on two empty sets.
    expect(
      migration.existsSync(),
      isTrue,
      reason: 'Migration not found at ${migration.path} — this whole file is '
          'vacuous. It was renamed, or the relative path is wrong.',
    );
  });

  /// The values inside `CHECK (dietary_tags <@ ARRAY[ … ]::TEXT[])`.
  List<String> vocabularyFromMigration() {
    final String sql = migration.readAsStringSync();
    final RegExp block = RegExp(
      r'menu_items_dietary_vocabulary\s+CHECK\s*\(\s*dietary_tags\s*<@\s*ARRAY\[(.*?)\]',
      dotAll: true,
    );
    final RegExpMatch? m = block.firstMatch(sql);
    if (m == null) return <String>[];
    return RegExp("'([a-z_]+)'").allMatches(m.group(1)!).map((x) => x.group(1)!).toList();
  }

  test('the constraint was actually found and is not empty', () {
    final List<String> found = vocabularyFromMigration();
    expect(
      found,
      isNotEmpty,
      reason: 'The CHECK constraint did not match the pattern. Either it was '
          'renamed or its shape changed — and until this scan is fixed, '
          'nothing is comparing the two lists.',
    );
    expect(found.length, greaterThanOrEqualTo(5));
  });

  test('every tag the database accepts has client copy', () {
    final Set<String> db = vocabularyFromMigration().toSet();
    final Set<String> client = kDietaryVocabulary.toSet();

    expect(
      db.difference(client),
      isEmpty,
      reason: 'These tags can be stored but would VANISH on screen — the widget '
          'skips keys it has no copy for. A nut warning that silently '
          'disappears is the worst version of this bug.',
    );
    expect(
      client.difference(db),
      isEmpty,
      reason: 'These have copy but the database would refuse them, so the copy '
          'is unreachable and the list has drifted the other way.',
    );
  });

  test('and `halal` is deliberately in neither', () {
    // We mark the exception, never the default. In Cairo halal is the default,
    // and tagging it would imply the unmarked dishes are not — which the
    // product owner called "both wrong and insulting".
    //
    // Asserted rather than assumed, because the pressure to add it is the
    // obvious kind: somebody will look at the list, notice it missing, and
    // think it was forgotten.
    expect(vocabularyFromMigration(), isNot(contains('halal')));
    expect(kDietaryVocabulary, isNot(contains('halal')));
  });

  test('the two inverses that DO carry information are both present', () {
    for (final String tag in <String>['contains_pork', 'contains_alcohol']) {
      expect(kDietaryVocabulary, contains(tag));
      expect(vocabularyFromMigration(), contains(tag));
    }
  });
}
