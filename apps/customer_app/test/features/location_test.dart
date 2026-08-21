import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_notifier.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_screen.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/shared/location/location_notifier.dart';
import 'package:sahra_customer_app/shared/location/location_source.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';
import '../support/screen_harness.dart';

/// THE LOCATION HALF-BATCH — and the promise that matters is a NEGATIVE one.
///
/// ─────────────────────────────────────────────────────────────────────────
/// "NO PERMISSION PROMPT BEFORE THERE IS A REASON FOR ONE"
/// ─────────────────────────────────────────────────────────────────────────
///
/// That was the condition the capability was approved under, and it is the one
/// thing here a diner would notice being broken — by which point they have
/// already denied the permission, possibly for good.
///
/// It is also the hardest kind of property to test, because it is about
/// something NOT happening. A test that opens the sheet and asserts a chip is
/// on screen passes whether or not the dialog fired behind it.
///
/// So the fake location source COUNTS ITS CALLS. `current()` is the only path
/// that can raise the dialog; if it was never called, the dialog cannot have
/// appeared. That turns "no prompt" from an intention into an integer.
void main() {
  Map<String, Object?> venue(String id, String slug, String name, {double? distanceKm}) =>
      <String, Object?>{
        'id': id,
        'slug': slug,
        'name_en': name,
        'name_ar': name,
        'cuisines': <String>['levantine'],
        'neighborhood': 'Zamalek',
        'price_band': 3,
        'rating': 4.5,
        'rating_count': 12,
        'next_available': <String>[],
        'cover': null,
        if (distanceKm != null) 'distance_km': distanceKm,
      };

  Map<String, Object?> page(List<Object> results) => <String, Object?>{
        'results': results,
        'next_cursor': null,
        'estimated_total': results.length,
        'availability_filtered': false,
      };

  late List<Map<String, String>> queries;

  FakeTransport recordingTransport(List<Object> results) => FakeTransport(
        (method, path, query) {
          if (path.contains('/restaurants/search')) {
            queries.add(query ?? const <String, String>{});
            return page(results);
          }
          return page(const <Object>[]);
        },
      );

  setUp(() => queries = <Map<String, String>>[]);

  Future<void> pump(
    WidgetTester tester, {
    required LocationSource location,
    required FakeTransport transport,
  }) async {
    // A REAL PHONE, not the 800x600 default. The filter sheet is taller than
    // the default surface, so half its controls sat outside the render tree
    // and `tap` reported an offset that "would not hit test" — which reads as
    // a broken control and is actually a broken viewport.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenHarness(
        Cell.enLight,
        const SearchScreen(),
        overrides: <Override>[
          transportProvider.overrideWithValue(transport),
          locationSourceProvider.overrideWithValue(location),
          // Text already typed, so the screen is searching rather than showing
          // its start state — a blank query never reaches the transport and
          // every assertion about query parameters would be vacuous.
          searchCriteriaProvider.overrideWith(_Typed.new),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFilters(WidgetTester tester) async {
    final BuildContext context = tester.element(find.byType(SearchScreen));
    await tester.tap(find.text(AppLocalizations.of(context).filterOpen).first);
    await tester.pumpAndSettle();
  }

  /// Scroll the sheet to a control before tapping it.
  ///
  /// The sheet is a `SingleChildScrollView` and taller than any phone in the
  /// matrix once distance and sort are on it — which is the diner's experience
  /// too, so the test scrolls the way they would rather than pretending the
  /// controls are all visible at once.
  Future<void> tapInSheet(WidgetTester tester, String label) async {
    final Finder target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('the prompt does not appear until the diner asks for it', () {
    testWidgets('not on the search screen, and not when the sheet opens', (tester) async {
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(
        tester,
        location: location,
        transport: recordingTransport(<Object>[
          venue('v1', 'layali', 'Layali Lounge'),
        ]),
      );

      // A search has run. If the counter is still zero AFTER a real query, the
      // capability is genuinely dormant rather than merely slow.
      expect(queries, isNotEmpty, reason: 'no search ran — this test proves nothing');
      expect(location.asked, 0, reason: 'the app asked for a position on launch');

      await openFilters(tester);
      expect(
        location.asked,
        0,
        reason: 'opening the filter sheet raised the permission dialog. The '
            'prompt belongs to the "near me" TAP and to nothing else.',
      );
    });

    testWidgets('and the search carries no lat/lng until it does', (tester) async {
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));

      for (final Map<String, String> q in queries) {
        expect(q.containsKey('lat'), isFalse);
        expect(q.containsKey('lng'), isFalse);
        expect(q.containsKey('radius_km'), isFalse);
        expect(q.containsKey('sort'), isFalse);
      }
    });
  });

  group('tapping "near me"', () {
    testWidgets('asks once, and the next search carries the position', (tester) async {
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tapInSheet(tester, l10n.filterNearMe);
      expect(location.asked, 1);

      // The chip now says what "near me" MEANS. A filter whose reach is
      // invisible is one a diner cannot tell is working.
      expect(find.text(l10n.filterNearMeRadius('5')), findsOneWidget);

      queries.clear();
      await tapInSheet(tester, l10n.filterApply);

      expect(queries, isNotEmpty);
      expect(queries.last['lat'], '30.0622');
      expect(queries.last['lng'], '31.2185');
      expect(queries.last['radius_km'], '5.0');
    });

    testWidgets('a refusal leaves the toggle OFF and says why', (tester) async {
      // The failure this is written against: a filter that switches on, ranks
      // against nothing, and has to be discovered to be useless.
      final _CountingSource location = _CountingSource(
        const FixedLocationSource.refused(LocationOutcome.denied),
      );
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tapInSheet(tester, l10n.filterNearMe);

      expect(location.asked, 1);
      // Still off — the label never became the radius one.
      expect(find.text(l10n.filterNearMe), findsOneWidget);
      expect(find.text(l10n.filterNearMeRadius('5')), findsNothing);
      expect(find.text(l10n.locationDenied), findsOneWidget);
    });

    testWidgets('a permanent refusal says something different, because it is', (tester) async {
      // "Try again" is an instruction that cannot work once the OS has stopped
      // showing the dialog. Four outcomes, four sentences.
      final _CountingSource location = _CountingSource(
        const FixedLocationSource.refused(LocationOutcome.deniedForever),
      );
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tapInSheet(tester, l10n.filterNearMe);

      expect(find.text(l10n.locationDeniedForever), findsOneWidget);
      expect(find.text(l10n.locationDenied), findsNothing);
    });
  });

  group('nearest-first', () {
    testWidgets('is not offered until there is a position', (tester) async {
      // ABSENT, not disabled. A disabled control invites the question "why";
      // an absent one is answered by the distance filter directly above it.
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      expect(find.text(l10n.sortRelevance), findsOneWidget);
      expect(find.text(l10n.sortRating), findsOneWidget);
      expect(find.text(l10n.sortDistance), findsNothing);

      await tapInSheet(tester, l10n.filterNearMe);

      expect(find.text(l10n.sortDistance), findsOneWidget);
    });

    testWidgets('reaches the wire as sort=distance', (tester) async {
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tapInSheet(tester, l10n.filterNearMe);
      await tapInSheet(tester, l10n.sortDistance);

      queries.clear();
      await tapInSheet(tester, l10n.filterApply);

      expect(queries.last['sort'], 'distance');
    });

    testWidgets('and relevance is NOT sent — it is the server default', (tester) async {
      final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
      await pump(tester, location: location, transport: recordingTransport(<Object>[]));
      await openFilters(tester);

      final BuildContext context = tester.element(find.byType(SearchScreen));
      queries.clear();
      await tapInSheet(tester, AppLocalizations.of(context).filterApply);

      expect(queries.last.containsKey('sort'), isFalse);
    });
  });

  testWidgets('a distance the server computed is shown on the row', (tester) async {
    final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
    await pump(
      tester,
      location: location,
      transport: recordingTransport(<Object>[
        venue('v1', 'layali', 'Layali Lounge', distanceKm: 1.42),
      ]),
    );

    final BuildContext context = tester.element(find.byType(SearchScreen));
    // One decimal: a venue 1.4km away and one 1.43km away are the same walk.
    expect(
      find.textContaining(AppLocalizations.of(context).resultDistance('1.4')),
      findsOneWidget,
    );
  });

  testWidgets('and a row shows no distance when the server sent none', (tester) async {
    // The ordinary case. A row that invented a distance from a position we do
    // not have would be the screen confidently saying something false.
    final _CountingSource location = _CountingSource(const FixedLocationSource.zamalek());
    await pump(
      tester,
      location: location,
      transport: recordingTransport(<Object>[venue('v1', 'layali', 'Layali Lounge')]),
    );

    expect(find.textContaining(' km'), findsNothing);
  });
}

/// Records how many times a position was asked for.
class _CountingSource implements LocationSource {
  _CountingSource(this._inner);

  final LocationSource _inner;
  int asked = 0;

  @override
  Future<bool> canAsk() => _inner.canAsk();

  @override
  Future<LocationResult> current() {
    asked++;
    return _inner.current();
  }
}

/// A criteria notifier that starts with text typed, so the screen searches.
class _Typed extends SearchCriteria {
  @override
  SearchQuery build() => const SearchQuery(text: 'layali');
}
