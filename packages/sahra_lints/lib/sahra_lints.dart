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
  }).toList()
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
          if (line.text.contains('Colors.transparent') && m.group(0)! == 'Colors.t') {
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
  'flutter_bloc',
  'bloc/',
  'get_it',
  'package:provider/',
  'mobx',
  'redux',
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

// ──────────────────────────────────── invisible characters cannot be reviewed ──

/// The bidi isolate constants in `sahra_design_system`, and the corruption
/// signature that has replaced them.
///
/// WHY THIS EXISTS, for whoever finds it later:
///
/// `sahra_bidi.dart` holds two constants whose entire value is a single
/// INVISIBLE Unicode control character — U+2066 LEFT-TO-RIGHT ISOLATE and
/// U+2069 POP DIRECTIONAL ISOLATE. They are what makes a phone number render
/// as `+20 2 2735 0000` inside Arabic text instead of `0000 2735 2 20+`.
///
/// This file is uniquely dangerous because **its correctness is invisible on
/// screen**. A human reviewing the diff cannot see the difference between a
/// correct constant and a corrupted one; both render as an empty-looking
/// string literal.
///
/// It has been corrupted before. A shell substitution intended to convert the
/// literal control characters into Dart escapes ate the backslash and left:
///
/// ```dart
/// const String _lri = '2066';   // the four-character string "2066"
/// const String _pdi = '2069';   // NOT the control characters
/// ```
///
/// `flutter analyze` reported **"No issues found!"** on that, because the
/// warning it had been emitting was about the presence of literal control
/// characters — and they were gone. The feature was gone with them:
/// `ltrRun()` would have shipped every phone number, time range and address
/// as `2066+20 2 2735 00002069`.
///
/// **EDIT THIS FILE WITH THE EDIT TOOL ONLY. Never perl, never sed, never a
/// heredoc.** Shell escaping has destroyed these constants once and came
/// within two commands of shipping it. That near-miss was caught by luck — a
/// behavioural test that happened to be re-run — which is not a system.
const Map<String, int> bidiIsolateConstants = <String, int>{
  '_lri': 0x2066,
  '_pdi': 0x2069,
};

/// Check the two constants are EXACTLY one code point each, and the right one.
///
/// Reads the file as bytes and inspects the actual code units rather than
/// pattern-matching the source text, because the whole problem is that the
/// source text looks the same either way.
List<Violation> bidiConstantsIntact(File bidiSource) {
  final out = <Violation>[];
  final path = _short(bidiSource);

  if (!bidiSource.existsSync()) {
    out.add(Violation(path, 0, 'bidi-file-missing', bidiSource.path));
    return out;
  }

  final lines = bidiSource.readAsStringSync().split('\n');

  for (final entry in bidiIsolateConstants.entries) {
    final name = entry.key;
    final expected = entry.value;

    // `const String _lri = '…';` — capture whatever is between the quotes.
    final pattern = RegExp("const String $name = '(.*)';");
    var found = false;

    for (var i = 0; i < lines.length; i++) {
      final m = pattern.firstMatch(lines[i]);
      if (m == null) continue;
      found = true;

      final literal = m.group(1)!;

      // Dart escape form, backslash-u-2066. Correct, and the form the guarded
      // file uses so its own source does not reorder in an editor. Written
      // here in words rather than shown, for the same reason.
      final escape = RegExp(r'^\\u\{?([0-9a-fA-F]{4,6})\}?$').firstMatch(literal);
      if (escape != null) {
        final value = int.parse(escape.group(1)!, radix: 16);
        if (value != expected) {
          out.add(Violation(
              path,
              i + 1,
              'bidi-wrong-code-point',
              '$name is U+${value.toRadixString(16).toUpperCase()}, expected '
                  'U+${expected.toRadixString(16).toUpperCase()}'));
        }
        break;
      }

      // Raw single code point. Also correct, if it is the right one.
      final units = literal.runes.toList();
      if (units.length == 1 && units.single == expected) break;

      out.add(Violation(
        path,
        i + 1,
        'bidi-constant-corrupted',
        '$name is ${_describeLiteral(literal)}, expected exactly one code point '
            'U+${expected.toRadixString(16).toUpperCase()}',
      ));
      break;
    }

    if (!found) {
      out.add(Violation(
          path, 0, 'bidi-constant-missing', "no `const String $name = '…';` in the file"));
    }
  }

  return out;
}

String _describeLiteral(String literal) {
  if (literal.isEmpty) return 'EMPTY';
  final runes = literal.runes.toList();
  final points =
      runes.map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ');
  return '${runes.length} code point(s) [$points] — the literal text "$literal"';
}

// ────────────────────────────────── §6 a claim about callers must be checkable ──

/// A DOCBLOCK MAY NOT CLAIM A CALLER IT DOES NOT NAME.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE INSTANCE THAT PRODUCED THIS RULE
/// ─────────────────────────────────────────────────────────────────────────
///
/// `PushRegistrar.syncExistingToken` carried this sentence:
///
///   > Called on sign-in and at launch for a signed-in diner.
///
/// Nothing called it on sign-in. Nothing called it at launch. Its only caller
/// was `askAfterBooking`, so a diner who had already granted permission was
/// never re-registered — and the two-minute token retry built underneath it
/// could never run on a later launch, which was the entire point of building
/// it. The sentence describing two callers had outlived having any, and it read
/// as documentation of a working mechanism for as long as it survived.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY IT FORBIDS THE CLAIM RATHER THAN CHECKING IT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The obvious rule — *verify that every named caller really calls it* — cannot
/// catch that sentence, because **it named nobody**. "On sign-in" and "at
/// launch" are SITUATIONS, not symbols; no static rule can resolve a situation
/// against a call graph. A checker built to verify claims would have walked
/// straight past the one claim that mattered and reported the class closed.
///
/// So the rule is inverted. The unverifiable claim is what is banned, and it
/// fails on SHAPE — before anything tries to resolve it. A sentence saying
/// "called by/from/on/at" must name a symbol in backticks; if it names none it
/// is rejected without a lookup, which is precisely how it catches the sentence
/// that named none.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE COST, ACCEPTED ON PURPOSE
/// ─────────────────────────────────────────────────────────────────────────
///
/// **This forbids a sentence people naturally write, and someone will find that
/// annoying.** "Called at launch" is ordinary English, it is usually true when
/// written, and being told to rewrite it as ``Called from `PushTapListener` at
/// launch`` will feel like bureaucracy the first few times.
///
/// It is worth it anyway. Four of the five stale-prose findings in this repo
/// were prose asserting something about code — a comment saying a feature was
/// unbuilt after it shipped, a doc claiming a `.gitignore` rule that did not
/// exist, a comment satisfying the very test that was supposed to check it, a
/// `RUNNING.md` listing shipped features as missing. Unfalsifiable prose that
/// fails to compile costs one rewrite. Unfalsifiable prose that survives
/// misleads the next person for a month, and in this case it silently disabled
/// push registration for every diner who had already said yes.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT IT DOES NOT CATCH — the named blind spot
/// ─────────────────────────────────────────────────────────────────────────
///
/// A docblock naming a symbol that DOES call the method, but from the wrong
/// situation, passes both stages. ``Called at launch by `X` `` where `X` only
/// runs after a booking is a true statement about the call graph and a false
/// one about when it happens. That is semantic and this rule cannot see it.
/// It is carried as a blind spot in `ENGINEERING-STANDARDS`, not fixed here.
///
/// Two more limits, stated rather than implied:
/// * Stage 2 runs only for METHODS and FUNCTIONS. A class or field docblock is
///   checked for shape only — "called" on a class means constructed, provided,
///   or routed to, and resolving that would be guesswork.
/// * A named symbol that resolves to nothing in [resolveIn] — `FirebaseMessaging`,
///   the Android framework, a cron — is accepted. It is out of tree, so the
///   claim is about something this repo cannot read.
///
/// Escape hatch: `callers-exempt: <reason>` on any line of the docblock.
/// Greppable and counted, like every other exemption in this file.
List<Violation> docblockCallerClaims(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
  Directory? resolveIn,
}) {
  final files = dartSources(dir, excludePathContains: excludePathContains);
  final index = _declarationIndex(resolveIn ?? dir, excludePathContains);
  final out = <Violation>[];

  for (final file in files) {
    for (final block in _docBlocks(file)) {
      if (block.text.contains('callers-exempt:')) continue;

      final claims = _sentences(block.text).where(_callerClaim.hasMatch).toList();
      if (claims.isEmpty) continue;

      // SCOPED TO THE WHOLE DOCBLOCK, not the sentence carrying the claim.
      // Measured: per-sentence also flagged `PushTokenSource.request`, whose
      // very next sentence says "See `push_registration.dart` for the single
      // call site" — a claim that is named, resolvable and true. Rewriting that
      // adds no information, and a rule that fires on already-checkable prose
      // teaches people to silence it. The sentence that produced this rule
      // named no symbol ANYWHERE in its block, so docblock scope still catches
      // it; per-sentence scope buys strictness the motivating case did not need.
      final symbols = _backticked
          .allMatches(block.text)
          .map((m) => m.group(1)!.trim())
          .where(_looksLikeSymbol)
          .toSet()
          .toList();

      // STAGE 1 — shape. No symbol named, so there is nothing to resolve and
      // nothing that can ever fail. This is the branch that catches the
      // sentence which produced the rule, and it never performs a lookup.
      if (symbols.isEmpty) {
        out.add(Violation(
          _short(file),
          block.line,
          'caller-claim-unnamed',
          '${block.member ?? '(block)'}: "${_clip(claims.first)}"',
        ));
        continue;
      }

      // STAGE 2 — resolution. Only for things that can be called.
      final member = block.member;
      if (member == null || !block.isCallable) continue;

      final resolved = <File>[];
      for (final s in symbols) {
        resolved.addAll(index[_symbolKey(s)] ?? const <File>[]);
      }
      // Out of tree: an OS callback, a platform channel, a scheduler. The claim
      // is about something this repo cannot read, so it stands.
      if (resolved.isEmpty) continue;

      final callsIt = resolved.any((f) => _containsCallTo(f, member));
      if (!callsIt) {
        out.add(Violation(
          _short(file),
          block.line,
          'caller-does-not-call',
          '$member claims a caller among ${symbols.map((s) => '`$s`').join(', ')}, '
              'and no call to it exists in ${resolved.map(_short).join(', ')}',
        ));
      }
    }
  }
  return out;
}

