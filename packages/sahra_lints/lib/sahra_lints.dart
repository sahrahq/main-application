/// Source scanners for the SAHRA engineering standards.
///
/// These live in their own package so the design system and both apps run the
/// SAME rule rather than three drifting copies. Every scanner returns a list of
/// [Violation]; the calling test asserts it is empty and prints them.
///
/// They are regex scanners over source text, not an analyzer plugin. That is a
/// deliberate trade: they catch the shape people actually write, run in
/// milliseconds with no toolchain, and their limits are documented per rule in
/// `docs/flutter/ENGINEERING-STANDARDS.md` rather than pretended away.
library sahra_lints;

import 'dart:io';

class Violation {
  Violation(this.file, this.line, this.rule, this.snippet);

  final String file;
  final int line;
  final String rule;
  final String snippet;

  @override
  String toString() => '$file:$line  [$rule]  ${snippet.trim()}';
}

/// A line of source with its 1-based number, comments already removed.
class _Line {
  _Line(this.number, this.text);
  final int number;
  final String text;
}

/// Dart files under [dir], excluding generated output and anything the caller
/// names. Paths are normalised to forward slashes so rules read the same on
/// Windows and Linux.
List<File> dartSources(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
}) {
  if (!dir.existsSync()) return <File>[];
  const alwaysExcluded = <String>['/generated/', '.g.dart', '.freezed.dart'];

  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
        final path = f.path.replaceAll(r'\', '/');
        for (final e in [...alwaysExcluded, ...excludePathContains]) {
          if (path.contains(e)) return false;
        }
        return true;
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Strip comments and string-literal-free prose so a rule about writing
/// `EdgeInsets.only(left:)` is not tripped by a comment explaining the rule.
///
/// Also honours `// <rule>-exempt: reason` on the PRECEDING line — the escape
/// hatch is deliberate, greppable, and counted by [countExemptions] so its
/// growth is visible rather than quiet.
List<_Line> _scannableLines(File file, String exemptTag) {
  final raw = file.readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final lines = raw.split('\n');
  final out = <_Line>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final commentAt = _commentStart(line);
    final code = commentAt == -1 ? line : line.substring(0, commentAt);
    if (code.trim().isEmpty) continue;

    // Look back through a CONTIGUOUS comment block, not just one line. A
    // one-line lookback silently ignored every exemption whose justification
    // ran to a second sentence — which is most of the ones worth writing.
    var exempt = line.contains('$exemptTag-exempt:');
    for (var j = i - 1; j >= 0 && !exempt; j--) {
      final above = lines[j].trim();
      if (!above.startsWith('//')) break;
      if (above.contains('$exemptTag-exempt:')) exempt = true;
    }
    if (exempt) continue;
    out.add(_Line(i + 1, code));
  }
  return out;
}

/// Index of `//` that is not inside a string literal.
int _commentStart(String line) {
  var inSingle = false;
  var inDouble = false;
  for (var i = 0; i < line.length - 1; i++) {
    final c = line[i];
    if (c == r'\') {
      i++;
      continue;
    }
    if (c == "'" && !inDouble) inSingle = !inSingle;
    if (c == '"' && !inSingle) inDouble = !inDouble;
    if (!inSingle && !inDouble && c == '/' && line[i + 1] == '/') return i;
  }
  return -1;
}

/// How many lines the scanners actually PARSED.
///
/// Every scanner in this file has the shape "find things, assert none are
/// bad" — and a scanner that finds nothing satisfies that trivially. If a
/// comment-stripping change or a path bug made `_scannableLines` return
/// empty, every rule would report clean on a codebase full of violations.
///
/// Calling tests assert this is non-zero, so "no violations" always means
/// "looked, found none" and never "did not look".
int scannedLineCount(Directory dir, {List<String> excludePathContains = const <String>[]}) {
  var n = 0;
  for (final file in dartSources(dir, excludePathContains: excludePathContains)) {
    n += _scannableLines(file, '__none__').length;
  }
  return n;
}

int countExemptions(List<File> files, String exemptTag) {
  var n = 0;
  for (final f in files) {
    n += RegExp('$exemptTag-exempt:').allMatches(f.readAsStringSync()).length;
  }
  return n;
}

// ───────────────────────────────────────────── §5 no hardcoded design values ──

/// Colours, spacing, radii and fonts must come from `sahra_design_system`.
///
/// The bare `0xFF…` rule is what narrows the "launder it through a variable"
/// hole: a hex assigned to a `const` in one file and used in another still has
/// to be written down somewhere, and this catches the writing down.
final _designRules = <String, RegExp>{
  'color-literal': RegExp(r'Color\(\s*0x[0-9A-Fa-f]{8}\s*\)'),
  'color-material': RegExp(r'\bColors\.[a-zA-Z]'),
  'color-constructor': RegExp(r'Color\.from(ARGB|RGBO)\('),
  'color-hex-literal': RegExp(r'0x[fF]{2}[0-9A-Fa-f]{6}\b'),
  'spacing-literal': RegExp(r'EdgeInsets(Directional)?\.[a-zA-Z]+\([^)]*\b\d'),
  'radius-literal': RegExp(r'(BorderRadius(Directional)?\.circular|Radius\.circular)\(\s*\d'),
  'size-literal': RegExp(r'SizedBox\(\s*(height|width)\s*:\s*\d'),
  'font-family-literal': RegExp(r"""fontFamily\s*:\s*['"]"""),
};

List<Violation> noHardcodedDesignValues(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
}) {
  final out = <Violation>[];
  for (final file in dartSources(dir, excludePathContains: excludePathContains)) {
    for (final line in _scannableLines(file, 'design')) {
      _designRules.forEach((rule, pattern) {
        for (final m in pattern.allMatches(line.text)) {
          // EdgeInsets.zero and `.all(SahraSpace.s4)` are fine; only literals
          // are the problem, and `zero` reads as a match on the loose pattern.
          if (m.group(0)!.contains('zero')) continue;
          // `Colors.transparent` is the ABSENCE of a design value, not one.
          // There is no token for "no fill" and inventing one would be worse
          // than allowing this. Every other `Colors.*` stays banned.
          if (line.text.contains('Colors.transparent') &&
              m.group(0)! == 'Colors.t') {
            continue;
          }
          out.add(Violation(_short(file), line.number, rule, m.group(0)!));
        }
      });
    }
  }
  return out;
}

