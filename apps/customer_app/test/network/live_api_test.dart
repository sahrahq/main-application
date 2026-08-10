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
import 'package:sahra_customer_app/features/reservations/domain/booking.dart';
import 'package:sahra_customer_app/features/reservations/domain/my_reservation.dart';
import 'package:sahra_customer_app/features/restaurants/data/restaurant_repository_impl.dart';
import 'package:sahra_customer_app/features/restaurants/domain/search_sort.dart';

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

  /// A real token for a real account, obtained the way a real client would.
  ///
  /// C-1.6 — booking requires an account — turned every hold below into a 401
  /// the moment it shipped, which is the enforcement working. The test could
  /// have been narrowed to "an anonymous hold is refused", and that would have
  /// been true and useless: the thing worth proving over a real socket is that
  /// a signed-in diner can still book.
  ///
  /// So this registers a fresh account WITH A PASSWORD and logs in. Both are
  /// real endpoints doing real work — `register` writes the user, `login`
  /// verifies an argon2id hash and mints a real JWT. Nothing is stubbed and no
  /// token is hand-forged.
  ///
  /// It does NOT use the OTP flow, and that is a limitation worth naming: the
  /// code goes to the API's log (OPS-1, `LoggingOtpDelivery`) and a Flutter
  /// test cannot read it. The OTP path is covered in-process by the API's own
  /// e2e suite, which can reach the store. When real delivery lands, this
  /// stays as it is — a password account is a legitimate account, not a
  /// shortcut around the auth the endpoint enforces.
  late String accessToken;

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

  // ONE ACCOUNT FOR THE WHOLE FILE, not one per test.
  //
  // `setUp` registered a fresh diner before every test, and every registration
  // sends an OTP. The per-IP budget is 10 sends per 10 minutes (doc 06 §1) and
  // every caller on loopback shares it — so at four tests this was quietly
  // spending 40% of the budget, and adding two more put the suite over it. The
  // failure is deceptive: `register` reports the send failure, so it surfaces
  // as a 429 on an endpoint that has nothing to do with rate limiting.
  //
  // Sharing one account is also more honest about what these tests are: a
  // signed-in diner doing several things, which is what a diner is.
  setUpAll(() async {
    // Anonymous first, to register and log in.
    final anon = SahraApi(DioTransport(baseUrl: base, localeCode: () => 'en'));

    // A phone nobody else in this database has. Reusing a fixed number would
    // make the second run of this suite fail against the first run's account —
    // and then somebody would "fix" it by deleting the assertion.
    final phone = '01${DateTime.now().microsecondsSinceEpoch % 1000000000}';
    const password = 'live-suite-password-1';

    await guarded(
      () => anon.register(
        body: RegisterDto(
          phone: phone,
          fullName: 'Live Suite',
          password: password,
          locale: 'en',
        ),
      ),
    );
    final pair = await guarded(
      () => anon.login(body: LoginDto(identifier: phone, password: password)),
    );
    accessToken = pair.accessToken;

    final transport = DioTransport(
      baseUrl: base,
      localeCode: () => 'en',
      accessToken: () => accessToken,
    );
    api = SahraApi(transport);
    restaurants = RestaurantRepositoryImpl(api, () => 'en');
    reservations = ReservationRepositoryImpl(api);
  });

  /// EVERY RESERVATION THIS RUN CREATES, so the teardown can give it back.
  ///
  /// ── THE SUITE WAS POISONING ITSELF, AND IT TOOK THREE RUNS TO SHOW ──────
  ///
  /// These tests book against the SEEDED venue on a SHARED dev database, and
  /// until now nothing cancelled what they booked. Layali has six tables; each
  /// run confirmed two or three bookings for tomorrow and left them there. On
  /// the third run the venue was full and two tests failed with "no
  /// availability" — a failure that says nothing about the code and everything
  /// about the last run.
  ///
  /// Worse than flaky: it is MONOTONIC. It passes today, passes tomorrow, and
  /// then fails permanently, so the natural reading is "something broke" rather
  /// than "the fixture filled up".
  ///
  /// Found while running the full suite twice in one session for Group G. It
  /// is not a Group G defect — the leak has been there since the live suite was
  /// written — but "8 live tests green" was a weaker claim than it looked,
  /// because it depended on how recently they had last been run.
  final List<String> booked = <String>[];

  tearDownAll(() async {
    // Through the REAL cancel endpoint, with this run's own token — the same
    // call the app makes. Not a database write: a suite that reaches around
    // its own API to tidy up is a suite that can pass while that API is broken.
    for (final id in booked) {
      try {
        await reservations.cancel(id: id, reason: 'live suite teardown');
      } catch (_) {
        // Already cancelled by the test itself, or expired. Either way the
        // table is back, which is the only thing this loop is for.
      }
    }
  });

  String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The first date in the next week with a bookable slot, and its board.
  ///
  /// ── WHY NOT JUST "TOMORROW" ─────────────────────────────────────────────
  ///
  /// It was tomorrow, and tomorrow is a fixture that other people can fill.
  /// This suite runs against a SHARED dev database, so a full venue is an
  /// ordinary state — another developer's e2e run, a demo, or (until the
  /// teardown above existed) this suite's own history.
  ///
  /// Walking forward keeps the assertion honest rather than loosening it: the
  /// claim is "this venue can be booked through the real engine", and a week of
  /// no availability anywhere still fails, loudly, with the dates it tried.
  Future<(String, SlotBoard)> firstBookable(String restaurantId) async {
    final List<String> tried = <String>[];
    for (int i = 1; i <= 7; i++) {
      final date = isoDate(DateTime.now().add(Duration(days: i)));
      tried.add(date);
      final board = await reservations.slots(
        restaurantId: restaurantId,
        date: date,
        partySize: 2,
      );
      if (board.slots.isNotEmpty) return (date, board);
    }
    fail('no availability at $restaurantId on any of ${tried.join(", ")} — '
        'the venue is full for a week, or `pnpm seed` has not been run');
  }

  test('DISTANCE over a real socket — Meilisearch geo, and a real haversine', () async {
    // NOTHING FAKE COVERS THIS CHAIN. `_geoRadius` and `_geoPoint:asc` are
    // Meilisearch features, `distance_km` is a haversine in the API, and the
    // seeded venues' coordinates are in PostGIS. A FakeTransport proves the
    // client sends the right query and nothing about whether any of that works.
    //
    // Zamalek, where the seed puts Layali and Sequoia.
    const double lat = 30.0622;
    const double lng = 31.2185;

    final page = await restaurants.search(
      lat: lat,
      lng: lng,
      radiusKm: kNearMeRadiusKm,
      sort: SearchSort.distance,
    );

    expect(page.results, isNotEmpty, reason: 'run `pnpm seed` first');

    // 1. EVERY RESULT CARRIES A DISTANCE. The API computes it only when the
    //    query had a position, so this is also the proof the position arrived.
    for (final venue in page.results) {
      expect(
        venue.distanceKm,
        isNotNull,
        reason: '${venue.name} came back with no distance_km despite a '
            'positioned query',
      );
      // 2. AND IT IS INSIDE THE RADIUS WE ASKED FOR. A `_geoRadius` filter that
      //    silently did nothing would return the whole city, every venue with a
      //    plausible distance, and look perfectly healthy.
      expect(venue.distanceKm!, lessThanOrEqualTo(kNearMeRadiusKm));
    }

    // 3. NEAREST FIRST ACTUALLY MEANS NEAREST FIRST.
    final List<double> distances = page.results.map((v) => v.distanceKm!).toList();
    final List<double> ascending = <double>[...distances]..sort();
    expect(
      distances,
      ascending,
      reason: 'sort=distance returned $distances — not ascending, so either '
          'Meilisearch ignored the sort or the geo point is wrong',
    );

    // 4. AND THE RADIUS EXCLUDES SOMETHING. Maadi is ~10km from Zamalek, so a
    //    filter that works must drop Kazoku — without this the three
    //    assertions above all pass on an unfiltered list.
    final unfiltered = await restaurants.search();
    expect(
      unfiltered.results.length,
      greaterThan(page.results.length),
      reason: 'the 5km radius excluded nothing. Every seeded venue is inside '
          'it, or `_geoRadius` is not being applied.',
    );
  });

  test('GROUP D over a real socket — the menu, and the price as a STRING', () async {
    // THE ONE THING NO FAKE CAN PROVE.
    //
    // `menu_items.price` is `NUMERIC(12,2)`. Between the column and this
    // assertion sit Prisma's Decimal, a `::text` cast, `JSON.stringify`, a
    // socket, and the generated Dart model — and any one of them turning it
    // into a number loses the scale. A fixture cannot check that, because a
    // fixture IS the string.
    final menus = await restaurants.menus('layali-lounge-zamalek');
    expect(menus, isNotEmpty, reason: 'run `pnpm seed` first');

    final item = menus.first.categories.first.items.first;
    expect(
      item.price,
      matches(RegExp(r'^\d+\.\d{2}$')),
      reason: 'The price arrived as "${item.price}". Two decimal places, or '
          'the scale was lost somewhere between NUMERIC(12,2) and here.',
    );
    expect(item.currency, 'EGP');

    // And the reviews, whose summary is computed by the TRIGGER rather than
    // by the client.
    final reviews = await restaurants.reviews('layali-lounge-zamalek');
    expect(reviews.results, isNotEmpty);
    expect(
      reviews.summary.ratingCount,
      reviews.summary.breakdown.values.reduce((a, b) => a + b),
      reason: 'the histogram and the count disagree',
    );

    // The verified-diner rule, visible from the outside: every author is a
    // first name and an initial, never the full name on the account.
    for (final r in reviews.results) {
      expect(r.author.split(' ').length, lessThanOrEqualTo(2));
    }

    // A suspended or unknown venue 404s here exactly as its profile does.
    await expectLater(
      restaurants.menus('no-such-venue-at-all'),
      throwsA(isA<Failure>()),
    );
  });

  test(
    'search → detail → slots → hold → confirm, against the real engine',
    () async {
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
      final (date, board) = await firstBookable(profile.id);

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
      booked.add(held.id);
      expect(held.status, 'held');
      expect(held.holdExpiresAt, isNotNull);
      expect(held.code, startsWith('SAH-'));

      final confirmed = await reservations.confirm(holdId: held.id);
      expect(confirmed.status, 'confirmed');
      expect(confirmed.code, held.code);

      // 6. AND IT COMES BACK. The screens the diner opens next read this list,
      // and until now nothing had ever proved the booking that was just made
      // appears in it — the write path and the read path were tested apart.
      final mine = await reservations.myReservations(view: 'upcoming');
      expect(
        mine.map((r) => r.code),
        contains(confirmed.code),
        reason: 'the reservation just confirmed is not in GET /reservations',
      );

      final one = await reservations.reservation(
        mine.firstWhere((r) => r.code == confirmed.code).id,
      );
      expect(one.status, 'confirmed');
      expect(one.needsAcknowledgement, isFalse);
      // The venue's wall clock, computed server-side — not derived here from the
      // UTC instant, which is the whole reason these two fields exist.
      expect(one.time, matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(one.venue.timezone, 'Africa/Cairo');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'GROUP A over a real socket — move it, then call it off',
    () async {
      // The three new endpoints had no live coverage at all: everything about
      // them was proved either in-process by the API's e2e suite or against a
      // fake transport in Flutter. Neither of those exercises the GENERATED
      // CLIENT against the real server — the layer where a wrong path, a
      // snake_case field or a missing body silently becomes a 404.
      final page = await restaurants.search(query: 'layali');
      expect(page.results, isNotEmpty, reason: 'run `pnpm seed` first');
      final profile = await restaurants.profile(page.results.first.slug);

      final (date, board) = await firstBookable(profile.id);

      final held = await reservations.hold(
        restaurantId: profile.id,
        startsAt: board.slots.first.startsAt,
        partySize: 2,
      );
      booked.add(held.id);
      final booking = await reservations.confirm(holdId: held.id);
      final mine = await reservations.myReservations(view: 'upcoming');
      final id = mine.firstWhere((r) => r.code == booking.code).id;

      // 1. THE PICKER ANSWERS, AND OFFERS THE BOOKING'S OWN SLOT.
      //
      // WHAT THIS CAN AND CANNOT PROVE HERE. The seeded venue has several
      // tables, so one booking does not exhaust a slot — the public grid keeps
      // offering the same time, and from out here the EXCLUSION is invisible.
      // Asserting it against this venue would be asserting nothing.
      //
      // The exclusion and the release are proved in `diner-actions.e2e-spec.ts`
      // against a venue built with exactly ONE table, where free and taken
      // are unambiguous. What is worth proving over a real socket is what that
      // suite cannot reach: that the GENERATED CLIENT calls the right path and
      // decodes the answer.
      final movable = await reservations.movableSlots(id: id, date: date);
      expect(movable.slots, isNotEmpty);
      expect(movable.partySize, 2, reason: "the picker ignored the booking's own party size");
      expect(
        movable.slots.map((s) => s.startsAt),
        contains(board.slots.first.startsAt),
        reason: 'the move picker does not offer the time this booking holds',
      );

      // 2. CHANGE THE PARTY SIZE. Absolute value, through the real engine, with
      //    the advisory lock and the re-check that a new booking gets.
      final moved = await reservations.modify(id: id, partySize: 3);
      expect(moved.partySize, 3);
      expect(moved.code, booking.code, reason: 'a modify created a new booking');
      expect(moved.status, 'confirmed');

      // 3. REPLAY IT. The argument for carrying no Idempotency-Key is that the
      //    body names absolute values — asserted here against the real database
      //    rather than reasoned about in a comment.
      final again = await reservations.modify(id: id, partySize: 3);
      expect(again.partySize, 3);
      expect(again.code, booking.code);

      // 4. CANCEL, as the DINER.
      final cancelled = await reservations.cancel(id: id, reason: 'Live suite');
      expect(cancelled.status, 'cancelled_by_user');
      expect(cancelled.cancelledBy, CancelledBy.user);
      expect(cancelled.cancelReason, 'Live suite');
      // The diner did this themselves, so there is nothing to acknowledge.
      expect(cancelled.needsAcknowledgement, isFalse);

      // 5. AND IT IS GONE FROM UPCOMING, WHICH IS THE SCREEN THE DINER RETURNS
      //    TO. The table release is a one-table property and lives in the e2e
      //    suite; this is the part a diner can actually see.
      final upcoming = await reservations.myReservations(view: 'upcoming');
      expect(
        upcoming.map((r) => r.code),
        isNot(contains(booking.code)),
        reason: 'a cancelled booking is still listed as upcoming',
      );

      final past = await reservations.myReservations(view: 'past');
      expect(
        past.map((r) => r.code),
        contains(booking.code),
        reason: 'a cancelled booking vanished instead of moving to history',
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'PATCH /auth/me over a real socket, and it REFUSES an email',
    () async {
      // The refusal matters more than the success. `users.email` is reachable
      // the moment this endpoint accepts one, and the verification flow that
      // decides what an unverified address may be used for is not built.
      final renamed = await guarded(
        () => api.updateMe(body: const UpdateProfileDto(fullName: 'Live Suite Diner')),
      );
      expect(renamed.fullName, 'Live Suite Diner');
      expect(renamed.email, isNull);

      // `UpdateProfileDto` has no email field, so this goes out as a raw body —
      // the only way to prove the SERVER refuses it rather than the client
      // merely declining to offer it.
      await expectLater(
        guarded(
          () => DioTransport(
            baseUrl: base,
            localeCode: () => 'en',
            accessToken: () => accessToken,
          ).send(
            method: 'PATCH',
            path: '/v1/auth/me',
            body: <String, Object?>{'fullName': 'X Y', 'email': 'nobody@example.com'},
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having((f) => f.code, 'code', 'validation_failed'),
        ),
      );

      // And nothing was written.
      final me = await guarded(() => api.me());
      expect(me.email, isNull);
      expect(me.fullName, 'Live Suite Diner');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'C-1.6: an anonymous hold is refused, and typed as an AuthFailure',
    () async {
      // The enforcement itself, over a real socket. The screens depend on this
      // arriving as an `AuthFailure` specifically — that is what routes a guest
      // to sign-in instead of showing them an error they cannot act on.
      final anon = SahraApi(DioTransport(baseUrl: base, localeCode: () => 'en'));
      final page = await restaurants.search(query: 'layali');
      final venue = page.results.first;
      // A REAL, BOOKABLE slot — the refusal has to be about the missing account
      // and nothing else. Asking for one on a full day would refuse for the wrong
      // reason and the assertion would still pass.
      final (_, board) = await firstBookable(venue.id);

      await expectLater(
        guarded(
          () => anon.createHold(
            body: CreateHoldDto(
              restaurantId: venue.id,
              startsAt: board.slots.first.startsAt,
              partySize: 2,
            ),
            idempotencyKey: newIdempotencyKey(),
          ),
        ),
        throwsA(isA<AuthFailure>()),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'a replayed idempotency key returns the SAME reservation',
    () async {
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
      // One id, because the replay must not have made a second — registered so
      // the teardown returns the table either way.
      booked.add(first.id);

      expect(replay.id, first.id, reason: 'a replay created a SECOND reservation');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'the doc 06 §1 envelope arrives as a typed Failure, not a DioException',
    () async {
      // The end of the error chain, over a real socket: envelope → ApiException
      // → Failure. No screen ever sees anything else.
      await expectLater(
        restaurants.profile('no-such-venue-anywhere-at-all'),
        throwsA(
          isA<Failure>().having((f) => f.code, 'code', 'restaurant_not_found'),
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