/// `called by`, `called from`, `called on`, `called at` — and the imperative
/// `call this from`. The gap before the preposition is at most two ADVERBS from
/// a closed list, never arbitrary words: `\w+` there matches
/// "called is indistinguishable from one that does not exist", a sentence about
/// this very class of defect that appears in the code it guards.
final _callerClaim = RegExp(
  r'\b(?:called|invoked)\s+'
  r'(?:(?:once|only|again|also|now|then|explicitly|deliberately|directly|'
  r'exactly|always|never|first|last)\s+){0,2}'
  r'(?:by|from|on|at)\b'
  r'|\bcall\s+(?:this|it)\s+(?:by|from|on|at)\b',
  caseSensitive: false,
);

final _backticked = RegExp(r'`([^`\n]+)`');

/// A backticked span that could name something: an identifier, a dotted path,
/// or a file. Excludes prose in backticks (`true`, `null`, a quoted sentence).
bool _looksLikeSymbol(String s) {
  if (s.contains(' ')) return false;
  if (const {'true', 'false', 'null', 'this'}.contains(s)) return false;
  return RegExp(r'^[A-Za-z_][\w.$]*(\(\))?$').hasMatch(s) || s.endsWith('.dart');
}

/// The lookup key: `PushTapListener.build` and `push_tap_listener.dart` both
/// resolve by their leading segment / basename.
String _symbolKey(String s) {
  final bare = s.replaceAll('()', '');
  if (bare.endsWith('.dart')) return bare.split('/').last.toLowerCase();
  return bare.split('.').first;
}