// ──────────────────────────────────────────────────── §5 RTL directionality ──

/// In Arabic the leading edge is on the RIGHT. A hardcoded `left` mirrors the
/// layout wrongly and never fails — it just looks subtly broken to half the
/// users, which is why this is a build error rather than a review note.
final _rtlRules = <String, RegExp>{
  'edge-insets-lr': RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
  'edge-insets-ltrb': RegExp(r'EdgeInsets\.fromLTRB\('),
  'alignment-lr': RegExp(
    r'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)',
  ),
  'border-radius-only': RegExp(r'BorderRadius\.only\('),
  'positioned-lr': RegExp(r'Positioned\((?![^)]*(start|end))[^)]*\b(left|right)\s*:'),
  'text-align-lr': RegExp(r'TextAlign\.(left|right)'),
};

List<Violation> rtlSafe(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
}) {
  final out = <Violation>[];
  for (final file in dartSources(dir, excludePathContains: excludePathContains)) {
    for (final line in _scannableLines(file, 'rtl')) {
      _rtlRules.forEach((rule, pattern) {
        for (final m in pattern.allMatches(line.text)) {
          out.add(Violation(_short(file), line.number, rule, m.group(0)!));
        }
      });
    }
  }
  return out;
}

// ───────────────────────────────────────────── §1 no hardcoded user strings ──

/// Positions whose value is READ BY A USER. A literal in any of them is copy
/// that will never be translated.
///
/// Design-system components are exempt by construction and by convention: they
/// receive copy as props (`SahraButton(label: ...)`) and own none. This scanner
/// is aimed at app widget trees, where the literal would be the copy itself.
final _stringRules = <String, RegExp>{
  'text-literal': RegExp(r'''\bText\(\s*['"](?![\s]*\$)[^'"]{2,}['"]'''),
  'label-literal': RegExp(
    r'''\b(label|labelText|hintText|helperText|errorText|title|subtitle|tooltip|semanticsLabel|content)\s*:\s*['"][^'"]{2,}['"]''',
  ),
};

