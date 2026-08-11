import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A GUARD THAT READS A STRUCTURED FILE MUST FIRST ASSERT THE FILE IS THAT
/// STRUCTURE.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// On 2026-08-11 both manifest guards passed on an `AndroidManifest.xml` that
/// the Android toolchain refuses to parse. A comment had been placed between
/// the attributes of the `<application>` start tag — not well-formed XML — and
/// every regex still matched, because the attributes were all still there in
/// the text. The permission check was green, the `<queries>` check was green,
/// and `flutter build apk --release` died with *"Please ensure that the
/// android manifest is a valid XML document"*.
///
/// **A guard that greps a file it cannot parse is checking a string, not a
/// manifest.**
///
/// Dart has no XML parser in the SDK and this repo will not add a dependency
/// for a test, so this is a deliberately small structural check rather than a
/// parser: it catches the malformations that a regex guard is blind to,
/// because the thing it is looking for survives them.
///
/// ── WHAT IT CATCHES, AND WHAT IT DOES NOT ────────────────────────────────
///
/// Catches: a comment inside a start tag, an unterminated comment, unbalanced
/// angle brackets. Those are the ways a hand-edited XML file breaks.
///
/// Does NOT catch: mismatched or unclosed ELEMENTS (`<a></b>`), duplicate
/// attributes, bad entities. A real parser would. Stated rather than implied —
/// if one of those ever bites, this is the function to grow, not a new one to
/// write beside it.
void assertWellFormedXml(File file) {
  expect(file.existsSync(), isTrue, reason: '${file.path} does not exist.');
  final String xml = file.readAsStringSync();

  final List<String> problems = <String>[];
  var i = 0;
  while (true) {
    final int open = xml.indexOf('<', i);
    if (open < 0) break;

    if (xml.startsWith('<!--', open)) {
      final int end = xml.indexOf('-->', open);
      if (end < 0) {
        problems.add('unterminated comment opened at offset $open');
        break;
      }
      i = end + 3;
      continue;
    }

    final int close = xml.indexOf('>', open);
    if (close < 0) {
      problems.add('unclosed tag at offset $open');
      break;
    }
    final String tag = xml.substring(open, close);
    if (tag.contains('<!--')) {
      final int line = '\n'.allMatches(xml.substring(0, open)).length + 1;
      problems.add('line $line: a comment sits INSIDE a start tag — '
          '${tag.split('\n').first.trim()}');
    }
    i = close + 1;
  }

  expect(
    problems,
    isEmpty,
    reason: '${file.path} is not well-formed XML, so every pattern-match '
        'against it is checking a string rather than a document: '
        '${problems.join('; ')}',
  );

  expect(
    '<'.allMatches(xml).length,
    equals('>'.allMatches(xml).length),
    reason: '${file.path} has unbalanced angle brackets.',
  );
}
