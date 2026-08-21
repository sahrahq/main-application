import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A PLURAL WITHOUT `#` IS A NOUN SELECTOR, NOT A QUANTITY.
///
/// `bookGuests` was `{count, plural, =1{guest} other{guests}}`. Correct for
/// `SahraPartyStepper`, which draws the figure itself and takes the unit
/// beside it. Then the sign-in screen passed it into a sentence and the screen
/// read **"Your table: El Fishawy, 4 August at 18:00, guests"** — no number.
///
/// Nothing caught it, and the interesting part is WHY. The party size was
/// present, correct, and survived the whole 401 round trip; the round-trip
/// test asserts exactly that and was right to pass. The value was never lost —
/// it was handed to a string with nowhere to put it. Every layer was correct
/// and the screen was still wrong.
///
/// So this asserts the property that distinguishes the two uses: a plural
/// message either interpolates its count (`#`, or a literal digit in a `=n`
/// branch) or it is DECLARED to be a bare unit in its `@key` description. The
/// declaration is what makes the next `bookGuests` a deliberate act rather
/// than an accident.
void main() {
  Map<String, dynamic> arb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final Map<String, dynamic> en = arb('lib/localization/app_en.arb');
  final Map<String, dynamic> ar = arb('lib/localization/app_ar.arb');

  /// Keys whose plural is the NOUN ALONE, on purpose, each with a reason.
  const Set<String> bareUnitOnPurpose = <String>{
    // Drawn beside a number the party stepper renders itself, in display type.
    // Its `@` description says so at length.
    'bookGuestsUnit',
  };

  final RegExp plural = RegExp(r'\{(\w+),\s*plural\s*,');

  test('the census found plural messages at all', () {
    final found =
        en.entries.where((e) => e.value is String && plural.hasMatch(e.value as String)).length;
    // Without this the loop below passes on an ARB with no plurals in it,
    // which is how a copy guard comes to guard nothing.
    expect(found, greaterThanOrEqualTo(3), reason: 'only $found plural messages');
  });

  /// One branch of a plural: `few{…}`, `other{…}`, `=2{…}`.
  final RegExp branch = RegExp(r'(=\d+|zero|one|two|few|many|other)\s*\{([^{}]*)\}');

  test('every plural BRANCH shows its count — in both locales', () {
    // ARABIC IS CHECKED TOO, and it needs a different rule rather than an
    // exemption. The Arabic for a party of two is «فردين» — the DUAL word
    // form, which carries the quantity itself; "2 فردين" is not how anyone
    // writes it. So an EXACT-match branch (`=1`, `=2`) may legitimately spell
    // the count as a word.
    //
    // Every other selector — few, many, other — covers a RANGE and therefore
    // cannot; it has to interpolate. English lands on the same rule from the
    // other side: `=1{1 guest}` spells it out, `other{# guests}` interpolates,
    // and `other{guests}` is the defect that shipped.
    //
    // The first version of this test only read the English ARB. The identical
    // bug in Arabic alone would have passed it.
    final silent = <String>[];

    for (final locale in <MapEntry<String, Map<String, dynamic>>>[
      MapEntry<String, Map<String, dynamic>>('en', en),
      MapEntry<String, Map<String, dynamic>>('ar', ar),
    ]) {
      for (final entry in locale.value.entries) {
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String || !plural.hasMatch(value)) continue;
        if (bareUnitOnPurpose.contains(entry.key)) continue;

        for (final m in branch.allMatches(value)) {
          final selector = m.group(1)!;
          final text = m.group(2)!;
          if (selector.startsWith('=')) continue;
          // A NAMED PLACEHOLDER, or a literal digit. **NOT `#`.**
          //
          // `#` is valid ICU and Flutter's gen-l10n DOES NOT SUBSTITUTE IT.
          // `signInSlotHeld` was `other{# guests}` in both locales and the
          // generated Dart emitted `other: '# guests'` verbatim, so the
          // sign-in screen read "…at 18:00, # guests" — the same missing
          // quantity this file was written to prevent, one character further
          // along.
          //
          // It survived because THIS TEST ACCEPTED `#`, and because the
          // screen test that should have caught it asserted
          // `textContaining('4')` against a fixture dated the 4th of the
          // month: the date satisfied the assertion and the party size was
          // never read at all. Two guards agreeing on the wrong answer.
          if (RegExp(r'\{\w+\}').hasMatch(text) || RegExp(r'\d').hasMatch(text)) continue;
          silent.add('${locale.key}.${entry.key} → $selector{$text}');
        }
      }
    }

    expect(
      silent,
      isEmpty,
      reason: 'These plural branches render a word with no number. In a '
          'sentence they produce a complete-looking line with the quantity '
          'missing — the "…at 18:00, guests" defect. Interpolate with a NAMED '
          'placeholder ({party}, {count}) — never `#`, which gen-l10n emits '
          'literally. Or add the key to bareUnitOnPurpose with a reason:\n  ${silent.join('\n  ')}',
    );
  });

  test('every declared bare unit really is one, and really is described', () {
    for (final key in bareUnitOnPurpose) {
      expect(en, contains(key), reason: '$key is allow-listed but does not exist');
      final meta = en['@$key'];
      expect(
        meta,
        isA<Map<String, dynamic>>(),
        reason: '$key is allow-listed as a bare unit but has no @$key '
            'description saying why — which is the whole point of the list',
      );
      expect(
        (meta as Map<String, dynamic>)['description'],
        isNotNull,
        reason: '@$key has no description',
      );
    }
  });
}