/// class / mixin / extension / enum / top-level function names, plus every
/// file's basename, mapped to the files declaring them.
Map<String, List<File>> _declarationIndex(
  Directory dir,
  List<String> excludePathContains,
) {
  final index = <String, List<File>>{};
  final decl = RegExp(r'^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+)*'
      r'(?:class|mixin|extension|enum)\s+(\w+)');
  for (final f in dartSources(dir, excludePathContains: excludePathContains)) {
    index.putIfAbsent(f.uri.pathSegments.last.toLowerCase(), () => []).add(f);
    for (final line in f.readAsLinesSync()) {
      final m = decl.firstMatch(line);
      if (m != null) index.putIfAbsent(m.group(1)!, () => []).add(f);
    }
  }
  return index;
}

/// Does [file] contain a real call to [member]?
///
/// COMMENTS ARE STRIPPED FIRST, and that is not an optimisation. A guard that
/// accepts a mention in a comment is satisfiable by writing a comment about
/// itself — which has already happened in this repo once, to the signing-config
/// test. A sentence saying "we should call `syncExistingToken` here" must not
/// be able to prove that we do.
bool _containsCallTo(File file, String member) {
  final call = RegExp(r'\b' + RegExp.escape(member) + r'\s*\(');
  for (final line in _scannableLines(file, '__none__')) {
    if (call.hasMatch(line.text)) return true;
  }
  return false;
}

