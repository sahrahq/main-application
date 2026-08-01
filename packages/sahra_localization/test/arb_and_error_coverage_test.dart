/// The test that keeps the two halves of this repo honest with each other.
///
/// It reads the NestJS source directly. That coupling is deliberate: the
/// alternative is a hand-kept list of error codes, and a hand-kept list is a
/// list that is wrong within a month. A backend engineer adding
/// `code: 'table_on_fire'` breaks the Flutter suite, which is the only moment
/// anyone would notice the diner has no copy for it.
import 'dart:convert';
import 'dart:io';

import 'package:sahra_localization/sahra_localization.dart';
import 'package:test/test.dart';

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/apps/api/src').existsSync() &&
        Directory('${dir.path}/packages').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}

Map<String, dynamic> _arb(Directory root, String locale) => jsonDecode(
      File('${root.path}/packages/sahra_localization/lib/l10n/app_$locale.arb')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

/// Message keys only — `@@locale`, `@@x-…` metadata and `@key` descriptors are
/// ARB bookkeeping, not copy.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Every `code: '…'` literal in the API source.
Set<String> _backendCodes(Directory root) {
  final pattern = RegExp(r"""code:\s*'([a-z_]+)'""");
  final codes = <String>{};
  for (final f in Directory('${root.path}/apps/api/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.ts'))) {
    for (final m in pattern.allMatches(f.readAsStringSync())) {
      codes.add(m.group(1)!);
    }
  }
  return codes;
}

void main() {
  final root = _repoRoot();
  final en = _arb(root, 'en');
  final ar = _arb(root, 'ar');
  final enKeys = _messageKeys(en);
  final arKeys = _messageKeys(ar);

  group('ARB parity', () {
    test('every English key exists in Arabic', () {
      expect(enKeys.difference(arKeys), isEmpty,
          reason: 'Missing from app_ar.arb — an English string would ship to Arabic users');
    });

    test('every Arabic key exists in English', () {
      expect(arKeys.difference(enKeys), isEmpty, reason: 'Orphaned keys in app_ar.arb');
    });

    test('no value is empty', () {
      for (final k in enKeys) {
        expect((en[k] as String).trim(), isNotEmpty, reason: 'en.$k is empty');
      }
      for (final k in arKeys) {
        expect((ar[k] as String).trim(), isNotEmpty, reason: 'ar.$k is empty');
      }
    });

    test('no Arabic value is byte-identical to its English one', () {
      // How an untranslated placeholder ships: copy the English in, mean to
      // come back to it, never come back to it.
      final same = enKeys.where((k) => en[k] == ar[k]).toList();
      expect(same, isEmpty, reason: 'Untranslated (identical to English): ${same.join(', ')}');
    });

    test('every Arabic value actually contains Arabic script', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final latinOnly = arKeys.where((k) => !arabic.hasMatch(ar[k] as String)).toList();
      expect(latinOnly, isEmpty, reason: 'No Arabic script in: ${latinOnly.join(', ')}');
    });

    test('placeholders match across locales', () {
      final ph = RegExp(r'\{(\w+)\}');
      for (final k in enKeys) {
        final inEn = ph.allMatches(en[k] as String).map((m) => m.group(1)).toSet();
        final inAr = ph.allMatches(ar[k] as String).map((m) => m.group(1)).toSet();
        expect(inAr, inEn, reason: 'Placeholder mismatch on "$k" — one locale would crash');
      }
    });
  });

  group('backend error codes are all reachable as copy', () {
    final codes = _backendCodes(root);

    test('the extraction found a plausible number of codes', () {
      // Guards the guard: a refactor that changes how errors are thrown could
      // silently make this scan return nothing, and an empty set trivially
      // satisfies every assertion below.
      expect(codes.length, greaterThanOrEqualTo(40),
          reason: 'Only found ${codes.length} codes — has the API error shape changed?');
    });

    test('every backend code maps to an ARB key', () {
      final unmapped = codes.difference(errorCodeToArbKey.keys.toSet()).toList()..sort();
      expect(
        unmapped,
        isEmpty,
        reason: 'Backend codes with no client mapping:\n  ${unmapped.join('\n  ')}\n'
            'Add them to errorCodeToArbKey and to BOTH .arb files.',
      );
    });

    test('every mapped ARB key exists in both locales', () {
      for (final entry in errorCodeToArbKey.entries) {
        expect(enKeys, contains(entry.value), reason: '${entry.key} → missing en copy');
        expect(arKeys, contains(entry.value), reason: '${entry.key} → missing ar copy');
      }
    });

    test('the mapping has no entries the backend never sends', () {
      final stale = errorCodeToArbKey.keys.toSet().difference(codes).toList()..sort();
      expect(stale, isEmpty, reason: 'Dead mappings for codes the API no longer emits: $stale');
    });

    test('client-only keys exist too', () {
      for (final key in clientOnlyArbKeys) {
        expect(enKeys, contains(key));
        expect(arKeys, contains(key));
      }
    });
  });

  group('the Arabic is flagged UNREVIEWED until a native speaker signs it off', () {
    test('both files declare their review status', () {
      // Removing this banner is the product owner's deliberate act and shows
      // up in a diff — see the launch-blocker decision record.
      expect(ar['@@x-review-status'], 'UNREVIEWED');
      expect(en['@@x-review-status'], 'UNREVIEWED');
    });
  });
}
