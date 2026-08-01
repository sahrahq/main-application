// Every font family the tokens name must actually ship.
//
// WRITTEN BEFORE THE PUBSPEC DECLARATIONS EXIST.
//
// The failure this prevents is silent: Flutter does not error on an unknown
// font family, it quietly substitutes the platform default. So an Arabic
// screen renders in Roboto instead of IBM Plex Sans Arabic, looks *fine* in a
// screenshot to anyone not reading Arabic closely, and ships. Nothing in a
// widget test would catch it either — the TextStyle still says the right
// family name.
//
// This asserts the whole chain: the token names a family, the pubspec declares
// it, and the file it points at exists on disk and is a real font.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final p = Directory('${dir.path}/packages/sahra_design_system');
    if (p.existsSync()) return p;
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/pubspec.yaml').readAsStringSync().contains('name: sahra_design_system')) {
      return dir;
    }
    dir = dir.parent;
  }
  throw StateError('package root not found from ${Directory.current.path}');
}

/// Families that are intentionally NOT bundled because they are platform
/// faces, not something we can or should redistribute. `font-mono` is a system
/// stack end to end — SFMono on Apple, Consolas on Windows — and bundling a
/// monospace face for the handful of places we use one would cost more bytes
/// than it earns.
const _systemFamilies = <String>{
  'SFMono-Regular',
  '-apple-system',
  'BlinkMacSystemFont',
};

/// (family, declared assets) parsed out of the pubspec `flutter: fonts:` block.
Map<String, List<String>> _declaredFonts(String pubspec) {
  final out = <String, List<String>>{};
  String? family;
  for (final line in pubspec.split('\n')) {
    final fam = RegExp(r'^\s*-\s*family:\s*(.+?)\s*$').firstMatch(line);
    if (fam != null) {
      family = fam.group(1)!;
      out[family] = <String>[];
      continue;
    }
    final asset = RegExp(r'^\s*-\s*asset:\s*(.+?)\s*$').firstMatch(line);
    if (asset != null && family != null) out[family]!.add(asset.group(1)!);
  }
  return out;
}

void main() {
  final root = _packageRoot();
  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  final declared = _declaredFonts(pubspec);

  /// Every `font-*` token, by the family it actually asks for.
  final tokenFamilies = <String, SahraFontStack>{
    'font-latin': SahraTokens.fontLatin,
    'font-arabic': SahraTokens.fontArabic,
    'font-arabic-display': SahraTokens.fontArabicDisplay,
    'font-display': SahraTokens.fontDisplay,
    'font-mono': SahraTokens.fontMono,
  };

  group('every family named in tokens.json ships', () {
    test('the token list here covers every font token in the theme', () {
      // Guards this test against going stale: a new font-* token in
      // tokens.json must be added above, or this fails.
      final fontTokens = SahraTokens.byToken.entries
          .where((e) => e.value is SahraFontStack)
          .map((e) => e.key)
          .toSet();
      expect(tokenFamilies.keys.toSet(), fontTokens);
    });

    for (final entry in <String, SahraFontStack>{...tokenFamilies}.entries) {
      test('${entry.key} → "${entry.value.family}"', () {
        final family = entry.value.family;
        if (_systemFamilies.contains(family)) return; // documented exception

        expect(
          declared.keys,
          contains(family),
          reason: 'Token ${entry.key} asks for "$family", which pubspec.yaml does not '
              'declare. Flutter will silently fall back to the platform font — '
              'no error, no failing widget test, just the wrong typeface in '
              'production.',
        );
        expect(declared[family], isNotEmpty, reason: '"$family" is declared with no assets');
      });
    }
  });

  group('every declared asset is a real font file', () {
    test('files exist and carry a TrueType/OpenType signature', () {
      for (final entry in declared.entries) {
        for (final asset in entry.value) {
          final f = File('${root.path}/$asset');
          expect(f.existsSync(), isTrue, reason: '${entry.key}: missing $asset');

          // 0x00010000 (TrueType) or "OTTO" (CFF). A truncated download or an
          // HTML error page saved as .ttf would pass an existence check and
          // fail only at runtime, on a device.
          final magic = f.readAsBytesSync().sublist(0, 4);
          final isTrueType =
              magic[0] == 0x00 && magic[1] == 0x01 && magic[2] == 0x00 && magic[3] == 0x00;
          final isOtto = String.fromCharCodes(magic) == 'OTTO';
          expect(
            isTrueType || isOtto,
            isTrue,
            reason: '$asset is not a font file (magic: $magic)',
          );
          expect(f.lengthSync(), greaterThan(10000), reason: '$asset is suspiciously small');
        }
      }
    });

    test('each bundled family ships its OFL licence', () {
      // All four families are SIL Open Font License. Redistributing them
      // without the licence text is the one thing the OFL actually forbids.
      for (final family in declared.keys) {
        final slug = family.replaceAll(' ', '');
        final licence = File('${root.path}/fonts/OFL-$slug.txt');
        expect(
          licence.existsSync(),
          isTrue,
          reason: 'No OFL-$slug.txt for bundled family "$family"',
        );
        expect(licence.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
      }
    });
  });

  group('the weights the type scale uses are declared', () {
    test('Arabic UI ships regular, medium and semibold', () {
      // SahraTypography uses w400 body, w500 labels, w600 headings.
      final assets = declared[SahraTokens.fontArabic.family] ?? <String>[];
      expect(assets.length, greaterThanOrEqualTo(3),
          reason: 'Arabic UI text uses three weights; static faces are needed for each');
    });

    test('variable display faces are declared once and driven by an axis', () {
      // Reem Kufi and Newsreader ship as variable fonts. Declaring the same
      // file under several `weight:` keys does NOT interpolate the axis —
      // Flutter picks a file, it does not set `wght`. The weight has to come
      // from FontVariation instead, so exactly one asset per family is right.
      for (final family in <String>[
        SahraTokens.fontArabicDisplay.family,
        SahraTokens.fontDisplay.family,
      ]) {
        expect(declared[family]?.length, 1,
            reason: '"$family" is variable — one asset, weight via FontVariation');
      }
    });
  });
}