class _DocBlock {
  _DocBlock(this.line, this.text, this.member, this.isCallable);

  /// 1-based line of the declaration the block documents.
  final int line;
  final String text;
  final String? member;

  /// A method or top-level function — the only kind stage 2 can check.
  final bool isCallable;
}

/// Every `///` run in [file], paired with the declaration underneath it.
List<_DocBlock> _docBlocks(File file) {
  final lines = file.readAsLinesSync();
  final out = <_DocBlock>[];
  var i = 0;

  while (i < lines.length) {
    if (!lines[i].trimLeft().startsWith('///')) {
      i++;
      continue;
    }
    final buffer = StringBuffer();
    while (i < lines.length && lines[i].trimLeft().startsWith('///')) {
      buffer.writeln(lines[i].trimLeft().replaceFirst(RegExp(r'^///\s?'), ''));
      i++;
    }
    // Skip annotations between the docblock and what it documents.
    var j = i;
    while (j < lines.length && (lines[j].trim().isEmpty || lines[j].trimLeft().startsWith('@'))) {
      j++;
    }
    final declaration = j < lines.length ? lines[j] : '';
    out.add(_DocBlock(
      j + 1,
      buffer.toString(),
      _declaredName(declaration),
      _isCallableDeclaration(declaration),
    ));
  }
  return out;
}

String? _declaredName(String declaration) {
  final type = RegExp(r'\b(?:class|mixin|extension|enum|typedef)\s+(\w+)').firstMatch(declaration);
  if (type != null) return type.group(1);

  final paren = declaration.indexOf('(');
  if (paren > 0) {
    final before = declaration.substring(0, paren);
    final ids = RegExp(r'\w+').allMatches(before).toList();
    if (ids.isNotEmpty) return ids.last.group(0);
  }
  final field = RegExp(r'^\s*(?:static\s+|final\s+|const\s+|late\s+)*'
          r'[\w<>,\s?]*\s(\w+)\s*[=;]')
      .firstMatch(declaration);
  return field?.group(1);
}

bool _isCallableDeclaration(String declaration) {
  if (RegExp(r'\b(?:class|mixin|extension|enum|typedef)\b').hasMatch(declaration)) {
    return false;
  }
  final paren = declaration.indexOf('(');
  if (paren <= 0) return false;
  // `final x = StateProvider<bool>((ref) => ...)` is a field, not a method.
  return !RegExp(r'=\s*$|=\s*\w').hasMatch(declaration.substring(0, paren));
}

