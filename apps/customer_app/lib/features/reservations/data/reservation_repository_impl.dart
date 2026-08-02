import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../../../core/utils/idempotency_key.dart';
import '../domain/booking.dart';
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
