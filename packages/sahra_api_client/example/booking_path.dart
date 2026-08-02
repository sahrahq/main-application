// A COMPILE-TIME CANARY for the customer booking path.
//
// This file does not run. It exists so that the call sites screens will use
// are type-checked by CI TODAY, before those screens exist — a backend change
// that breaks them fails here rather than in a widget three weeks from now.
//
// It is also the honest demonstration of guarantee 3: rename a field or change
// a type in the backend, regenerate, and `dart analyze` fails ON THIS LINE.
import 'package:sahra_api_client/sahra_api_client.dart';

/// search → detail → book, exactly as the screens will do it.
Future<ReservationResponse> bookFromSearch(
  SahraApi api, {
  required String query,
  required String date,
  required int partySize,
  required String idempotencyKey,
}) async {
  // 1. DISCOVERY. Note what is NOT used from this: `next_available` is a hint
  //    and carries no absolute instant — see README, "what it does NOT
  //    guarantee".
  final SearchResponse results = await api.find(
    q: query,
    availableAt: date,
    partySize: '$partySize',
  );
  final SearchResultResponse venue = results.results.first;

  // 2. REAL AVAILABILITY. The only source of a bookable instant.
  final AvailabilityResponse availability = await api.getSlots(
    id: venue.id,
    date: date,
    partySize: '$partySize',
  );
  final SlotResponse slot = availability.slots.first;

  // 3. HOLD. `startsAt` — the absolute UTC instant — never `time`, which is
  //    the diner-facing wall clock. This can still throw 409 slot_taken; the
  //    screen must offer alternatives rather than swallow it.
  final ReservationResponse hold = await api.createHold(
    body: CreateHoldDto(
      restaurantId: venue.id,
      startsAt: slot.startsAt,
      partySize: partySize,
    ),
    idempotencyKey: idempotencyKey,
  );

  // 4. CONFIRM — a SEPARATE idempotency key, per doc 06 §1.
  return api.confirm(
    id: hold.id,
    body: const ConfirmHoldDto(),
    idempotencyKey: '$idempotencyKey-confirm',
  );
}
