// The guard that makes tokens.json the single source of truth.
//
// Two independent failures are caught here:
//
//   1. A token exists in tokens.json but has no value in the generated theme.
//      Adding a token later cannot silently go unimplemented.
//   2. tokens.g.dart is stale — someone edited the JSON without regenerating,
//      or (worse) edited the generated file by hand.
//
// Without (2), (1) can be satisfied by editing the generated file directly,
// which is exactly the drift the generator exists to prevent.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../tool/generate_tokens.dart' as generator;

File _repoFile(String relative) {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final f = File('${dir.path}/$relative');
    if (f.existsSync()) return f;
    dir = dir.parent;
  }
  throw StateError('Could not locate $relative from ${Directory.current.path}');
}

Map<String, Map<String, String>> _tokensJson() {
  final raw = jsonDecode(_repoFile('docs/design/tokens.json').readAsStringSync())
      as Map<String, dynamic>;
  return raw.map(
    (k, v) => MapEntry(k, (v as Map<String, dynamic>).cast<String, String>()),
  );
}

void main() {
  final tokens = _tokensJson();
  final root = tokens['root']!;
  final night = tokens['themeNight']!;

  group('tokens.json is fully implemented', () {
    test('the counts CLAUDE.md states are the counts in the file', () {
      // CLAUDE.md: "75 light + 10 night". If this changes, CLAUDE.md is now
      // wrong too — fix both, deliberately.
      expect(root.length, 75, reason: 'root token count changed');
      expect(night.length, 10, reason: 'themeNight token count changed');
    });

    test('every LIGHT token has a value in the light theme', () {
      final themed = SahraSemantics.light().byToken;
      final missing = root.keys.where((k) => !themed.containsKey(k)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'Tokens present in tokens.json but absent from the light theme:\n'
            '${missing.join('\n')}\n'
            'Run: dart run tool/generate_tokens.dart',
      );
    });

    test('every NIGHT override has a value in the dark theme', () {
      final themed = SahraSemantics.dark().byToken;
      final missing = night.keys.where((k) => !themed.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'Missing night tokens: ${missing.join(', ')}');
    });

    test('the dark theme actually differs on all 10 night tokens', () {
      // Presence is not enough: a night token mapped to its light value would
      // pass the check above while dark mode quietly stayed light.
      final light = SahraSemantics.light().byToken;
      final dark = SahraSemantics.dark().byToken;
      for (final key in night.keys) {
        expect(
          dark[key],
          isNot(equals(light[key])),
          reason: '"$key" is identical in both themes — the night override is not wired up',
        );
      }
    });

    test('every token value has the right Dart type for its shape', () {
      final themed = SahraSemantics.light().byToken;
      for (final entry in root.entries) {
        final value = themed[entry.key]!;
        final resolved = _resolveVar(entry.value, root);
        if (resolved.startsWith('#')) {
          expect(value, isA<Color>(), reason: '${entry.key} should be a Color');
        } else if (resolved.endsWith('px') || RegExp(r'^-?[\d.]+$').hasMatch(resolved)) {
          expect(value, isA<double>(), reason: '${entry.key} should be a double');
        } else if (resolved.contains('rgba(')) {
          expect(value, isA<List<BoxShadow>>(), reason: '${entry.key} should be shadows');
        }
      }
    });
  });

  group('the generated file cannot drift', () {
    test('tokens.g.dart matches what the generator produces from tokens.json', () {
      final expected = generator.generate(_repoFile('docs/design/tokens.json').readAsStringSync());
      final actual = _repoFile(
        'packages/sahra_design_system/lib/src/generated/tokens.g.dart',
      ).readAsStringSync();

      expect(
        actual.replaceAll('\r\n', '\n').trimRight(),
        expected.replaceAll('\r\n', '\n').trimRight(),
        reason: 'tokens.g.dart is stale or was hand-edited.\n'
            'Run: dart run tool/generate_tokens.dart',
      );
    });
  });

  group('spot checks against the raw JSON', () {
    test('a colour is exactly the hex in the file', () {
      expect(SahraTokens.terracotta, const Color(0xFFC64A2B));
      expect(root['terracotta'], '#C64A2B');
    });

    test('an alias resolves to its target, not a copy', () {
      // accent -> var(--terracotta)
      expect(root['accent'], 'var(--terracotta)');
      expect(SahraTokens.accent, same(SahraTokens.terracotta));
    });

    test('dark surfaces come from the night ramp', () {
      expect(SahraSemantics.dark().surfacePage, SahraTokens.night);
      expect(SahraSemantics.dark().textBody, SahraTokens.nightText);
    });

    test('terracotta is unmodified in BOTH themes (DESIGN-RULES.md)', () {
      expect(SahraSemantics.dark().accent, SahraSemantics.light().accent);
      expect(SahraSemantics.dark().accent, SahraTokens.terracotta);
    });

    test('a shadow parses every layer', () {
      expect(SahraTokens.shadow1.length, 2);
      expect(SahraTokens.shadow2.length, 2);
      expect(SahraTokens.shadow3.length, 2);
    });

    test('a font stack keeps its fallbacks', () {
      expect(SahraTokens.fontArabic.family, 'IBM Plex Sans Arabic');
      expect(SahraTokens.fontArabic.fallback, contains('Poppins'));
    });
  });
}

String _resolveVar(String value, Map<String, String> all) {
  final m = RegExp(r'^var\(--([a-z0-9-]+)\)$').firstMatch(value);
  return m == null ? value : _resolveVar(all[m.group(1)]!, all);
}
