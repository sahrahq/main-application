/// Coverage and font guards for the golden harness.
///
/// Two failures these catch that a golden diff never will:
///
///   1. A component added with no goldens — it simply has no picture, and no
///      diff can fail for an image nobody takes.
///   2. Goldens rendered in blank boxes because fonts did not load. Those are
///      stable, diffable, and prove nothing. This is the exact failure mode
///      that would have hidden the missing-font bug fixed in f9a6283.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../component_registry.dart';
import '../flutter_test_config.dart';
import '../support/harness.dart';

Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() && pubspec.readAsStringSync().contains('name: sahra_design_system')) {
      return dir;
    }
    dir = dir.parent;
  }
  throw StateError('package root not found');
}

void main() {
  final root = _packageRoot();
  final goldenDir = Directory('${root.path}/test/golden/goldens');

  // THE CENSUS. Everything below iterates `componentGoldens`; an empty
  // registry would make all of it pass while nothing was pictured at all.
  test('every component built so far is registered', () {
    // The wave is not done until each component has a picture in four cells.
    expect(exportedComponents.length, 16, reason: 'All 16 components from docs/design');
  });

  test('the registry is populated', () {
    expect(componentGoldens, isNotEmpty);
    expect(exportedComponents, isNotEmpty);
    expect(
      componentGoldens.length,
      greaterThanOrEqualTo(exportedComponents.length),
      reason: 'Fewer registered variants than exported components',
    );
  });

  group('every component is pictured four times', () {
    test('each registered variant has all four cells on disk', () {
      final missing = <String>[];
      for (final name in componentGoldens.keys) {
        for (final cell in Cell.values) {
          final f = File(
            '${goldenDir.path}/${name.replaceAll('/', '_')}.${cell.slug}.png',
          );
          if (!f.existsSync()) missing.add('${name} [${cell.slug}]');
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'No golden for:\n  ${missing.join('\n  ')}\n'
            'Run: flutter test --update-goldens',
      );
    });

    test('no orphaned goldens — a rename left pictures behind', () {
      final expected = <String>{
        for (final name in componentGoldens.keys)
          for (final cell in Cell.values) '${name.replaceAll('/', '_')}.${cell.slug}.png',
      };
      final actual = goldenDir.existsSync()
          ? goldenDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.png'))
              .map((f) => f.uri.pathSegments.last)
              // `Review_*` are review artefacts (the contrast audit page), not
              // components. They have no registry entry by design.
              .where((n) => !n.startsWith('Review_'))
              .toSet()
          : <String>{};

      expect(actual.difference(expected), isEmpty,
          reason: 'Golden files with no owning component — delete them');
    });

    test('every exported component appears in the registry', () {
      // Guards the registry itself: shipping a widget and forgetting to
      // register it would leave it silently unpictured and unchecked.
      final registered = componentGoldens.keys.map((k) => k.split('/').first).toSet();
      expect(registered, containsAll(exportedComponents));
    });
  });

  group('fonts actually loaded — otherwise every golden is boxes', () {
    testWidgets('the bundled families all exist on disk', (tester) async {
      // Census again: an empty font map would make the loop below a no-op.
      expect(sahraFontAssets.length, 4, reason: 'Expected four bundled families');
      for (final entry in sahraFontAssets.entries) {
        for (final asset in entry.value) {
          expect(File('${root.path}/$asset').existsSync(), isTrue,
              reason: '${entry.key}: missing $asset');
        }
      }
    });

    testWidgets('Arabic renders as glyphs, not as blank boxes', (tester) async {
      // A missing font makes every glyph the same width. Two Arabic strings of
      // equal length would then measure identically no matter what they say,
      // and identical-but-wrong is exactly what a golden cannot detect.
      final widths = <double>[];
      for (final text in <String>['حجز', 'مطعم القاهرة الكبير']) {
        await tester.pumpWidget(
          harness(Cell.arLight, Text(text, style: const TextStyle(fontSize: 24))),
        );
        await tester.pumpAndSettle();
        widths.add(tester.getSize(find.text(text)).width);
      }

      expect(widths[1], greaterThan(widths[0]),
          reason: 'Arabic text is not measuring — fonts did not load');

      // And the family really is the Arabic one, not a silent fallback.
      final theme = SahraTheme.light(locale: const Locale('ar'));
      expect(theme.textTheme.bodyMedium!.fontFamily, SahraTokens.fontArabic.family);
    });

    testWidgets('the Material icon font is loaded too', (tester) async {
      // 15 of the 22 icon names fall back to Material. flutter test does not
      // load that font by default, so every one of them was rendering as an
      // empty box — in goldens that a human was supposed to review.
      expect(
        materialIconsLoaded,
        isTrue,
        reason: 'MaterialIcons-Regular.otf was not loaded. Every fallback icon '
            'will render as tofu and the goldens will be worthless.',
      );
    });

    testWidgets('two different Material icons do not render identically', (tester) async {
      // Tofu is the same box for every codepoint, so identical rendering is
      // the signature of a missing font.
      final sizes = <Size>[];
      for (final icon in <IconData>[Icons.add, Icons.favorite]) {
        await tester.pumpWidget(
          harness(Cell.enLight, Icon(icon, size: 48)),
        );
        await stabilise(tester);
        sizes.add(tester.getSize(find.byType(Icon)));
      }
      expect(sizes.first, sizes.last); // same box, as expected for icons
      expect(materialIconsLoaded, isTrue);
    });

    testWidgets('Latin and Arabic use different families in the same theme', (tester) async {
      final ar = SahraTheme.light(locale: const Locale('ar')).textTheme.bodyMedium!;
      final en = SahraTheme.light(locale: const Locale('en')).textTheme.bodyMedium!;
      expect(ar.fontFamily, isNot(en.fontFamily));
    });
  });
}
