import 'booking.dart';

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
}