/// Sentence split that survives prose. Backticked spans are masked first so a
/// `push_test.dart` or a `§4.` does not end a sentence early.
List<String> _sentences(String text) {
  final flat = text.replaceAll('\n', ' ');
  final out = <String>[];
  final buffer = StringBuffer();
  var inCode = false;

  for (var i = 0; i < flat.length; i++) {
    final c = flat[i];
    buffer.write(c);
    if (c == '`') inCode = !inCode;
    // A terminator INSIDE backticks belongs to a symbol — `push_test.dart`,
    // `doc 06 s4.` — and must not end the sentence early. This used to be done
    // by masking each span with a sentinel character, which put two invisible
    // control characters into the source of the package whose whole job is
    // keeping invisible characters out of source. It also unmasked on `\d+`,
    // so any real number in the prose came back as somebody else's symbol.
    if (inCode) continue;
    final ends = (c == '.' || c == '!' || c == '?' || c == ':') &&
        (i + 1 >= flat.length || flat[i + 1] == ' ');
    if (ends) {
      out.add(buffer.toString());
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) out.add(buffer.toString());

  return out.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

String _clip(String s) => s.length <= 90 ? s : '${s.substring(0, 87)}...';

// ──────────────────────────────────────────── §6b a capability nothing calls ──

/// PUBLIC METHODS THAT NOTHING IN `lib/` EVER MENTIONS.
///
/// *A capability that is never called is indistinguishable from one that does
/// not exist* (ENGINEERING-STANDARDS). This finds the literal case: a public
/// method declared in the app and referenced from nowhere but its own
/// declaration and, possibly, a test.
///
/// ─────────────────────────────────────────────────────────────────────────
/// READ THIS BEFORE TRUSTING IT
/// ─────────────────────────────────────────────────────────────────────────
///
/// **It did not, and could not, catch the defect that prompted the caller-claim
/// rule above.** `syncExistingToken` HAD a caller — `askAfterBooking` — so it
/// was never dead. It was reachable from one situation while its docblock
/// described two others. This rule and that one are unrelated; counting this
/// one toward closing the stale-prose class would be exactly the move that
/// class is made of.
///
/// **It is prone to false positives on ports.** A concrete implementation whose
/// callers all go through an abstract type is live code that looks dead. Name
/// matching dodges most of it — `currentToken` is mentioned in the file that
/// calls it through `PushTokenSource` — but a method named only on the
/// interface and never on an implementation is still a plausible miss in the
/// other direction, and a fake used solely from tests will be reported.
///
/// **It is a text scanner, not an analyzer.** It counts NAME appearing anywhere
/// in comment-stripped source outside its own declaration, which deliberately
/// includes tear-offs (`onTap: x.retry`) and deliberately over-counts: two
/// unrelated classes with a method of the same name shield each other. Over-
/// counting is the safe direction for a rule whose failure mode is noise.
///
/// Scope it to an APP, never a package: `sahra_design_system`'s public widgets
/// are called from `apps/`, so pointed at the package everything looks dead.
List<Violation> publicMethodsWithNoCaller(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
  Set<String> exemptNames = const <String>{},
}) {
  const framework = <String>{
    'build',
    'main',
    'toString',
    'noSuchMethod',
    'createState',
    'initState',
    'dispose',
    'didChangeDependencies',
    'didUpdateWidget',
    'setState',
  };
  final keyword = RegExp(r'^(if|for|while|switch|catch|return|assert|await|'
      r'yield|super|this|new|do|else|case)$');
  final declaration = RegExp(
    r'^(\s+(?:@\w+\s+)*(?:static\s+|external\s+|abstract\s+)*'
    r'(?:[\w<>,\s?\[\]$]+\s+)?)(\w+)\s*\(',
  );
  // `throw StateError(x);`, `await launchUrl(u);`, `final r = RegExp(p);` and
  // `runApp(App());` all match the shape of a declaration. What separates them
  // is the PREFIX: a declaration's prefix is a type or nothing, never a
  // statement keyword and never an expression. Measured on this app, these five
  // exclusions turned 6 hits into 2 — the other 4 were calls.
  final statementPrefix = RegExp(r'\b(?:throw|return|await|yield|new)\s+$');

  final files = dartSources(dir, excludePathContains: excludePathContains);
  final declared = <_Decl>[];

  for (final file in files) {
    final raw = file.readAsLinesSync();
    var currentClass = '';
    for (final line in _scannableLines(file, 'callers')) {
      final classMatch = RegExp(r'\b(?:class|mixin|extension)\s+(\w+)').firstMatch(line.text);
      if (classMatch != null) {
        currentClass = classMatch.group(1)!;
        continue;
      }
      final m = declaration.firstMatch(line.text);
      if (m == null) continue;

      final prefix = m.group(1)!;
      final name = m.group(2)!;
      if (statementPrefix.hasMatch(prefix)) continue;
      if (RegExp(r'[=(.,:?]').hasMatch(prefix)) continue;
      // A body proves a declaration. A bare `;` only does when a return type is
      // present (an abstract member) — otherwise it is a call statement.
      final hasBody = RegExp(r'(\{|=>)').hasMatch(line.text);
      if (!hasBody && prefix.trim().isEmpty) continue;
      // `{`, `{}`, `=>` or `;`. The `{}` alternative is not tidiness: without
      // it `void foo() {}` ends with `}` and every single-line empty body in
      // the app was skipped in silence. Caught by the positive control in
      // `source_rules_test.dart`, on the first run, before this rule had ever
      // reported a number anyone could have believed.
      if (!RegExp(r'(\{\s*\}?|=>|;)\s*$').hasMatch(line.text)) continue;

      if (name.startsWith('_') ||
          keyword.hasMatch(name) ||
          framework.contains(name) ||
          exemptNames.contains(name) ||
          name == currentClass) {
        continue;
      }
      // `@override` sits on the line above, which `_scannableLines` drops if
      // it is nothing else.
      final above = line.number >= 2 ? raw[line.number - 2] : '';
      if (above.contains('@override') || line.text.contains('@override')) continue;
      if (line.text.contains('factory ')) continue;

      declared.add(_Decl(file, line.number, name));
    }
  }

  final out = <Violation>[];
  for (final d in declared) {
    final mention = RegExp(r'\b' + RegExp.escape(d.name) + r'\b');
    var used = false;
    for (final file in files) {
      for (final line in _scannableLines(file, 'callers')) {
        if (file.path == d.file.path && line.number == d.line) continue;
        // Another declaration of the same name is not a use of it.
        if (declared
            .any((o) => o.name == d.name && o.file.path == file.path && o.line == line.number)) {
          continue;
        }
        if (mention.hasMatch(line.text)) {
          used = true;
          break;
        }
      }
      if (used) break;
    }
    if (!used) {
      out.add(Violation(_short(d.file), d.line, 'no-caller',
          '${d.name}() is public and nothing in lib/ mentions it'));
    }
  }
  return out;
}

class _Decl {
  _Decl(this.file, this.line, this.name);
  final File file;
  final int line;
  final String name;
}

/// The exact corruption signature, anywhere in the repo.
///
/// `'2066'` or `'2069'` inside a Dart string literal is what a swallowed
/// backslash leaves behind. There is no legitimate reason for either — they
/// are not years, not ports, not sizes, and if one ever is, this rule wants to
/// hear about it.
List<Violation> noBidiCorruptionSignature(
  Directory dir, {
  List<String> excludePathContains = const <String>[],
}) {
  final out = <Violation>[];
  final signature = RegExp(r"""['"](2066|2069)['"]""");

  for (final file in dartSources(dir, excludePathContains: excludePathContains)) {
    // NOT `_scannableLines`: this rule must see the raw source. A corrupted
    // constant may sit on a line the comment-stripper would touch, and this is
    // the one rule that cannot afford to be clever about what it reads.
    final lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final m in signature.allMatches(lines[i])) {
        out.add(Violation(_short(file), i + 1, 'bidi-corruption-signature', m.group(0)!));
      }
    }
  }
  return out;
}

