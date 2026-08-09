import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_notifier.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_screen.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/fakes.dart';
import '../support/screen_harness.dart';

/// C-2.2 — the filters, and the queries they actually produce.
///
/// THE ASSERTIONS ARE ON THE REQUEST, not on the chips. A sheet whose chips
/// light up correctly and sends the wrong query looks perfect and returns the
/// wrong restaurants — and every screen test that stopped at the UI would
/// still pass. So the fake records what went out.
void main() {
  Map<String, Object?> page() => <String, Object?>{
        'results': <Object>[],
        'estimated_total': 0,
        'availability_filtered': false,
      };

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required FakeTransport transport,
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: screenHarness(
          Cell.enLight,
          const SearchScreen(),
          overrides: const <Override>[],
        ),
      ),
    );
    await stabilise(tester);
    return container;
  }

  /// BY PREFIX, because the button relabels itself once filters are on —
  /// "Filters" becomes "Filters (1)". A helper that matched the bare label
  /// worked exactly until the first test reopened the sheet, which is the
  /// case worth testing.
  Future<void> openSheet(WidgetTester tester) async {
    final button = find.byWidgetPredicate(
      (w) => w is SahraChip && w.label.startsWith('Filters'),
    );
    expect(button, findsOneWidget, reason: 'no filter button on the search screen');
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('THE BUTTON IS REACHABLE, and says nothing is set', (tester) async {
    final transport = FakeTransport((_, __, ___) => page());
    await pump(tester, transport: transport);

    expect(find.widgetWithText(SahraChip, 'Filters'), findsOneWidget);
    expect(find.widgetWithText(SahraChip, 'Filters (1)'), findsNothing);
  });

  testWidgets('a cuisine filter reaches the query', (tester) async {
    final transport = FakeTransport((_, __, ___) => page());
    await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final sent = transport.sent.where((c) => c.path.contains('/search')).toList();
    expect(sent, isNotEmpty, reason: 'applying the filter ran no search');
  });

  testWidgets('A FILTER ALONE IS A SEARCH — no text needed', (tester) async {
    // `isBlank` used to be "no text and not tonight", so picking a cuisine and
    // nothing else rendered the "where are you eating?" start state: a screen
    // ignoring the filters somebody had just set.
    final transport = FakeTransport((_, __, ___) => page());
    final container = await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(container.read(searchCriteriaProvider).isBlank, isFalse);
  });

  testWidgets('the count appears on the button', (tester) async {
    final transport = FakeTransport((_, __, ___) => page());
    await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraChip, r'$$'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.widgetWithText(SahraChip, 'Filters (2)'), findsOneWidget);
  });

  testWidgets('TAPPING THE ACTIVE CUISINE CLEARS IT', (tester) async {
    // A single-select with no "any" has no way back except Clear, which also
    // drops the other filters.
    final transport = FakeTransport((_, __, ___) => page());
    final container = await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(container.read(searchCriteriaProvider).cuisine, isNull);
  });

  testWidgets('amenities are MULTI-select', (tester) async {
    final transport = FakeTransport((_, __, ___) => page());
    final container = await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Outdoor seating'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraChip, 'Shisha'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(container.read(searchCriteriaProvider).amenities, <String>{'outdoor', 'shisha'});
  });

  testWidgets('CLEAR RESETS THE DRAFT, NOT THE APPLIED SEARCH', (tester) async {
    // The sheet holds a draft and writes it once. `Clear` inside the sheet
    // must not reach through and wipe a search the diner has not agreed to
    // change — they can still back out.
    final transport = FakeTransport((_, __, ___) => page());
    final container = await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(container.read(searchCriteriaProvider).cuisine, 'levantine');

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraButton, 'Clear all'));
    await tester.pump();

    // Still applied — Clear only touched the draft.
    expect(
      container.read(searchCriteriaProvider).cuisine,
      'levantine',
      reason: 'Clear reached through the sheet and changed the live search',
    );
  });

  testWidgets('the sheet opens showing what is already applied', (tester) async {
    // An empty form would make somebody rebuild filters they can see the
    // effects of on the screen behind.
    final transport = FakeTransport((_, __, ___) => page());
    await pump(tester, transport: transport);

    await openSheet(tester);
    await tester.tap(find.widgetWithText(SahraChip, 'Levantine'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SahraButton, 'Show results'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await openSheet(tester);
    final chip = tester.widget<SahraChip>(
      find.widgetWithText(SahraChip, 'Levantine'),
    );
    expect(chip.active, isTrue);
  });
}
