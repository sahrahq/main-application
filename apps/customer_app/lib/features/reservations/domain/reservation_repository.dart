import '../../restaurants/domain/review.dart';
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

    /// ── DELIBERATELY UNCOLLECTED BY THIS APP, 2026-08-11 ──────────────────
    ///
    /// The API accepts it (free text, max 40, no enum), `MyReservation` reads
    /// it back, and **nothing in the client ever sets it.** That is a decision,
    /// not a gap, and it is recorded here rather than in a doc because here is
    /// where the next reader meets the parameter.
    ///
    /// There is NO DESIGN for capturing an occasion on a booking. Searched
    /// every reference: `BookingFlowScreen.jsx` and `ConfirmationScreen.jsx`
    /// have no such input, and `OccasionScreen.jsx` — which sounds like the
    /// picker and is not — is a Ramadan/Iftar seasonal LANDING PAGE reached
    /// from a Discover banner, part of the deferred offers/events family.
    ///
    /// Inventing a picker would mean designing a vocabulary with no reference,
    /// and it would be thrown away. Worse, it would be designed from one side:
    /// **whether asking a diner is worth it depends on what a venue does with
    /// the answer**, and the venue's view does not exist until
    /// `management_app` is built. Both sides get designed together, then.
    ///
    /// The parameter stays because the API and the management app will want
    /// it, and because removing it from the port would mean re-adding it
    /// later to the same signature.
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

  /// Move a booking, or change how many are coming (C-3.4).
  ///
  /// Returns the reservation as it now stands, so the caller replaces its
  /// state from the response instead of re-fetching — one round trip, and no
  /// window in which the screen shows the old time.
  ///
  /// NO IDEMPOTENCY KEY, and that is a decision rather than an omission: the
  /// arguments are absolute, so replaying lands on the same window with the
  /// same party. Recorded in `idempotency-contract.spec.ts`.
  ///
  /// Throws `ConflictFailure(code: 'slot_taken')` when the target went while
  /// the diner was choosing — the normal path, not an exceptional one. Also
  /// `invalid_status_transition` and `reservation_not_modifiable`.
  ///
  /// At least one of [startsAt] and [partySize] must be given; a call naming
  /// neither is refused by the server rather than treated as a success.
  Future<MyReservation> modify({
    required String id,
    String? startsAt,
    int? partySize,
  });

  /// The diner cancels their own booking (C-3.5).
  ///
  /// A DIFFERENT ENDPOINT from the venue's cancel, and it must stay that way:
  /// the actor recorded on the row is the only input to the acknowledgement
  /// model. [reason] is optional here and required there — nobody reads the
  /// diner's with the same stakes, and demanding one would make cancelling
  /// harder than simply not turning up.
  Future<MyReservation> cancel({required String id, String? reason});

  /// The times [id] could be moved to on [date].
  ///
  /// NOT [slots]. That grid is what a NEW booker sees, and it hides the tables
  /// this reservation is holding — including the slots either side of it, once
  /// the turn time is longer than the interval. Those are legal destinations
  /// for a move, so a picker built on the public grid would leave the diner's
  /// most likely choices off the screen.
  ///
  /// [partySize] defaults to the booking's own on the server, so "same party,
  /// different time" needs nothing passed.
  Future<SlotBoard> movableSlots({
    required String id,
    required String date,
    int? partySize,
  });

  /// Review a visit (C-4.4, doc 06 §"Reviews").
  ///
  /// ON THIS REPOSITORY, not on the restaurant one, because the subject is a
  /// RESERVATION. The API keys the review on `reservation_id` and refuses
  /// anything else, so a signature that took a restaurant id would be a
  /// signature that could not be satisfied.
  ///
  /// No idempotency key. `reservation_id` is UNIQUE server-side: a replay gets
  /// a typed 409 (`review_already_exists`) rather than a second review.
  ///
  /// [body] is optional — stars alone is a complete review, and an empty or
  /// whitespace-only body is sent as null rather than as a blank the CHECK
  /// constraint would refuse.
  Future<Review> createReview({
    required String reservationId,
    required int rating,
    int? foodRating,
    int? serviceRating,
    int? ambienceRating,
    String? body,
  });
}
