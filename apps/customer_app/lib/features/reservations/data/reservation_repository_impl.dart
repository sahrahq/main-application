import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../../../core/utils/idempotency_key.dart';
import '../domain/booking.dart';
import '../domain/my_reservation.dart';
import '../domain/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl(this._api);

  final SahraApi _api;

  @override
  Future<SlotBoard> slots({
    required String restaurantId,
    required String date,
    required int partySize,
  }) async {
    final r = await guarded(
      () => _api.getSlots(
        id: restaurantId,
        date: date,
        // The generated signature is String because OpenAPI query params are
        // strings. Passing an int here would not compile — which is the point.
        partySize: partySize.toString(),
      ),
    );

    return SlotBoard(
      date: r.date,
      partySize: r.partySize,
      timezone: r.timezone,
      slots: r.slots
          .map((s) => Slot(label: s.time, startsAt: s.startsAt, zones: s.zones))
          .toList(),
    );
  }

  @override
  Future<Booking> hold({
    required String restaurantId,
    required String startsAt,
    required int partySize,
    String? seatingPref,
    String? guestName,
    String? guestPhone,
    String? specialRequests,
    String? occasion,
  }) async {
    // ONE key per attempt, generated here and not reused.
    //
    // If the network drops after the server committed the hold, a retry with
    // this same key returns the ORIGINAL reservation instead of taking a
    // second table — which is exactly the situation a diner on a Cairo 3G
    // connection is in when they tap twice.
    final key = newIdempotencyKey();

    final r = await guarded(
      () => _api.createHold(
        idempotencyKey: key,
        body: CreateHoldDto(
          restaurantId: restaurantId,
          // The ABSOLUTE instant from an availability slot. Never a wall-clock
          // string, never anything reconstructed from search's next_available.
          startsAt: startsAt,
          partySize: partySize,
          seatingPref: seatingPref,
          guestName: guestName,
          guestPhone: guestPhone,
          specialRequests: specialRequests,
          occasion: occasion,
        ),
      ),
    );

    return _booking(r);
  }

  @override
  Future<Booking> confirm({
    required String holdId,
    String? specialRequests,
    String? occasion,
  }) async {
    // A DIFFERENT key from the hold. Confirming is a separate mutation, and
    // reusing the hold's key would make the confirm look like a replay of it.
    final r = await guarded(
      () => _api.confirm(
        id: holdId,
        idempotencyKey: newIdempotencyKey(),
        body: ConfirmHoldDto(specialRequests: specialRequests, occasion: occasion),
      ),
    );

    return _booking(r);
  }

  @override
  Future<List<MyReservation>> myReservations({required String view}) async {
    final r = await guarded(() => _api.list2(status: view));
    return r.map(_mine).toList();
  }

  @override
  Future<MyReservation> reservation(String id) async {
    final r = await guarded(() => _api.one(id: id));
    return _mine(r);
  }

  @override
  Future<void> acknowledgeCancellation(String id) =>
      // NO IDEMPOTENCY KEY, and the generated signature is why: the header is
      // in the client only where the spec declares it, and this endpoint does
      // not. It is idempotent by construction anyway — a conditional UPDATE
      // that writes the timestamp once. See
      // `apps/api/src/shared/api/idempotency-contract.spec.ts` for the full
      // census of which mutations carry a key and which do not.
      guarded(() => _api.acknowledge(id: id));

  MyReservation _mine(MyReservationResponse r) => MyReservation(
        id: r.id,
        code: r.code,
        status: r.status,
        source: r.source,
        startsAt: r.startsAt,
        endsAt: r.endsAt,
        date: r.date,
        time: r.time,
        partySize: r.partySize,
        needsAcknowledgement: r.needsAcknowledgement,
        // Parsed to an enum HERE, once, rather than compared to a string in
        // three widgets. An unrecognised value becomes null, which the screens
        // already handle as "cancelled, actor unknown" — a server that gains a
        // third actor must not blank the whole screen on an unknown enum.
        cancelledBy: switch (r.cancelledBy) {
          'user' => CancelledBy.user,
          'restaurant' => CancelledBy.restaurant,
          _ => null,
        },
        cancelledAt: r.cancelledAt,
        cancelReason: r.cancelReason,
        specialRequests: r.specialRequests,
        occasion: r.occasion,
        venue: ReservationVenue(
          id: r.restaurant.id,
          slug: r.restaurant.slug,
          nameEn: r.restaurant.nameEn,
          nameAr: r.restaurant.nameAr,
          city: r.restaurant.city,
          timezone: r.restaurant.timezone,
          neighborhood: r.restaurant.neighborhood,
        ),
      );

  Booking _booking(ReservationResponse r) => Booking(
        id: r.id,
        code: r.code,
        status: r.status,
        startsAt: r.startsAt,
        endsAt: r.endsAt,
        partySize: r.partySize,
        holdExpiresAt: r.holdExpiresAt,
      );
}
