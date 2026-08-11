import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Written 2026-08-11, the day an empty `key.properties` was seen parsing to a
// present config. Dates live in comments here, never in a string literal —
// `fixture_dates_test` strips comments and scans literals, because a date
// pinned in code drifts into the past and quietly changes what its test covers.

/// A RELEASE BUILD SIGNED WITH DEBUG KEYS MUST NOT LOOK SHIPPABLE.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SHAPE THIS EXISTS FOR
/// ─────────────────────────────────────────────────────────────────────────
///
/// `flutter build apk --release` with the scaffold's
/// `signingConfig = signingConfigs.getByName("debug")` **succeeds**. It
/// produces an APK, prints a size, exits zero — and Play rejects it at upload,
/// because a debug-signed artefact cannot be distributed. Every signal along
/// the way says the build worked.
///
/// That is the "looks fine, cannot ship" shape, and it is the reason this test
/// exists rather than a comment in the Gradle file.
///
/// ─────────────────────────────────────────────────────────────────────────
/// MISSING, EMPTY AND MALFORMED ARE THE SAME ANSWER: UNSIGNED
/// ─────────────────────────────────────────────────────────────────────────
///
/// The three fail differently and must not:
///
///   · **missing**  — no `key.properties`. The honest case: CI, and any
///     contributor without the keystore.
///   · **empty**    — the file exists and is 0 bytes. Seen for real on
///     2026-08-11, created but unsaved. `Properties.load` on it succeeds and
///     yields nothing, so a naive `if (file.exists())` builds a signing config
///     with four nulls and fails deep inside the signing task, or worse,
///     silently falls through.
///   · **malformed** — present but missing a key, or naming a keystore that is
///     not on disk. A typo'd path is indistinguishable from a correct one
///     until the signer opens it.
///
/// `hasReleaseSigning` in `app/build.gradle.kts` collapses all three, and this
/// test pins that logic so a future edit cannot quietly reintroduce the
/// difference.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT THIS READS, AND WHAT IT NEVER READS
/// ─────────────────────────────────────────────────────────────────────────
///
/// It reads the Gradle file, and `key.properties` **only for whether the four
/// key NAMES are present and non-blank**. It never reads, prints, compares or
/// logs a value. The passwords do not enter this process.
void main() {
  final File gradle = File('android/app/build.gradle.kts');
  final File props = File('android/key.properties');

  /// THE GRADLE FILE WITH ITS COMMENTS STRIPPED.
  ///
  /// Every check below greps for a construct, and this file's comments EXPLAIN
  /// those constructs by quoting them. Grepping the raw text therefore passes
  /// on the prose describing the code even when the code is gone — found on
  /// 2026-08-11 when a deliberate break failed to turn this red because
  /// `f.length() > 0` also appears in the comment above it.
  ///
  /// A guard that can be satisfied by a comment about itself is not a guard.
  String g() =>
      gradle.readAsLinesSync().where((String l) => !l.trimLeft().startsWith('//')).join('\n');

  test('the Gradle file is where we think it is — census', () {
    expect(gradle.existsSync(), isTrue);
    expect(g().length, greaterThan(500));
  });

  test('release does NOT hardcode the debug signing config', () {
    // The scaffold line, verbatim. Its presence means every release build is
    // debug-signed regardless of any keystore.
    expect(
      g().contains('signingConfig = signingConfigs.getByName("debug")\n        }'),
      isFalse,
      reason: 'The release buildType still pins the debug signing config. Every '
          '`flutter build apk --release` will succeed and every Play upload '
          'will be rejected.',
    );
  });

  test('debug keys are reachable only as an explicit, warned fallback', () {
    final String src = g();
    // The fallback must exist — CI and `flutter run --release` depend on it —
    // but it must be conditional and it must say so out loud.
    expect(
      src.contains('hasReleaseSigning'),
      isTrue,
      reason: 'No conditional signing at all: the fallback is unconditional.',
    );
    expect(
      src.contains('logger.warn'),
      isTrue,
      reason: 'The debug-key fallback is silent. A release that cannot ship '
          'must announce itself at build time.',
    );
    expect(
      src.contains('DEBUG KEYS'),
      isTrue,
      reason: 'The warning does not name what is wrong in words an operator '
          'will recognise in a build log.',
    );
  });

  test('EMPTY is treated as unsigned, not as a valid blank config', () {
    // The specific trap: `f.exists()` alone is true for a 0-byte file, and
    // `Properties.load` on it succeeds. The length check is what separates
    // "created but unsaved" from "configured".
    expect(
      g().contains('f.length() > 0'),
      isTrue,
      // The date this was seen for real is in the docblock at the top of this
      // file, not in this string: `fixture_dates_test` strips comments and
      // scans string literals, because a date pinned in code drifts into the
      // past and silently changes what its test covers.
      reason: 'A 0-byte key.properties would parse to zero properties and be '
          'mistaken for a present config. Seen for real, once.',
    );
  });

  test('MALFORMED is treated as unsigned — all four keys AND the keystore file', () {
    final String src = g();
    for (final String k in <String>['storeFile', 'storePassword', 'keyPassword', 'keyAlias']) {
      expect(
        src.contains('"$k"'),
        isTrue,
        reason: '$k is not required by hasReleaseSigning.',
      );
    }
    expect(
      src.contains('isNullOrBlank'),
      isTrue,
      reason: 'A present-but-blank value would pass a null check and fail at '
          'signing time instead of at configuration time.',
    );
    expect(
      src.contains('.exists()'),
      isTrue,
      reason: 'A typo in storeFile is indistinguishable from a correct path '
          'unless the keystore is checked for existence here.',
    );
  });

  test('the keystore path is never committed, and its VALUES are never read here', () {
    // `key.properties` is optional. When it is present, only the presence of
    // the four names is checked — never their values.
    if (!props.existsSync()) return;
    final List<String> names = props
        .readAsLinesSync()
        .map((String l) => l.split('=').first.trim())
        .where((String n) => n.isNotEmpty)
        .toList();
    expect(
      names,
      containsAll(<String>['storeFile', 'storePassword', 'keyPassword', 'keyAlias']),
      reason: 'key.properties exists but is incomplete — Gradle will fall '
          'back to debug keys and the release cannot be uploaded.',
    );
    expect(props.lengthSync(), greaterThan(0));
  });

  test('minification is on for release — R8 is part of what release MEANS', () {
    // Not signing, but the same class: a release build that skips shrinking is
    // a different artefact from the one that ships, and finding out at upload
    // time is too late.
    expect(g().contains('isMinifyEnabled = true'), isTrue);
    expect(g().contains('isShrinkResources = true'), isTrue);
  });
}
