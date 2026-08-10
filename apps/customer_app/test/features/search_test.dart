import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/core/error/failure.dart';
import 'package:sahra_customer_app/features/restaurants/domain/restaurant_repository.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_notifier.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';

void main() {
  ProviderContainer containerWith(FakeTransport transport) {
    final c = ProviderContainer(
      overrides: <Override>[transportProvider.overrideWithValue(transport)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Map<String, Object?> page(List<Map<String, Object?>> results, {bool filtered = false}) =>
      <String, Object?>{
        'results': results,
        'next_cursor': null,
        'estimated_total': results.length,
        'availability_filtered': filtered,
      };

  Map<String, Object?> venue({List<String>? next}) => <String, Object?>{
        'id': '11111111-1111-4111-8111-111111111111',
        'slug': 'layali-lounge-zamalek',
        'name_en': 'Layali Lounge',
        'name_ar': 'ليالي لاونج',
        'cuisines': <String>['levantine'],
        'neighborhood': 'Zamalek',
        'price_band': 3,
        'rating': 4.8,
        'rating_count': 312,
        if (next != null) 'next_available': next,
      };

  group('search returns nothing', () {
    test('is an EMPTY page, not an error', () async {
      // The distinction the four-state pattern exists for. A zero-result
      // search is a normal outcome that needs a helpful empty state; treating
      // it as an error would show a retry button for a query that will keep
      // returning nothing.
      final c = containerWith(FakeTransport((_, __, ___) => page(<Map<String, Object?>>[])));

      c.read(searchCriteriaProvider.notifier).setText('zzz no such venue');
      final result = await c.read(searchResultsProvider.future);

      expect(result.results, isEmpty);
      expect(result.estimatedTotal, 0);
    });

    test('a blank query never reaches the network at all', () async {
      final transport = FakeTransport((_, __, ___) => page(<Map<String, Object?>>[]));
      final c = containerWith(transport);

      final result = await c.read(searchResultsProvider.future);

      expect(result.results, isEmpty);
      // An unfiltered list of every venue in Cairo is not discovery, and it is
      // a query the backend should never be asked to run on app open.
      expect(transport.calls, isEmpty);
    });
  });

  group('search is down — the 503 the backend already returns', () {
    test('becomes a ServerFailure carrying search_unavailable', () async {
      // Meilisearch is a separate process; when it is unreachable the API
      // answers 503 `search_unavailable` rather than pretending the city has
      // no restaurants. The client must carry that through — "nothing found"
      // and "search is broken" need different words and different affordances.
      final c = containerWith(
        FakeTransport((_, __, ___) => throw envelope(503, 'search_unavailable')),
      );

      c.read(searchCriteriaProvider.notifier).setText('koshary');

      await expectLater(
        c.read(searchResultsProvider.future),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.code, 'code', 'search_unavailable')
              .having((f) => f.requestId, 'requestId', 'req_test'),
        ),
      );
    });

    test('an outage is never mistaken for an empty result', () async {
      final c = containerWith(
        FakeTransport((_, __, ___) => throw envelope(503, 'search_unavailable')),
      );
      c.read(searchCriteriaProvider.notifier).setText('koshary');

      // The AsyncValue must be in error, not in data-with-an-empty-list —
      // which is what a repository swallowing the exception would produce, and
      // which would render the "nothing matches, try a nearby area" state
      // during a total outage.
      await c.read(searchResultsProvider.future).then<void>(
            (_) => fail('an outage resolved to data'),
            onError: (_, __) {},
          );
      expect(c.read(searchResultsProvider).hasError, isTrue);
    });
  });

  group('the phone is offline', () {
    test('is OfflineFailure, distinct from a server error', () async {
      final c = containerWith(FakeTransport((_, __, ___) => throw offline));
      c.read(searchCriteriaProvider.notifier).setText('koshary');

      await expectLater(
        c.read(searchResultsProvider.future),
        throwsA(isA<OfflineFailure>()),
      );
    });
  });

  group('the availability filter', () {
    test('sends date and party size TOGETHER, or neither', () async {
      Map<String, String>? sent;
      final transport = _QueryRecordingTransport(
        (q) => sent = q,
        (_, __, ___) => page(<Map<String, Object?>>[venue(next: <String>['21:00'])], filtered: true),
      );
      final c = containerWith(transport);

      c.read(searchCriteriaProvider.notifier).setText('layali');
      await c.read(searchResultsProvider.future);
      // Text only — the API rejects half a filter with
      // `invalid_availability_filter`, because unfiltered results that LOOK
      // availability-checked are worse than none.
      expect(sent!.containsKey('available_at'), isFalse);
      expect(sent!.containsKey('party_size'), isFalse);

      c.read(searchCriteriaProvider.notifier).toggleTonight();
      await c.read(searchResultsProvider.future);
      expect(sent!.containsKey('available_at'), isTrue);
      expect(sent!['party_size'], '2');
    });

    test('next_available survives as strings, never parsed into a time', () async {
      final c = containerWith(
        FakeTransport((_, __, ___) =>
            page(<Map<String, Object?>>[venue(next: <String>['21:00', '21:30'])], filtered: true),),
      );

      c.read(searchCriteriaProvider.notifier).toggleTonight();
      final result = await c.read(searchResultsProvider.future);

      // Parsing these into a DateTime is the first step towards passing one to
      // a booking call, and it carries no date and no zone — in Cairo that is
      // a 2–3 hour error (sahra_api_client/README.md §2).
      expect(result.results.single.nextAvailable, <String>['21:00', '21:30']);
    });

    test('a venue with no teaser reports an empty list, not a null hole', () async {
      final c = containerWith(
        FakeTransport((_, __, ___) => page(<Map<String, Object?>>[venue()])),
      );

      c.read(searchCriteriaProvider.notifier).setText('layali');
      final result = await c.read(searchResultsProvider.future);

      expect(result.results.single.nextAvailable, isEmpty);
      expect(result.availabilityFiltered, isFalse);
    });
  });

  group('the locale decides which name comes back', () {
    test('ar takes name_ar, en takes name_en, from the same response', () async {
      final c = containerWith(
        FakeTransport((_, __, ___) => page(<Map<String, Object?>>[venue()])),
      );
      c.read(searchCriteriaProvider.notifier).setText('layali');

      // Default is ar — `supportedLocales.first`, and the product decision
      // that Arabic is primary rather than "supported".
      expect((await c.read(searchResultsProvider.future)).results.single.name, 'ليالي لاونج');

      c.read(localeCodeProvider.notifier).set('en');
      c.invalidate(searchResultsProvider);
      expect((await c.read(searchResultsProvider.future)).results.single.name, 'Layali Lounge');
    });
  });

  group('the page-two caveat is represented, not hidden', () {
    test('a cursor is carried through so the screen can know there is more', () async {
      final c = containerWith(
        FakeTransport((_, __, ___) => <String, Object?>{
              'results': <Object>[venue()],
              'next_cursor': 'cursor-20',
              'estimated_total': 42,
              'availability_filtered': true,
            },),
      );
      c.read(searchCriteriaProvider.notifier).setText('a');

      final result = await c.read(searchResultsProvider.future);
      expect(result.nextCursor, 'cursor-20');
      // Page two has NOT been availability-filtered (README §3). The flag on
      // THIS page says nothing about the next one, which is why paging is not
      // wired to the screen yet rather than wired wrongly.
      expect(result, isA<SearchPage>());
    });
  });
}

class _QueryRecordingTransport extends FakeTransport {
  _QueryRecordingTransport(this.onQuery, super.handler);
  final void Function(Map<String, String>) onQuery;

  @override
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    onQuery(query ?? <String, String>{});
    return super.send(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
  }
}
