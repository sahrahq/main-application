import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ICU SYNTAX THAT REACHED THE SCREEN INSTEAD OF BEING COMPILED AWAY.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS SCANS THE GENERATED DART, NOT THE ARB
/// ─────────────────────────────────────────────────────────────────────────
///
/// `signInSlotHeld` was `other{# guests}` in both locales. `#` is valid ICU,
/// and Flutter's `gen-l10n` **does not implement it** — it emitted
/// `other: '# guests'` verbatim, and the sign-in screen read
/// "…at 18:00, # guests" for as long as the message existed.
///
/// Two guards missed it. `plural_count_test` reads the ARB and ACCEPTED `#`,
/// because `#` is what ICU says to use. The screen test asserted
/// `textContaining('4')` against a fixture dated the 4th, so the date
/// satisfied it and the count was never read at all.
///
/// The lesson is WHERE TO LOOK. A guard on the ARB checks what we wrote; the
/// defect was in what the generator did with it. Only the output settles that.
///
/// Deliberately a DENY LIST OF SURVIVING SYNTAX rather than an allow list of
/// supported features: a construct gen-l10n passes through in future shows up
/// here as literal syntax, without anybody having had to predict it.
void main() {
  final generated = Directory('lib/localization/generated')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Every single-quoted string in the generated files, with its location.
  ///
  /// SINGLE QUOTES ONLY, and the escape handling is naive — `'We\'ll'` is read
  /// as two fragments rather than one string. Both are fine here and neither
  /// is worth the unreadable regex that fixes them: gen-l10n emits single
  /// quotes throughout, and a split fragment still contains any ICU syntax it
  /// carried. The scanner over-reports at worst; it cannot under-report.
  List<({String file, int line, String text})> literals() {
    final found = <({String file, int line, String text})>[];
    final quoted = RegExp("'([^']*)'");

    for (final file in generated) {
      final name = file.path.replaceAll(r'\', '/').split('/').last;
      for (final (i, raw) in file.readAsLinesSync().indexed) {
        if (raw.trimLeft().startsWith('//')) continue;
        for (final m in quoted.allMatches(raw)) {
          final text = m.group(1) ?? '';
          if (text.isEmpty) continue;
          found.add((file: name, line: i + 1, text: text));
        }
      }
    }
    return found;
  }

  test('the scan found the generated localizations at all', () {
    // Guards the guard. A moved directory or a renamed file makes every
    // assertion below pass on an empty list.
    expect(generated, isNotEmpty, reason: 'no generated localization files found');
    expect(
      literals().length,
      greaterThan(200),
      reason: 'only ${literals().length} string literals parsed — the scanner '
          'is broken, not the copy',
    );
  });

  group('no ICU construct survived into a runtime string', () {
    /// What to look for, and what it means when found.
    ///
    /// The `#` rule caught a live defect. The others are the same failure
    /// waiting in constructs not used yet — added now, while it costs nothing,
    /// rather than after the next one has shipped to a diner.
    final rules = <({RegExp pattern, String name, String why})>[
      (
        pattern: RegExp('#'),
        name: 'ICU `#`',
        why: 'gen-l10n does NOT substitute `#` inside a plural — it emits the '
            'character. Use a named placeholder ({count}, {party}), which it '
            'does substitute.',
      ),
      (
        pattern: RegExp(r'\b(plural|select|selectordinal)\s*,'),
        name: 'an uncompiled ICU selector',
        why: 'A `plural`/`select` in a runtime string was never parsed as ICU '
            '— usually a syntax slip in the ARB, which gen-l10n passes through '
            'rather than rejecting.',
      ),
      (
        pattern: RegExp(r'offset\s*:\s*\d'),
        name: 'ICU plural `offset:`',
        why: 'gen-l10n does not implement `offset:`. "and N others" must be '
            'computed in Dart and passed in as a placeholder.',
      ),
      (
        // NOT `${…}` — that is Dart interpolation and is exactly right. This
        // is a BARE `{name}`, which means the placeholder was never declared
        // in the `@key` metadata and gen-l10n treated it as literal text.
        pattern: RegExp(r'(?<!\$)\{\s*\w+\s*\}'),
        name: 'an unsubstituted {placeholder}',
        why: 'A placeholder still in braces at runtime was not declared in its '
            '`@key` metadata, so it ships as literal text.',
      ),
    ];

    for (final rule in rules) {
      test('${rule.name} does not appear in any generated string', () {
        final offenders = literals()
            .where((l) => rule.pattern.hasMatch(l.text))
            .map((l) => '${l.file}:${l.line}  ${l.text}')
            .toList();

        expect(
          offenders,
          isEmpty,
          reason: '${rule.why}\n\nFound in:\n  ${offenders.join('\n  ')}',
        );
      });
    }
  });

  group('the scanner can actually see a defect', () {
    // GUARDS THE GUARD, and not ceremony: the rules above are regexes over a
    // file, and a regex that matches nothing looks exactly like a codebase
    // with nothing wrong in it. These feed them the strings that really broke
    // and require a match — and feed them the fixed versions and require none.
    test('it would have caught the `# guests` defect', () {
      expect(RegExp('#').hasMatch('# guests'), isTrue);
      expect(RegExp('#').hasMatch('4 guests'), isFalse);
    });

    test('it would catch an undeclared placeholder, and allow Dart interpolation', () {
      final braces = RegExp(r'(?<!\$)\{\s*\w+\s*\}');
      expect(braces.hasMatch('Contact us: {contact}'), isTrue);
      // What a CORRECT generated string looks like — must not be flagged.
      expect(braces.hasMatch(r'Your table: ${venue}, ${date}'), isFalse);
      expect(braces.hasMatch(r'$party guests'), isFalse);
    });

    test('it would catch an uncompiled plural', () {
      final selector = RegExp(r'\b(plural|select|selectordinal)\s*,');
      expect(selector.hasMatch('{count, plural, other{x}}'), isTrue);
      expect(selector.hasMatch('4 places'), isFalse);
    });
  });
}
