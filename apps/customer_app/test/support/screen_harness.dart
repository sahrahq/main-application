import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// The same four cells every component ships in (ENGINEERING-STANDARDS §3).
/// A screen is not exempt because it is bigger.
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

/// A screen inside a real MaterialApp, with the provider graph overridden.
///
/// `home:` rather than the app's GoRouter, so a golden pictures ONE screen
/// deterministically — routing is exercised by the flow tests, and a router in
/// a golden makes the picture depend on navigation history.
Widget screenHarness(
  Cell cell,
  Widget screen, {
  required List<Override> overrides,
  double textScale = 1.0,
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: cell.theme,
        locale: cell.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...SahraTheme.localizationsDelegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: LocaleSync(child: child ?? const SizedBox.shrink()),
        ),
        home: screen,
      ),
    );

/// `pumpAndSettle` never returns while a Skeleton shimmer is looping, so a
/// fixed pump is used instead — also what makes a golden reproducible.
Future<void> stabilise(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Drive the screen to the state under test before anything is asserted.
///
/// EXISTS FOR THE SHEETS. A modal opened by `showModalBottomSheet` is not a
/// screen the registry can construct — it is a thing a tap produces — so
/// without this the cancel and move sheets would have no golden, no
/// accessibility check and no 200%-text check, while every screen around them
/// had all three. A capability that no matrix covers is the same shape as one
/// that does not exist.
typedef ScreenSettle = Future<void> Function(WidgetTester tester);

/// Four goldens from one call, at phone size.
void screenGoldens(
  String name,
  Widget Function(Cell) build, {
  required List<Override> Function(Cell) overrides,
  ScreenSettle? after,
  Size surface = const Size(390, 844),
}) {
  for (final cell in Cell.values) {
    testWidgets('golden: $name [${cell.slug}]', (tester) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(screenHarness(cell, build(cell), overrides: overrides(cell)));
      await stabilise(tester);
      if (after != null) await after(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name.replaceAll('/', '_')}.${cell.slug}.png'),
      );
    }, tags: 'golden',);
  }
}

/// The §4 guarantees, on a whole screen.
void screenA11y(
  String name,
  Widget Function(Cell) build, {
  required List<Override> Function(Cell) overrides,
  bool interactive = true,
  ScreenSettle? after,
  Size surface = const Size(390, 844),
}) {
  for (final cell in Cell.values) {
    testWidgets('a11y: $name [${cell.slug}]', (tester) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(screenHarness(cell, build(cell), overrides: overrides(cell)));
      await stabilise(tester);
      if (after != null) await after(tester);

      // THE GUARD ON THE GUARDS. All three tap-target and label guidelines
      // SKIP a node with no tap action, so a screen whose controls lost their
      // semantics passes every one of them while being unusable. Assert the
      // tree is operable BEFORE asserting anything about it.
      if (interactive) {
        expect(
          _tappableNodes(tester),
          isNotEmpty,
          reason: '$name exposes no SemanticsAction.tap — every check below '
              'would skip it and pass for the wrong reason.',
        );
      }

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}

/// 200% text. Egyptian users on mid-range Androids run large text more than
/// average, and a RenderFlex overflow is silent in release builds.
void screenTextScale(
  String name,
  Widget Function(Cell) build, {
  required List<Override> Function(Cell) overrides,
  ScreenSettle? after,
  Size surface = const Size(390, 844),
}) {
  for (final cell in Cell.values) {
    testWidgets('text scale 2.0x: $name [${cell.slug}]', (tester) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        screenHarness(cell, build(cell), overrides: overrides(cell), textScale: 2.0),
      );
      await stabilise(tester);
      if (after != null) await after(tester);
      expect(tester.takeException(), isNull);
    });
  }
}

List<SemanticsNode> _tappableNodes(WidgetTester tester) {
  final found = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(SemanticsAction.tap)) found.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // `pipelineOwner`, deprecated, and deliberately.
  //
  // `rootPipelineOwner` is the ROOT of a tree of pipeline owners and carries no
  // semanticsOwner of its own — swapping to it to silence the deprecation
  // threw "Null check operator used on a null value" in all four cells. The
  // guard caught its own breakage, which is the point of the guard-on-the-
  // guards existing at all.
  // ignore: deprecated_member_use
  walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return found;
}
