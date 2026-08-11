import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_lints/sahra_lints.dart';

/// COPY THAT PROMISES AN ACTION MUST HAVE ONE ATTACHED.
///
/// **SCOPE, UP FRONT: this covers ONE call site today** — a secondary line
/// (`detail:`/`subtitle:`/`trailing:`) carrying localised copy that opens with
/// an English imperative. It does NOT cover titles, body text, bare `Text()`,
/// Arabic-only phrasing, or a handler that exists and does nothing. Inherit
/// the caveat, not the impression.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE PATTERN, AFTER FOUR OCCURRENCES
/// ─────────────────────────────────────────────────────────────────────────
///
/// Four controls in this app have promised something they did not do, and
/// three were found by a person rather than by a test:
///
///   · the waitlist bell that failed on tap
///   · the "Saved places" row that led nowhere
///   · **"Call venue"** — a phone number with an action label and NO GESTURE,
///     shipped that way and noticed only while building the map handoff
///   · account copy still describing features as unbuilt after they were built
///
/// Two of the four are one shape: **a widget rendering action-shaped copy with
/// no handler attached.** That shape is enumerable, so here it is.
///
/// ─────────────────────────────────────────────────────────────────────────
/// HOW THE CATALOGUE IS DERIVED, AND THE BROADER RULE THAT WAS REJECTED
/// ─────────────────────────────────────────────────────────────────────────
///
/// The catalogue is `app_en.arb`: every key whose ENGLISH value begins with an
/// imperative verb. Computed on every run, so a new key joins it the day it is
/// written — no list beside the test.
///
/// THE FIRST VERSION CHECKED EVERY USE OF THOSE KEYS AND WAS WRONG. It
/// reported twelve offenders, all of them headings or sentences that merely
/// begin with a verb:
///
///     "Sign in to book"                   — a page title
///     "Find the vibe for tonight"         — an onboarding heading
///     "Enter the code"                    — a step title
///     "Invite friends, payment methods …" — a sentence saying things are NOT
///                                           built
///
/// A rule that fires on a page title has no signal, and a rule with no signal
/// gets suppressed and then deleted. So it is narrowed to where the real
/// defect lives: **a SECONDARY line — `detail:`, `subtitle:`, `trailing:`,
/// `caption:`, `helper:` — is where a widget says what tapping it will DO.**
/// A title describes what a thing is; a detail line under a phone number
/// reading "Call venue" promises something.
///
/// That narrowing is a real loss of coverage, recorded rather than hidden.
/// What remains still catches the defect that produced it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT IT CANNOT SEE — STATED, NOT PRETENDED
/// ─────────────────────────────────────────────────────────────────────────
///
///   · **Action copy anywhere but a secondary line.** A bare `Text(l10n.x)`
///     promising an action is not caught — see the rejected broad rule above.
///   · **Nouns that imply action.** "Directions" alone would pass; only
///     "Get directions" is caught. English imperatives are detectable, intent
///     is not.
///   · **A handler that does nothing.** The waitlist bell HAD an `onTap`; it
///     just failed. This proves a handler exists, never that it works — that
///     is the journey test's job.
///   · **Arabic copy.** The verb list is English. `arb_parity_test` requires
///     every key in both files, so an action key is reached via its English
///     twin.
void main() {
  final Directory lib = Directory('lib');
  final File arb = File('lib/localization/app_en.arb');

  /// English imperatives that open a call to action. Extend freely — a verb
  /// missing here is a gap in coverage, never a false failure.
  const Set<String> imperatives = <String>{
    'add',
    'book',
    'call',
    'cancel',
    'change',
    'choose',
    'clear',
    'confirm',
    'contact',
    'copy',
    'create',
    'delete',
    'dial',
    'edit',
    'email',
    'enter',
    'find',
    'follow',
    'get',
    'go',
    'invite',
    'join',
    'leave',
    'manage',
    'message',
    'move',
    'notify',
    'open',
    'pick',
    'refresh',
    'remove',
    'reply',
    'report',
    'reserve',
    'resend',
    'retry',
    'save',
    'search',
    'see',
    'select',
    'send',
    'set',
    'share',
    'show',
    'sign',
    'start',
    'submit',
    'switch',
    'tap',
    'try',
    'turn',
    'update',
    'view',
    'write',
  };

  /// Anything that attaches behaviour. A widget carrying one of these is a
  /// control, whatever its copy says.
  const List<String> handlers = <String>[
    'onTap:',
    'onPressed:',
    'onLongPress:',
    'onChanged:',
    'onSubmitted:',
    'onSelected:',
    'onRetry:',
    'onOpen:',
    'onSave:',
    'onDismiss:',
    'onBack:',
    'onDelete:',
    'onConfirm:',
    'onToggle:',
    'recognizer:',
  ];

  Map<String, String> actionKeys() {
    final Map<String, dynamic> json = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, String> out = <String, String>{};
    json.forEach((String k, dynamic v) {
      if (k.startsWith('@') || v is! String || v.isEmpty) return;
      final String first = v.split(RegExp(r'[\s,.:!?]')).first.toLowerCase();
      if (imperatives.contains(first)) out[k] = v;
    });
    return out;
  }

  /// The constructor call surrounding [index], by bracket matching. Walks back
  /// to the `(` opening the innermost enclosing call, then forward to its
  /// match, so a handler passed on any line of the invocation counts.
  String? enclosingCall(String src, int index) {
    var depth = 0;
    var open = -1;
    for (var i = index; i >= 0; i--) {
      final String c = src[i];
      if (c == ')') depth++;
      if (c == '(') {
        if (depth == 0) {
          open = i;
          break;
        }
        depth--;
      }
    }
    if (open < 0) return null;
    depth = 0;
    for (var i = open; i < src.length; i++) {
      final String c = src[i];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return src.substring(open, i + 1);
      }
    }
    return null;
  }

  /// ONE PASS, CAPTURING THE KEY — not a regex rebuilt per key.
  ///
  /// The per-key version matched NOTHING while reporting success: the pattern
  /// printed correctly, the source demonstrably contained the string, and
  /// `allMatches` still returned zero. Rather than ship a guard whose failure
  /// I could not explain, it was replaced with this — which was then broken on
  /// purpose and observed going red. A guard nobody has seen fail is
  /// decoration.
  final RegExp secondary =
      RegExp(r'(detail|subtitle|trailing|caption|helper)\s*:\s*l10n\.([A-Za-z0-9_]+)');

  test('the catalogue is derived and non-trivial — census', () {
    final Map<String, String> keys = actionKeys();
    expect(arb.existsSync(), isTrue);
    expect(dartSources(lib).length, greaterThan(15));
    expect(
      keys.length,
      greaterThan(20),
      reason: 'Only ${keys.length} action keys derived from app_en.arb — the '
          'imperative detection has gone stale and every check below is '
          'weaker than it looks.',
    );
  });

  test('the scan sees secondary-line copy at all — census', () {
    // The per-key version failed exactly here and said nothing. Counting what
    // the scan SEES turns a silently-broken matcher into a red test.
    var seen = 0;
    for (final File f in dartSources(lib)) {
      seen += secondary.allMatches(f.readAsStringSync()).length;
    }
    // ONE site today, and that number is the honest measure of this rule's
    // reach. The app overwhelmingly uses positional `Text()` and `title:`;
    // secondary lines carrying localised copy are rare. The narrowing that
    // removed twelve false positives also cut coverage to a single call site.
    //
    // Pinned to a NAMED site rather than a magic threshold, so "the matcher
    // broke" and "the last site was deleted" are different failures.
    expect(
      seen,
      greaterThan(0),
      reason: 'The secondary-line scan matched nothing. The matcher is broken '
          'and the rule below is vacuous.',
    );
    final bool findsKnownSite =
        dartSources(lib).where((File f) => f.path.contains('venue_screen')).any(
              (File f) => secondary
                  .allMatches(f.readAsStringSync())
                  .any((RegExpMatch m) => m.group(2) == 'venueCall'),
            );
    expect(
      findsKnownSite,
      isTrue,
      reason: 'The scan no longer sees `detail: l10n.venueCall` in '
          'venue_screen.dart — the one site this rule is known to cover.',
    );
  });

  test('every use of action copy sits inside something with a handler', () {
    final Map<String, String> keys = actionKeys();
    final List<String> offenders = <String>[];

    for (final File f in dartSources(lib)) {
      final String src = f.readAsStringSync();
      for (final RegExpMatch m in secondary.allMatches(src)) {
        final String key = m.group(2)!;
        if (!keys.containsKey(key)) continue;
        final String? call = enclosingCall(src, m.start);
        if (call == null) continue;
        if (handlers.any(call.contains)) continue;
        final int line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('${f.path}:$line ${m.group(1)}: l10n.$key ("${keys[key]}") '
            'promises an action and the enclosing call has no handler');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Action-shaped copy with nothing attached: ${offenders.join(' | ')} — '
          'either give it a handler, or change the copy so it describes rather '
          'than instructs. "Call venue" sat on a row with no gesture for two '
          'groups; a label promising an action nothing performs is the defect '
          'this rule exists for.',
    );
  });

  test('AND IT CATCHES ONE — guards the guard', () {
    const String fake = "_InfoRow(icon: 'phone', title: x, detail: l10n.venueCall)";
    expect(secondary.hasMatch(fake), isTrue);
    final String? call = enclosingCall(fake, fake.indexOf('l10n.venueCall'));
    expect(call, isNotNull);
    expect(handlers.any(call!.contains), isFalse);

    const String fixed = "_InfoRow(icon: 'phone', title: x, detail: l10n.venueCall, onTap: dial)";
    final String? ok = enclosingCall(fixed, fixed.indexOf('l10n.venueCall'));
    expect(handlers.any(ok!.contains), isTrue);
  });
}
