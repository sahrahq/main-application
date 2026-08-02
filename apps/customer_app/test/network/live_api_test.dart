@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_api_client/sahra_api_client.dart';
import 'package:sahra_customer_app/core/error/failure.dart';
import 'package:sahra_customer_app/core/error/guarded.dart';
import 'package:sahra_customer_app/core/network/dio_transport.dart';
import 'package:sahra_customer_app/core/utils/idempotency_key.dart';
import 'package:sahra_customer_app/features/reservations/data/reservation_repository_impl.dart';
import 'package:sahra_customer_app/features/restaurants/data/restaurant_repository_impl.dart';

/// The whole chain against a RUNNING backend — real Dio, real socket, real
/// Postgres, real reservation engine.
///
///     docker compose up -d
///     cd apps/api && pnpm seed && pnpm start:dev
///     cd apps/customer_app && flutter test --tags live
///
/// Tagged, so a plain `flutter test` skips it: a test that needs a server is a
/// test that turns CI red for the wrong reason. But every other test in this
/// app fakes the socket, and a suite where NOTHING has ever touched the real
/// API can be entirely green while the app cannot reach anything at all.
void main() {
  const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');

  late SahraApi api;
  late RestaurantRepositoryImpl restaurants;
  late ReservationRepositoryImpl reservations;

  setUpAll(() {
    // `TestWidgetsFlutterBinding` INSTALLS AN HttpOverrides THAT ANSWERS 400
    // TO EVERYTHING and never opens a socket. Nothing announces this except a
    // warning buried in the output, so a "live" test written here does not
    // fail — it passes, against a fabricated 400, having touched no server.
    //
    // The only reason it did not pass that way here is that these assertions
    // name a SPECIFIC code (`restaurant_not_found`) rather than "some
    // failure". A loose `throwsA(isA<Failure>())` would have been green
    // forever while proving the opposite of what it claims.
    //
    // Clearing the override restores the real client for this file only.
    HttpOverrides.global = null;
  });

  setUp(() {
    final transport = DioTransport(baseUrl: base, localeCode: () => 'en');
    api = SahraApi(transport);
    restaurants = RestaurantRepositoryImpl(api, () => 'en');
    reservations = ReservationRepositoryImpl(api);
  });

  String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  test('search → detail → slots → hold → confirm, against the real engine', () async {
    // 1. SEARCH. Meilisearch decides WHICH, Postgres decides WHAT.
    final page = await restaurants.search(query: 'layali');
    expect(page.results, isNotEmpty, reason: 'run `pnpm seed` first');
    final venue = page.results.first;
    expect(venue.name, isNotEmpty);

    // 2. DETAIL, BY SLUG — the deep-link path, not the id one.
    final profile = await restaurants.profile(venue.slug);
    expect(profile.id, venue.id);
    expect(profile.timezone, 'Africa/Cairo');
    expect(profile.hours, isNotEmpty, reason: 'a venue with no shifts cannot be booked');

    // 3. SLOTS. The only source of a bookable instant.
    final date = isoDate(DateTime.now().add(const Duration(days: 1)));
    final board = await reservations.slots(
      restaurantId: profile.id,
      date: date,
      partySize: 2,
    );
    expect(board.slots, isNotEmpty, reason: 'no availability on $date');

    // The two time fields are DIFFERENT things, and against a real Cairo venue
    // the difference is visible: UTC+3, so a 19:00 wall clock is 16:00Z.
    final slot = board.slots.first;
    expect(slot.startsAt, endsWith('Z'));
    expect(slot.label, matches(RegExp(r'^\d{2}:\d{2}$')));

    // 4. HOLD, then 5. CONFIRM — two mutations, two idempotency keys.
    final held = await reservations.hold(
      restaurantId: profile.id,
      startsAt: slot.startsAt,
      partySize: 2,
    );
    expect(held.status, 'held');
    expect(held.holdExpiresAt, isNotNull);
    expect(held.code, startsWith('SAH-'));

    final confirmed = await reservations.confirm(holdId: held.id);
    expect(confirmed.status, 'confirmed');
    expect(confirmed.code, held.code);
  }, timeout: const Timeout(Duration(seconds: 60)),);

  test('a replayed idempotency key returns the SAME reservation', () async {
    // The guarantee that makes a retry on a bad Cairo connection safe. Driven
    // at the client level because the repository generates a fresh key per
    // attempt by design — which is correct, and also means the repository
    // cannot demonstrate a replay.
    final page = await restaurants.search(query: 'layali');
    final venue = page.results.first;

    final date = isoDate(DateTime.now().add(const Duration(days: 2)));
    final board = await reservations.slots(
      restaurantId: venue.id,
      date: date,
      partySize: 2,
    );
    final slot = board.slots.last;

    final key = newIdempotencyKey();
    final body = CreateHoldDto(
      restaurantId: venue.id,
      startsAt: slot.startsAt,
      partySize: 2,
    );

    final first = await guarded(() => api.createHold(body: body, idempotencyKey: key));
    final replay = await guarded(() => api.createHold(body: body, idempotencyKey: key));

    expect(replay.id, first.id, reason: 'a replay created a SECOND reservation');
  }, timeout: const Timeout(Duration(seconds: 60)),);

  test('the doc 06 §1 envelope arrives as a typed Failure, not a DioException', () async {
    // The end of the error chain, over a real socket: envelope → ApiException
    // → Failure. No screen ever sees anything else.
    await expectLater(
      restaurants.profile('no-such-venue-anywhere-at-all'),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', 'restaurant_not_found'),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 30)),);
}
