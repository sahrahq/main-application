import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

/// A NEUTRAL CHARACTER NEXT TO A NUMBER CHANGES SIDES IN ARABIC.
///
/// The rating filter shipped `"{rating}+"`. In English it reads `4.0+`. In
/// Arabic it rendered **`+4.0`** — the plus jumped to the visual left and the
/// chip stopped saying "4.0 or better"; it now says something closer to
/// "positive four". Every assertion passed, because the string was correct and
/// only its layout was wrong. It was found by opening the Arabic golden.
///
/// That is the third time in this repo. Before it: a phone number that rendered
/// `0000 2735 2 20+`, and opening hours that rendered `23:30 – 18:00` — a venue
/// that shuts before it opens. Three findings of one class, all found by
/// looking, is the signal that the class needs a test rather than a fourth
/// pair of eyes.
///
/// ── WHY IT HAPPENS, PRECISELY ────────────────────────────────────────────
///
/// The Unicode bidirectional algorithm doing its job. Digits are `EN`
/// (European Number) and keep left-to-right order inside themselves even in an
/// Arabic paragraph. `+` and `-` are `ES`; rule W4 turns an `ES` **between**
/// two numbers into part of the number, which is why `4-5` is safe. An `ES` at
/// the EDGE of a number matches no such rule, so W6 demotes it to `ON` (Other
/// Neutral) and N1/N2 hand it the paragraph direction — RTL. The number keeps
/// its own direction, the sign takes the paragraph's, and they end up on
/// opposite sides of each other.
///
/// The remedy is `ltrRun` (U+2066 … U+2069) around the whole run.
///
/// ── WHICH CHARACTERS, AND WHICH ARE DELIBERATELY NOT HERE ────────────────
///
/// Flagged — bidi class `ES` or `ON`, and semantically part of the number they
/// touch: `+ - − – — ~ < > ≤ ≥ ±`.
///
/// NOT flagged, and the reasons are different for each group:
///
///   - **`. , :`** — class `CS`. Between two digits, W4 absorbs them (`18:00`,
///     `4.8`, `1,200` are all safe). At the edge of a number they are sentence
///     punctuation, and a full stop after «15 دقيقة» *belongs* on the left in
///     an Arabic paragraph. Flagging them would demand an isolate that made
///     the copy wrong.
///   - **`% #`** — class `ET`. Rule W5 attaches a terminator run to an
///     adjacent number and it inherits `EN`, so `20%` is already safe without
///     an isolate. Egyptian copy generally uses «٪» U+066A anyway, which is
///     not neutral at all.
///   - **`/`** — class `CS`, and it only ever appears here between two
///     numbers, where W4 applies.
///
/// Getting that list wrong in either direction costs something real: too
/// narrow and the next `+4.0` ships, too wide and somebody wraps a full stop
/// in an isolate and moves it to the wrong side of the sentence.
///
/// ── WHAT THIS ASSERTS ────────────────────────────────────────────────────
///
/// The copy alone cannot be checked, because the fix is not in the copy — the
/// ARB value `"{rating}+"` is correct and stays. So this is two halves:
///
///   1. Read the Arabic ARB and find every value carrying the risk signature.
///   2. For each one, find its call sites in `lib/` and require that every one
///      is inside an `ltrRun(…)`.
///
/// It OBSERVES the at-risk set rather than being handed a list of it. A guard
/// that is told which keys to check only ever guards the keys somebody
/// remembered.
void main() {
  final Map<String, dynamic> ar =
      jsonDecode(File('lib/localization/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;

  // ── the detector ────────────────────────────────────────────────────────

  /// Digits of either script. Arabic-Indic is forbidden in copy by
  /// `arb_test.dart`, and included here anyway: a guard that depends on
  /// another guard still holding is a guard with a second way to fail.
  const String digit = r'[0-9٠-٩]';

  /// `-` is escaped: unescaped inside a character class it is a range.
  const String neutral = r'[+\-−–—~<>≤≥±]';

  /// A neutral touching a number or a `{placeholder}` boundary, on either
  /// side. One optional space, because a space is neutral too — `{opens} –
  /// {closes}` is the hours bug, and the space did not save it.
  final RegExp signature = RegExp(
    '$neutral ?(?:$digit|\\{)'
    '|(?:$digit|\\}) ?$neutral',
  );

  String? riskIn(String value) => signature.firstMatch(value)?.group(0);

  // ── half one: which Arabic copy carries the risk ────────────────────────

  Iterable<String> copyKeys(Map<String, dynamic> a) =>
      a.keys.where((String k) => !k.startsWith('@') && a[k] is String);

  test('the Arabic ARB was actually read — census', () {
    // An empty map makes every check below pass by having nothing to check.
    final int n = copyKeys(ar).length;
    expect(
      n,
      greaterThan(200),
      reason: 'Only $n Arabic strings — the ARB path is wrong and this '
          'whole file is vacuous.',
    );
  });

  final Map<String, String> atRisk = <String, String>{
    for (final String k in copyKeys(ar))
      if (riskIn(ar[k] as String) != null) k: riskIn(ar[k] as String)!,
  };

  group('the detector can see a defect', () {
    // Fed the real strings, both the one that shipped broken and the one that
    // shipped broken before it.
    test('flags the two that were found by looking', () {
      expect(riskIn('{rating}+'), '}+', reason: 'the rating chip');
      expect(riskIn('{opens} – {closes}'), '} –', reason: 'the venue hours');
    });

    test('flags a bare figure with a sign, in either script', () {
      expect(riskIn('~20 دقيقة'), isNotNull);
      expect(riskIn('<15'), isNotNull);
      expect(riskIn('خصم -5'), isNotNull);
      expect(riskIn('حتى 30+'), isNotNull);
      // Arabic-Indic, in case the numeral rule is ever relaxed.
      expect(riskIn('~٢٠'), isNotNull);
    });

    test('and does NOT flag what an isolate would break', () {
      // Sentence punctuation. An isolate here would drag the full stop to the
      // wrong end of an Arabic sentence.
      expect(riskIn('الحجز خلال 15 دقيقة.'), isNull);
      // W4 absorbs an internal separator.
      expect(riskIn('18:00'), isNull);
      expect(riskIn('4.8'), isNull);
      // W5 attaches a terminator to its number.
      expect(riskIn('خصم 20%'), isNull);
      // Prose with no figure in it at all.
      expect(riskIn('الحجز مجاني'), isNull);
      expect(riskIn('فلاتر ({count})'), isNull);
    });

    test('the scan of the real ARB found something', () {
      // The at-risk set being empty would make the call-site check below pass
      // without examining a single call site — and it would look like a clean
      // bill of health rather than a broken detector.
      expect(
        atRisk,
        isNotEmpty,
        reason: 'No Arabic copy matched the risk signature at all. Either '
            'the pattern broke, or every figure lost its sign — check the '
            'ARB before believing this.',
      );
    });
  });

  // ── half two: every at-risk call site is isolated ───────────────────────

  /// Keys that carry the signature but must NOT be isolated, each with a
  /// reason. Empty on purpose — an entry here means somebody decided a number
  /// and its sign really do belong on opposite sides, which is a claim that
  /// needs writing down, not a checkbox.
  const Set<String> unisolatedOnPurpose = <String>{};

  final List<File> sources = dartSources(Directory('lib'));

  test('the source scan opened files — census', () {
    expect(
      sources.length,
      greaterThan(15),
      reason: 'Only ${sources.length} sources — pointed at the wrong tree.',
    );
  });

  /// Walks left from [at] to see whether it sits inside the arguments of an
  /// `ltrRun(` / `ltrRunOrNull(` call, at any nesting depth:
  /// `ltrRun(l10n.k(x))` and `ltrRun(fmt(l10n.k))` both count.
  ///
  /// Deliberately a paren walk rather than a line match. The venue hours call
  /// spans three lines inside a `.map((h) => …)`, and a line-based check would
  /// have declared it unisolated.
  bool insideIsolate(String src, int at) {
    final RegExp head = RegExp(r'ltrRun(OrNull)?$');
    var depth = 0;
    for (var i = at; i > 0; i--) {
      final int c = src.codeUnitAt(i);
      if (c == 0x29) {
        depth++; // ')'
      } else if (c == 0x28) {
        if (depth > 0) {
          depth--; // a nested group, closed on the way past
        } else if (head.hasMatch(src.substring(i < 24 ? 0 : i - 24, i))) {
          return true;
        }
        // Otherwise it is some other enclosing call — keep walking outward.
      }
    }
    return false;
  }

  test('the paren walk can return false — control', () {
    // Without this the check below could pass because `insideIsolate` says yes
    // to everything, which is the same shape of failure as a scanner pointed
    // at an empty directory.
    const String wrapped = 'label: ltrRun(l10n.filterRatingPlus(x)),';
    const String bare = 'label: l10n.filterRatingPlus(x),';
    expect(insideIsolate(wrapped, wrapped.indexOf('.filterRatingPlus')), isTrue);
    expect(insideIsolate(bare, bare.indexOf('.filterRatingPlus')), isFalse);
    // And it does not confuse a sibling call for a wrapper.
    const String sibling = 'x: other(a(b), l10n.filterRatingPlus(x)),';
    expect(insideIsolate(sibling, sibling.indexOf('.filterRatingPlus')), isFalse);
  });

  test('every at-risk Arabic string is isolated everywhere it is used', () {
    final List<String> bare = <String>[];
    final List<String> unused = <String>[];

    for (final MapEntry<String, String> entry in atRisk.entries) {
      if (unisolatedOnPurpose.contains(entry.key)) continue;

      final RegExp use = RegExp('\\.${entry.key}\\b');
      var sites = 0;

      for (final File file in sources) {
        final String src = file.readAsStringSync();
        for (final RegExpMatch m in use.allMatches(src)) {
          sites++;
          if (!insideIsolate(src, m.start)) {
            bare.add('${entry.key} (${entry.value}) — '
                '${file.path.replaceAll(r'\', '/')}');
          }
        }
      }

      // A key with no call site passes the loop above by not entering it. That
      // is either dead copy or a renamed key, and both should be said out loud
      // rather than counted as clean.
      if (sites == 0) unused.add(entry.key);
    }

    expect(
      bare,
      isEmpty,
      reason: 'These render a sign on the wrong side of its number in '
          'Arabic — the `+4.0` defect. Wrap the call in `ltrRun(…)`:\n  '
          '${bare.join('\n  ')}',
    );
    expect(
      unused,
      isEmpty,
      reason: 'At-risk copy that nothing in lib/ uses. Delete the key, or '
          'find the call site this scan cannot see: $unused',
    );
  });

  test('no exemption has gone stale', () {
    for (final String key in unisolatedOnPurpose) {
      expect(
        atRisk,
        contains(key),
        reason: '$key is exempted from isolation but no longer carries the '
            'risk signature — the copy changed and the exemption outlived '
            'its reason.',
      );
    }
  });
}
