import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// EVERY TEXT STYLE HAS TO RESOLVE TO A SAHRA FAMILY.
///
/// This exists because five of Material's fifteen text slots were left
/// undefined in `SahraTypography._build`, and an undefined slot does not throw
/// — `ThemeData` quietly fills it from its own typography, which inherits
/// `ThemeData.fontFamily`: Poppins, the Latin UI face, which has no Arabic
/// glyphs. The bookings list wrote `textTheme.titleMedium` and every venue
/// name rendered as empty boxes, in Arabic only. A human looking at a golden
/// caught it; nothing else did.
///
/// ─────────────────────────────────────────────────────────────────────────
/// TWO CHECKS THAT LOOK RIGHT AND ARE NOT. Do not reintroduce either.
/// ─────────────────────────────────────────────────────────────────────────
///
/// **`expect(style, isNotNull)`** can never fail. ThemeData has already
/// substituted a Poppins style by the time anyone can read it back — the hole
/// is invisible from the outside, which is the entire reason it survived.
///
/// **Measuring two Arabic strings and asserting the longer one is wider** is
/// the technique `screen_coverage_test.dart` uses to prove fonts loaded at
/// all, and it does not work here. When a glyph is missing, `flutter_test`
/// draws a FIXED-WIDTH box, so a 19-character string is still wider than a
/// 3-character one and the check passes on pure tofu. It detects "no font
/// loaded"; it cannot detect "the wrong font". This was written that way
/// first, and the deliberate break — deleting `titleMedium` again — passed it.
///
/// What follows asserts the family by name, which is exact, and which fails
/// the moment a slot falls back.
void main() {
  /// Named, so a failure says which slot rather than which index.
  final Map<String, TextStyle? Function(TextTheme)> slots =
      <String, TextStyle? Function(TextTheme)>{
    'displayLarge': (t) => t.displayLarge,
    'displayMedium': (t) => t.displayMedium,
    'displaySmall': (t) => t.displaySmall,
    'headlineLarge': (t) => t.headlineLarge,
    'headlineMedium': (t) => t.headlineMedium,
    'headlineSmall': (t) => t.headlineSmall,
    'titleLarge': (t) => t.titleLarge,
    'titleMedium': (t) => t.titleMedium,
    'titleSmall': (t) => t.titleSmall,
    'bodyLarge': (t) => t.bodyLarge,
    'bodyMedium': (t) => t.bodyMedium,
    'bodySmall': (t) => t.bodySmall,
    'labelLarge': (t) => t.labelLarge,
    'labelMedium': (t) => t.labelMedium,
    'labelSmall': (t) => t.labelSmall,
  };

  test('the census covers all fifteen Material slots', () {
    // A slot missing from this MAP is a slot missing from the check, which is
    // the same hole one level up.
    expect(slots.length, 15);
  });

  test('every slot in the Arabic theme uses an Arabic-capable family', () {
    final arabic = <String>{
      SahraTokens.fontArabic.family,
      SahraTokens.fontArabicDisplay.family,
    };

    final wrong = <String>[];
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.dark
          ? SahraTheme.dark(locale: const Locale('ar'))
          : SahraTheme.light(locale: const Locale('ar'));

      for (final entry in slots.entries) {
        final family = entry.value(theme.textTheme)?.fontFamily;
        if (!arabic.contains(family)) {
          wrong.add('${brightness.name}/${entry.key} → ${family ?? 'null'}');
        }
      }
    }

    expect(wrong, isEmpty,
        reason: 'These resolve to a font with no Arabic glyphs. Every screen '
            'using one shows empty boxes to half the market:\n  '
            '${wrong.join('\n  ')}',);
  });

  test('every slot in the Latin theme uses a SAHRA family', () {
    final latin = <String>{
      SahraTokens.fontLatin.family,
      SahraTokens.fontDisplay.family,
    };

    final wrong = <String>[];
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.dark
          ? SahraTheme.dark(locale: const Locale('en'))
          : SahraTheme.light(locale: const Locale('en'));

      for (final entry in slots.entries) {
        final family = entry.value(theme.textTheme)?.fontFamily;
        if (!latin.contains(family)) {
          wrong.add('${brightness.name}/${entry.key} → ${family ?? 'null'}');
        }
      }
    }

    // Latin fails less loudly — Roboto draws English perfectly well, so a hole
    // here is a font inconsistency rather than an unreadable screen. It is
    // still a hole, and it is the same hole.
    expect(wrong, isEmpty, reason: 'Not a SAHRA family:\n  ${wrong.join('\n  ')}');
  });
}
