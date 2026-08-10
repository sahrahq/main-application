import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// The four cells every component is rendered in.
///
/// Not three, not "the important ones". Arabic-dark is the combination nobody
/// checks by hand and the one where a hardcoded colour or a `left` padding
/// shows up.
enum Cell {
  arLight(Locale('ar'), Brightness.light, 'ar.light'),
  arDark(Locale('ar'), Brightness.dark, 'ar.dark'),
  enLight(Locale('en'), Brightness.light, 'en.light'),
  enDark(Locale('en'), Brightness.dark, 'en.dark');

  const Cell(this.locale, this.brightness, this.slug);
  final Locale locale;
  final Brightness brightness;
  final String slug;

  ThemeData get theme => brightness == Brightness.dark
      ? SahraTheme.dark(locale: locale)
      : SahraTheme.light(locale: locale);
}

/// Wrap a component in the smallest real app that still exercises theme,
/// locale and direction.
Widget harness(Cell cell, Widget child, {double textScale = 1.0}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: cell.theme,
      locale: cell.locale,
      supportedLocales: SahraTheme.supportedLocales,
      localizationsDelegates: SahraTheme.localizationsDelegates,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            backgroundColor: cell.theme.sahra.surfacePage,
            body: Center(child: Padding(padding: SahraSpace.all(SahraSpace.s4), child: child)),
          ),
        ),
      ),
    );

/// Advance to a FIXED, reproducible frame.
///
/// `pumpAndSettle` never returns for a component with a looping animation —
/// the Skeleton shimmer repeats forever by design, so "settled" is a state it
/// never reaches. Pumping a fixed duration instead is deterministic for both:
/// a controller starts at 0, so 400ms into a 1600ms loop is the same phase on
/// every run, and a static widget simply ignores the time.
Future<void> stabilise(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Four goldens from one call.
///
/// [name] becomes `goldens/<name>.<cell>.png`. Writing the matrix by hand is
/// how a component ends up with two goldens instead of four, so it is not
/// offered.
///
/// [build] receives the cell so a component can be given locale-appropriate
/// copy — a design-system component owns no strings; it is handed them, and
/// the golden has to show real Arabic to be worth anything.

void goldenMatrix(String name, Widget Function(Cell cell) build, {Size? surface}) {
  for (final cell in Cell.values) {
    testWidgets('golden: $name [${cell.slug}]', (tester) async {
      tester.view.physicalSize = surface ?? const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(cell, build(cell)));
      await stabilise(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name.replaceAll('/', '_')}.${cell.slug}.png'),
      );
    }, tags: 'golden');
  }
}

/// The accessibility guarantees from ENGINEERING-STANDARDS §4, applied to one
/// widget in all four cells.
///
/// All four checks ship in `flutter_test`; no dependency is added for them.

void a11yMatrix(String name, Widget Function(Cell cell) build, {bool interactive = true}) {
  for (final cell in Cell.values) {
    testWidgets('a11y: $name [${cell.slug}]', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(cell, build(cell)));
      await stabilise(tester);

      // THE GUARD ON THE GUARDS. Every tap-target and label guideline below
      // SKIPS a semantics node that has no tap action — so a component whose
      // action was accidentally stripped passes all three while being
      // unusable with a screen reader. That is precisely what happened to
      // SahraButton on day one (`excludeSemantics: true` swallowed the
      // InkWell's action), and all four checks reported green.
      //
      // Assert the tree is actually operable BEFORE asserting anything about
      // it, so a vacuous pass is impossible.
      if (interactive) {
        final tappable = _tappableNodes(tester);
        expect(
          tappable,
          isNotEmpty,
          reason: '$name exposes no SemanticsAction.tap. A screen reader would '
              'announce it and be unable to activate it — and every guideline '
              'below would skip it and pass for the wrong reason.',
        );
      }

      // 44pt (iOS) and 48dp (Android) hit boxes.
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // Every tappable thing announces something.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // The palette is warm and low-contrast by design; assumption is not
      // enough. Note this guideline SKIPS text drawn over an image.
      await expectContrast(tester, '$name [${cell.slug}]');

      handle.dispose();
    });
  }
}

/// `textContrastGuideline`, with the explanation attached to the failure.
///
/// The guideline samples RENDERED PIXELS and regularly lands on an anti-aliased
/// glyph edge, where — on our surfaces — no colour at all can clear AA. It has
/// produced two false colour investigations here. The caveat now travels with
/// the failure rather than living only in a decision doc, and it sits beside
/// `bestPossibleEdgeContrast`, which is what proves it
/// (`test/a11y/palette_contrast_test.dart`).
Future<void> expectContrast(WidgetTester tester, String where) async {
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } on TestFailure catch (e) {
    throw TestFailure('${e.message}\n\n$where$kEdgeSampledContrastCaveat');
  }
}

/// A screen that overflows at 200% text is broken for a large share of
/// Egyptian users, and overflow is silent in release builds. `RenderFlex`
/// throws in debug, so this catches it.

void textScaleMatrix(String name, Widget Function(Cell cell) build, {double scale = 2.0}) {
  for (final cell in Cell.values) {
    testWidgets('text scale ${scale}x: $name [${cell.slug}]', (tester) async {
      await tester.pumpWidget(harness(cell, build(cell), textScale: scale));
      await stabilise(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '$name overflows at ${scale}x text in ${cell.slug}',
      );
    });
  }
}

/// Semantics nodes that a screen reader could actually activate.
List<SemanticsNode> _tappableNodes(WidgetTester tester) {
  final found = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(SemanticsAction.tap)) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.rootElement!.renderObject!.debugSemantics!);
  return found;
}
