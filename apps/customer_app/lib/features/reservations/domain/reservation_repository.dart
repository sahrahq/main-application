import 'booking.dart';
import 'my_reservation.dart';

/// Availability and booking. Pure Dart.
abstract class ReservationRepository {
  /// Real bookable slots for a date and party size (doc 06 §3).
  ///
  /// This — not search's `next_available` — is the only source of a bookable
  /// `startsAt`.
  Future<SlotBoard> slots({
    required String restaurantId,
    required String date,
    required int partySize,
  });

  /// Place a 5-minute hold (doc 06 §3, doc 05 §4).
  ///
  /// Throws `ConflictFailure(code: 'slot_taken')` when the table went between
  /// being displayed and being asked for. That is the normal path, not an
  /// exceptional one — the whole engine exists because two diners can want the
  /// last table at the same moment.
  ///
  /// The `Idempotency-Key` is generated inside the implementation and held for
  /// the life of one attempt, so a network retry cannot produce two holds.
  Future<Booking> hold({
    required String restaurantId,
    required String startsAt,
    required int partySize,
    String? seatingPref,
    String? guestName,
    String? guestPhone,
    String? specialRequests,
    String? occasion,
  });

  /// Confirm a hold inside its window (doc 06 §3).
  ///
  /// A SEPARATE idempotency key from the hold — this is a separate mutation,
  /// and reusing the key would make the confirm look like a replay of the hold.
  ///
  /// Throws `ConflictFailure(code: 'hold_expired')` when the window closed.
  Future<Booking> confirm({
    required String holdId,
    String? specialRequests,
    String? occasion,
  });

  /// The caller's own reservations (doc 06 §3).
  ///
  /// OWNERSHIP IS NOT A PARAMETER. There is no `userId` here and there must
  /// never be one — the server derives it from the token and puts it in the
  /// WHERE clause of every query. An id that a client could pass is an id a
  /// client could change.
  ///
  /// [view] is `upcoming` or `past`. `held` and `expired` reservations appear
  /// in neither: a five-minute hold is not a booking, and showing one would
  /// promise a table that is about to be released.
  Future<List<MyReservation>> myReservations({required String view});

  /// One of the caller's own. 404 for someone else's — byte-identical to a 404
  /// for an id that exists for nobody, deliberately.
  Future<MyReservation> reservation(String id);

  /// Mark a restaurant-initiated cancellation as seen.
  ///
  /// ITS OWN CALL, never a side effect of reading the detail screen. A read
  /// that acknowledged would be acknowledged by a prefetch, a retry or a list
  /// render, none of which is a human reading the notice — and the notice
  /// existing at all is the difference between a diner knowing and a diner
  /// arriving at a restaurant that is not expecting them.
  Future<void> acknowledgeCancellation(String id);
}