List<Violation> noHardcodedUserStrings(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
}) {
  final out = <Violation>[];
  for (final file in dartSources(dir, excludePathContains: excludePathContains)) {
    for (final line in _scannableLines(file, 'i18n')) {
      _stringRules.forEach((rule, pattern) {
        for (final m in pattern.allMatches(line.text)) {
          out.add(Violation(_short(file), line.number, rule, m.group(0)!));
        }
      });
    }
  }
  return out;
}

// ─────────────────────────────────────────────────── §6 layers and imports ──

/// Clean Architecture dependency rule (doc 07 §1): the arrow points inward.
/// `domain/` is pure Dart, `presentation/` may not reach past it into `data/`.
List<Violation> layerBoundaries(Directory dir) {
  final out = <Violation>[];
  for (final file in dartSources(dir)) {
    final path = _short(file);
    final isDomain = path.contains('/domain/');
    final isPresentation = path.contains('/presentation/');
    if (!isDomain && !isPresentation) continue;

    for (final line in _scannableLines(file, 'layer')) {
      final import = RegExp(r'''import\s+['"]([^'"]+)['"]''').firstMatch(line.text);
      if (import == null) continue;
      final target = import.group(1)!;

      if (isDomain &&
          (target.startsWith('package:flutter') ||
              target.contains('/data/') ||
              target.contains('riverpod'))) {
        out.add(Violation(path, line.number, 'domain-is-pure-dart', target));
      }
      if (isPresentation && target.contains('/data/')) {
        out.add(Violation(path, line.number, 'presentation-may-not-see-data', target));
      }
    }
  }
  return out;
}

/// One state system. "Just this once" is how a codebase ends up with two.
const bannedPackages = <String>[
  'flutter_bloc', 'bloc/', 'get_it', 'package:provider/', 'mobx', 'redux',
];

List<Violation> bannedImports(Directory dir) {
  final out = <Violation>[];
  for (final file in dartSources(dir)) {
    for (final line in _scannableLines(file, 'import')) {
      if (!line.text.contains('import ')) continue;
      for (final banned in bannedPackages) {
        if (line.text.contains(banned)) {
          out.add(Violation(_short(file), line.number, 'banned-import', banned));
        }
      }
    }
  }
  return out;
}

// ────────────────────────────────────────────────────────── §2 four states ──

/// `AsyncValue` may only be unwrapped inside `SahraAsyncView`. Anywhere else
/// and a screen is inventing its own loading/empty/error handling, which is
/// how three screens end up with three different empty states.
List<Violation> asyncValueOnlyInSharedView(
  Directory dir, {
  String allowedFileSuffix = 'sahra_async_view.dart',
}) {
  final out = <Violation>[];
  final rules = <String, RegExp>{
    'raw-async-when': RegExp(r'\.(when|maybeWhen|whenOrNull)\('),
    'bare-spinner': RegExp(r'\b(CircularProgressIndicator|LinearProgressIndicator)\('),
  };

  for (final file in dartSources(dir)) {
    final path = _short(file);
    if (path.endsWith(allowedFileSuffix)) continue;
    if (!path.contains('/presentation/')) continue;

    for (final line in _scannableLines(file, 'state')) {
      rules.forEach((rule, pattern) {
        for (final m in pattern.allMatches(line.text)) {
          out.add(Violation(path, line.number, rule, m.group(0)!));
        }
      });
    }
  }
  return out;
}

String _short(File f) {
  final p = f.path.replaceAll(r'\', '/');
  final i = p.indexOf('/lib/');
  return i == -1 ? p.split('/').last : p.substring(i + 1);
}

/// Format a failure the way a developer can act on it.
String describe(List<Violation> violations, String rule) =>
    '${violations.length} $rule violation(s):\n${violations.join('\n')}';
