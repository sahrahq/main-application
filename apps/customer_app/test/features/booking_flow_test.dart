import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sahra_customer_app/core/error/failure.dart';
import 'package:sahra_customer_app/features/reservations/presentation/booking_notifier.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';

/// The booking state machine — doc 07 §4 puts it at ~100% for a reason: it is
/// the highest-risk logic in the product and the only place a diner can be
/// told they have a table they do not have.
///
/// Every test drives the REAL notifier, REAL repository and REAL generated
/// client. Only the socket is fake, so a change to the wire shape breaks these
/// the same way it would break a screen.
void main() {
  const venueId = '11111111-1111-4111-8111-111111111111';
  const startsAt = '2026-08-05T18:00:00.000Z';

  ProviderContainer containerWith(FakeTransport transport) {
    final c = ProviderContainer(
      overrides: <Override>[transportProvider.overrideWithValue(transport)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Map<String, Object?> reservation(String status) => <String, Object?>{
        'id': '22222222-2222-4222-8222-222222222222',
        'code': 'SAH-7K2M',
        'restaurantId': venueId,
        'partySize': 2,
        'startsAt': startsAt,
        'endsAt': '2026-08-05T19:30:00.000Z',
        'status': status,
        'source': 'app',
      };

  group('the happy path', () {
    test('holds, then confirms, and lands on the confirmed reservation', () async {
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/reservations/holds') return reservation('held');
        if (path.endsWith('/confirm')) return reservation('confirmed');
        throw StateError('unexpected $method $path');
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      final state = c.read(bookingFlowProvider(venueId));
      expect(state, isA<BookingDone>());
      expect((state as BookingDone).booking.status, 'confirmed');
      expect((state).booking.code, 'SAH-7K2M');

      // TWO calls, in order. Collapsing them into one would remove the window
      // a deposit sheet lives in (C-4.1) and the moment a diner can still walk
      // away.
      expect(transport.calls, <String>[
        'POST /v1/reservations/holds',
        'POST /v1/reservations/holds/22222222-2222-4222-8222-222222222222/confirm',
      ]);
    });

    test('the hold and the confirm use DIFFERENT idempotency keys', () async {
      final keys = <String>[];
      final transport = _KeyRecordingTransport(keys, (method, path, _) {
        if (path.endsWith('/confirm')) return reservation('confirmed');
        return reservation('held');
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      expect(keys, hasLength(2));
      // Reusing the hold's key on the confirm would make the confirm look like
      // a replay of the hold, and the server would answer with the hold.
      expect(keys.first, isNot(keys.last));
    });
  });

  group('the slot is taken between seeing it and confirming it', () {
    // THE SEMANTIC THE TYPE SYSTEM CANNOT CARRY.
    //
    // `createHold` returns `ReservationResponse` and its signature says nothing
    // about the 409. sahra_api_client/README.md §1 states it in prose; this is
    // the test that makes the client's prose an executable claim.
    test('becomes a state with alternatives, never a thrown exception', () async {
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/reservations/holds') {
          throw envelope(409, 'slot_taken', alternatives: <String>[
            '2026-08-05T18:30:00.000Z',
            '2026-08-05T19:00:00.000Z',
          ],);
        }
        throw StateError('confirm must never be reached after a failed hold');
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      final state = c.read(bookingFlowProvider(venueId));
      expect(state, isA<BookingSlotTaken>());

      final failure = (state as BookingSlotTaken).failure;
      expect(failure.code, 'slot_taken');
      // doc 06 §6 — "409s on booking always include alternatives … turn
      // failure into conversion". A conflict with nowhere to go is the dead
      // end DESIGN-RULES.md forbids.
      expect(failure.alternatives, hasLength(2));
      expect(failure.requestId, 'req_test');
    });

    test('never confirms a hold that was never created', () async {
      // The failure mode this rules out is the worst one available: telling a
      // diner they have a table when the engine refused to give them one.
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/reservations/holds') throw envelope(409, 'slot_taken');
        // NOT `fail()`. A TestFailure raised in here is caught by `guarded`
        // and mapped to an UnknownFailure like any other exception, so the
        // test would pass while the thing it forbids happened. Assert on what
        // was RECORDED instead — the fake cannot swallow that.
        return <String, Object?>{};
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      expect(
        transport.calls.where((call) => call.endsWith('/confirm')),
        isEmpty,
        reason: 'confirmed a hold the engine refused to create — the worst '
            'failure available: a diner told they have a table they do not',
      );
      expect(c.read(bookingFlowProvider(venueId)), isNot(isA<BookingDone>()));
    });

    test('refreshes the slot board, so the alternatives offered are real', () async {
      var slotCalls = 0;
      final transport = FakeTransport((method, path, _) {
        if (path.contains('/availability')) {
          slotCalls++;
          return <String, Object?>{
            'date': '2026-08-05',
            'partySize': 2,
            'timezone': 'Africa/Cairo',
            'slots': <Object>[
              <String, Object?>{
                'time': '18:30',
                'startsAt': '2026-08-05T16:30:00.000Z',
                'zones': <String>['indoor'],
              },
            ],
          };
        }
        throw envelope(409, 'slot_taken');
      });
      final c = containerWith(transport);

      // Materialise the board first, the way the screen does.
      await c.read(availableSlotsProvider(venueId).future);
      expect(slotCalls, 1);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);
      await c.read(availableSlotsProvider(venueId).future);

      // The board on screen is known-wrong the moment the hold 409s. Offering
      // the same stale list back is how a diner fails twice in a row.
      expect(slotCalls, 2, reason: 'availability was not re-run after slot_taken');
    });
  });

  group('the hold expires while the diner is deciding', () {
    test('is a DIFFERENT state from slot_taken — the copy has to differ', () async {
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/reservations/holds') return reservation('held');
        throw envelope(409, 'hold_expired');
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      // "Somebody else was faster" and "you were" are both 409s and both send
      // the diner back to the picker, but telling them the wrong one is the
      // difference between an apology and an accusation.
      expect(c.read(bookingFlowProvider(venueId)), isA<BookingHoldExpired>());
    });
  });

  group('the phone goes offline mid-booking', () {
    test('after the request leaves, it is a failure — never a silent success', () async {
      final transport = FakeTransport((method, path, _) => throw offline);
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      final state = c.read(bookingFlowProvider(venueId));
      expect(state, isA<BookingFailed>());
      expect((state as BookingFailed).failure, isA<OfflineFailure>());
    });

    test('offline BETWEEN the hold and the confirm leaves a hold, not a booking', () async {
      // The honest outcome, and the reason the customer app does NOT queue
      // mutations (doc 07 §3): the table is held for five minutes and then
      // released by the sweeper. A queued confirm that fired later would be a
      // promise the engine never made.
      var holds = 0;
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/reservations/holds') {
          holds++;
          return reservation('held');
        }
        throw offline;
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      expect(holds, 1);
      expect(c.read(bookingFlowProvider(venueId)), isA<BookingFailed>());
      // And emphatically not "done".
      expect(c.read(bookingFlowProvider(venueId)), isNot(isA<BookingDone>()));
    });
  });

  group('the slot the screen sends', () {
    test('is the absolute startsAt, never the wall-clock label', () async {
      String? sent;
      final transport = _BodyRecordingTransport((body) => sent = body, (method, path, _) {
        if (path.endsWith('/confirm')) return reservation('confirmed');
        return reservation('held');
      });
      final c = containerWith(transport);

      await c.read(bookingFlowProvider(venueId).notifier).book(startsAt: startsAt, partySize: 2);

      // `21:00` would book the wrong hour, and in Cairo that is a 2–3 hour
      // error depending on the date (sahra_api_client/README.md §2).
      expect(sent, startsAt);
      expect(sent, contains('T'));
      expect(sent, endsWith('Z'));
    });
  });

  group('choosing a slot', () {
    test('is cleared when the date changes — a 21:00 Thursday is not a 21:00 Friday', () {
      final c = containerWith(FakeTransport((_, __, ___) => throw offline));

      c.read(chosenSlotProvider(venueId).notifier).choose(startsAt);
      expect(c.read(chosenSlotProvider(venueId)), startsAt);

      c.read(bookingSelectionProvider(venueId).notifier).setDate('2026-08-09');
      expect(
        c.read(chosenSlotProvider(venueId)),
        isNull,
        reason: 'a slot left selected across a date change books the wrong night',
      );
    });

    test('is cleared when the party size changes', () {
      final c = containerWith(FakeTransport((_, __, ___) => throw offline));

      c.read(chosenSlotProvider(venueId).notifier).choose(startsAt);
      c.read(bookingSelectionProvider(venueId).notifier).setPartySize(6);

      expect(c.read(chosenSlotProvider(venueId)), isNull);
    });
  });
}

class _KeyRecordingTransport extends FakeTransport {
  _KeyRecordingTransport(this.keys, super.handler);
  final List<String> keys;

  @override
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    final key = headers?['idempotency-key'];
    if (key != null) keys.add(key);
    return super.send(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
  }
}

class _BodyRecordingTransport extends FakeTransport {
  _BodyRecordingTransport(this.onStartsAt, super.handler);
  final void Function(String?) onStartsAt;

  @override
  Future<dynamic> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (body is Map && body['startsAt'] != null) onStartsAt(body['startsAt'] as String);
    return super.send(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
  }
}
