import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter_test_config.dart';
import '../screen_registry.dart';
import '../support/screen_harness.dart';

/// Coverage and font guards for the SCREEN goldens.
///
/// The same two failures the component version catches, one level up: a screen
/// state with no picture, and pictures taken in a font that never loaded.
void main() {
  final goldenDir = Directory('test/golden/goldens');

  group('the census', () {
    test('the registry is populated', () {
      // Everything below iterates `screenCases`. An empty registry would make
      // all of it pass while nothing was pictured at all — the failure mode
      // the contrast census hit twice.
      expect(screenCases, isNotEmpty);
      expect(screenCases.length, greaterThanOrEqualTo(10));
    });

    test('every screen in the booking path has at least one state pictured', () {
      // OBSERVED off the registry keys, never recomputed from the same source
      // as the thing being checked.
      final screens = screenCases.keys.map((k) => k.split('/').first).toSet();
      expect(screens, containsAll(<String>{'Search', 'Venue', 'Book', 'Confirmed'}));
    });

    test('the four states are all represented somewhere', () {
      // Not "a screen has four goldens" — that would be satisfied by four
      // pictures of the same content. These are the states that go wrong.
      expect(screenCases.keys, contains('Search/results')); // content
      expect(screenCases.keys, contains('Search/no-results')); // empty
      expect(screenCases.keys, contains('Search/outage')); // error
      expect(screenCases.keys, contains('Search/offline')); // error, other kind
      expect(screenCases.keys, contains('Book/no-slots')); // empty, elsewhere
      expect(screenCases.keys, contains('Venue/not-found')); // error, elsewhere
    });
  });

  test('every registered state has all four cells on disk', () {
    final missing = <String>[];
    for (final name in screenCases.keys) {
      for (final cell in Cell.values) {
        final f = File('${goldenDir.path}/${name.replaceAll('/', '_')}.${cell.slug}.png');
        if (!f.existsSync()) missing.add('$name [${cell.slug}]');
      }
    }
    expect(missing, isEmpty,
        reason: 'No golden for:\n  ${missing.join('\n  ')}\n'
            'Run: flutter test --update-goldens --tags golden',);
  });

  test('no orphaned goldens — a rename left pictures behind', () {
    final expected = <String>{
      for (final name in screenCases.keys)
        for (final cell in Cell.values) '${name.replaceAll('/', '_')}.${cell.slug}.png',
    };
    final actual = goldenDir.existsSync()
        ? goldenDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .map((f) => f.uri.pathSegments.last)
            .toSet()
        : <String>{};
    expect(actual.difference(expected), isEmpty);
  });

  group('the pictures can actually show what they claim', () {
    testWidgets('Arabic measures as glyphs, not as blank boxes', (tester) async {
      // A missing font draws every glyph as the same box, so two DIFFERENT
      // Arabic strings would measure the same. Existence checks cannot catch
      // that; different content producing different output can.
      final widths = <double>[];
      for (final text in <String>['حجز', 'مطعم القاهرة الكبير']) {
        await tester.pumpWidget(
          screenHarness(Cell.arLight, Center(child: Text(text, style: const TextStyle(fontSize: 24))),
              overrides: const <Override>[],),
        );
        await stabilise(tester);
        widths.add(tester.getSize(find.text(text)).width);
      }
      expect(widths[1], greaterThan(widths[0]),
          reason: 'Arabic is not measuring — the fonts did not load, and every '
              'screen golden is a picture of boxes',);
    });

    testWidgets('the Material icon font is loaded', (tester) async {
      // 15 of the 22 icon names are Material fallbacks. `flutter test` does
      // not load that font, and the first time this was missed, 15 icons were
      // empty squares in goldens a human was reviewing.
      expect(materialIconsLoaded, isTrue);
    });
  });
}