/// The failure message. Long on purpose: a future session meeting this needs
/// to know WHY, not just WHAT, or it will "fix" it with the tool that broke it.
String describeBidi(List<Violation> violations) => '''
${violations.length} bidi-constant violation(s):
${violations.join('\n')}

WHAT THESE CONSTANTS ARE
  U+2066 LEFT-TO-RIGHT ISOLATE and U+2069 POP DIRECTIONAL ISOLATE. They are
  INVISIBLE control characters. `ltrRun()` wraps phone numbers, time ranges
  and addresses in them so a Latin run inside Arabic text lays out
  left-to-right. Without them a Cairo phone number renders as
  "0000 2735 2 20+" and opening hours as "23:30 - 18:00".

WHY A LINT GUARDS TWO CONSTANTS
  Their correctness is INVISIBLE ON SCREEN. A reviewer reading the diff cannot
  tell a correct constant from a corrupted one — both look like an empty
  string literal. Nothing else in this repo has that property.

HOW THEY BROKE LAST TIME
  A shell substitution meant to turn the literal control characters into Dart
  escapes swallowed the backslash and left the four-character strings "2066"
  and "2069". `flutter analyze` then reported "No issues found!", because the
  warning it had been emitting was about the CONTROL CHARACTERS BEING PRESENT
  — and they were gone, along with the feature.

HOW TO FIX IT
  Edit `packages/sahra_design_system/lib/src/theme/sahra_bidi.dart` so it reads
  exactly:

      const String _lri = '\\u2066';
      const String _pdi = '\\u2069';

  USE THE EDIT TOOL. Never perl, never sed, never a heredoc — shell escaping
  is what destroyed them, three attempts running.

  Then run the BEHAVIOURAL test, not the analyzer:

      cd packages/sahra_design_system && flutter test test/bidi_test.dart
''';

String _short(File f) {
  final p = f.path.replaceAll(r'\', '/');
  final i = p.indexOf('/lib/');
  return i == -1 ? p.split('/').last : p.substring(i + 1);
}

/// Format a failure the way a developer can act on it.
String describe(List<Violation> violations, String rule) =>
    '${violations.length} $rule violation(s):\n${violations.join('\n')}';
