import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_localization/sahra_localization.dart';

/// The ARB guarantees, one level up from the shared package's own tests.
void main() {
  Map<String, dynamic> arb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final en = arb('lib/localization/app_en.arb');
  final ar = arb('lib/localization/app_ar.arb');

  Set<String> keys(Map<String, dynamic> a) =>
      a.keys.where((k) => !k.startsWith('@')).toSet();

  test('the merged ARB is not a stub — census', () {
    expect(keys(en).length, greaterThan(90),
        reason: 'Only ${keys(en).length} keys — the merge produced a stub and '
            'every parity check below is comparing two empty sets.',);
  });

  test('parity: every key exists in both locales', () {
    expect(keys(en).difference(keys(ar)), isEmpty, reason: 'missing Arabic');
    expect(keys(ar).difference(keys(en)), isEmpty, reason: 'missing English');
  });

  test('no Arabic value is byte-identical to its English one', () {
    // How an untranslated placeholder ships: copied, not translated.
    //
    // The allowlist is NAMED, one entry at a time, with a reason. A pattern
    // like "skip anything that is only placeholders" would silently absorb the
    // next string somebody forgets to translate.
    const identicalOnPurpose = <String>{
      // "{opens} – {closes}" — two placeholders and an en-dash. There is no
      // Arabic form of a dash between two times, and the times themselves stay
      // in Latin digits (DESIGN-RULES.md).
      'venueHoursRange',
      // "01x xxx xxxx" — an Egyptian mobile number MASK, not a sentence. The
      // digits stay Latin (DESIGN-RULES.md) and the `x` is a placeholder
      // character a diner reads positionally. Translating it to «٠١خ خخخ خخخخ»
      // would show a shape that does not match what their keypad produces.
      'signInPhoneHint',
      // "{rating}+" — a figure and a plus sign. Latin figures in both locales
      // (DESIGN-RULES.md), and there is no Arabic form of "+" meaning "or
      // better". A translation here could only be the same three characters.
      'filterRatingPlus',
    };

    final untranslated = <String>[];
    for (final k in keys(en)) {
      if (identicalOnPurpose.contains(k)) continue;
      if (en[k] is String && en[k] == ar[k]) untranslated.add(k);
    }
    expect(untranslated, isEmpty, reason: 'copied, not translated: $untranslated');
  });

  test('no Arabic-Indic numeral appears in any copy', () {
    // DESIGN-RULES.md: figures are Latin, in Arabic as well as English.
    // Mixing two numeral systems in one interface is worse than either used
    // consistently, and the way it creeps back is exactly how it arrived —
    // somebody types «١٥» into one string by hand while every other figure on
    // the screen comes from a token or a formatter.
    //
    // U+0660–U+0669 is Arabic-Indic; U+06F0–U+06F9 is the Extended (Persian)
    // set, checked too because it is what several keyboards actually emit.
    // Written as the glyphs themselves rather than escapes, so the range is
    // readable to whoever hits this failure.
    // NOT a raw string: `r'...'` would leave `٠` as six literal
    // characters and the check would match nothing while looking correct.
    final indic = RegExp('[٠-٩۰-۹]');
    final offenders = <String>[];
    for (final a in <Map<String, dynamic>>[en, ar]) {
      for (final k in keys(a)) {
        if (indic.hasMatch(a[k] as String)) offenders.add('$k: ${a[k]}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Arabic-Indic numerals — use Latin figures: '
            '${offenders.join(' | ')}',);
  });

  test('no value is empty', () {
    for (final a in <Map<String, dynamic>>[en, ar]) {
      for (final k in keys(a)) {
        expect((a[k] as String).trim(), isNotEmpty, reason: '$k is empty');
      }
    }
  });

  test('every backend error code has copy here', () {
    // The mechanism that makes the two halves of the repo verify each other:
    // a code added to apps/api without client copy fails the Flutter suite.
    final missing = errorCodeToArbKey.values.where((k) => !keys(en).contains(k)).toList();
    expect(missing, isEmpty, reason: 'backend codes with no client copy: $missing');
  });

  test('the merged files are still marked UNREVIEWED', () {
    // Stays until a native Egyptian speaker reads the whole file in one pass.
    // A machine can prove a key exists and differs; it cannot prove it reads
    // naturally to a Cairo diner.
    expect(ar['@@x-review-status'], 'UNREVIEWED');
  });

  group('the merged ARB has not drifted from its two sources', () {
    // NOT a subprocess. `dart run tool/merge_arb.dart --check` inside
    // `flutter test` hangs on pub resolution, and a check that times out in CI
    // is a check that gets deleted. The INVARIANT is checkable directly: every
    // key from each source must appear in the merge with an identical value.
    // That is what "generated and committed" actually means here.
    final sharedEn = arb('../../packages/sahra_localization/lib/l10n/app_en.arb');
    final sharedAr = arb('../../packages/sahra_localization/lib/l10n/app_ar.arb');
    final sourceEn = arb('lib/localization/source/app_en.arb');
    final sourceAr = arb('lib/localization/source/app_ar.arb');

    test('the sources were actually read — census', () {
      expect(keys(sharedEn).length, greaterThan(40));
      expect(keys(sourceEn).length, greaterThan(40));
    });

    test('every shared error string survives the merge unchanged', () {
      // Catches the mistake that would quietly UN-share the shared copy:
      // editing the generated file instead of the source.
      final drifted = <String>[];
      for (final k in keys(sharedEn)) {
        if (en[k] != sharedEn[k]) drifted.add('en.$k');
        if (ar[k] != sharedAr[k]) drifted.add('ar.$k');
      }
      expect(drifted, isEmpty,
          reason: 'edited in lib/localization/ instead of the source: $drifted. '
              'Run: dart run tool/merge_arb.dart',);
    });

    test('every screen string survives the merge unchanged', () {
      final drifted = <String>[];
      for (final k in keys(sourceEn)) {
        if (en[k] != sourceEn[k]) drifted.add('en.$k');
        if (ar[k] != sourceAr[k]) drifted.add('ar.$k');
      }
      expect(drifted, isEmpty, reason: 'stale merge: $drifted');
    });

    test('the merge is exactly the two sources — nothing invented in between', () {
      final expected = keys(sharedEn).union(keys(sourceEn));
      expect(keys(en), expected,
          reason: 'the generated ARB has keys from neither source, or is missing some',);
    });

    test('no key is defined by BOTH sources', () {
      // A silent winner means editing the loser has no effect, which is worse
      // than a conflict.
      expect(keys(sharedEn).intersection(keys(sourceEn)), isEmpty);
    });
  });
}
