import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../domain/booking.dart';
import 'pending_booking.dart';

part 'booking_notifier.g.dart';

/// What the booking screen is asking for: which venue, which day, how many.
class BookingCriteria {
  const BookingCriteria({
    required this.restaurantId,
    required this.date,
    this.partySize = 2,
  });

  final String restaurantId;

  /// `YYYY-MM-DD`.
  final String date;
  final int partySize;

  BookingCriteria copyWith({String? date, int? partySize}) => BookingCriteria(
        restaurantId: restaurantId,
        date: date ?? this.date,
        partySize: partySize ?? this.partySize,
      );
}

@riverpod
class BookingSelection extends _$BookingSelection {
  @override
  BookingCriteria build(String restaurantId) =>
      BookingCriteria(restaurantId: restaurantId, date: todayIso());

  void setDate(String date) => state = state.copyWith(date: date);

  void setPartySize(int size) => state = state.copyWith(partySize: size);
}

/// The real, bookable slots. NOT search's `next_available`.
@riverpod
Future<SlotBoard> availableSlots(Ref ref, String restaurantId) {
  final criteria = ref.watch(bookingSelectionProvider(restaurantId));
  return ref.watch(reservationRepositoryProvider).slots(
        restaurantId: restaurantId,
        date: criteria.date,
        partySize: criteria.partySize,
      );
}

/// Where the booking attempt has got to.
sealed class BookingProgress {
  const BookingProgress();
}

class BookingIdle extends BookingProgress {
  const BookingIdle();
}

class BookingInFlight extends BookingProgress {
  const BookingInFlight();
}

class BookingDone extends BookingProgress {
  const BookingDone(this.booking);
  final Booking booking;
}

/// The slot went while the diner was choosing.
///
/// A STATE, not an error banner. doc 06 §6 requires a booking 409 to carry
/// alternatives — "turn failure into conversion" — and 11-user-flows §3 draws
/// the arrow from here back to the slot picker, not to a dead end. So this
/// carries the failure AND the screen re-runs availability behind it.
class BookingSlotTaken extends BookingProgress {
  const BookingSlotTaken(this.failure);
  final ConflictFailure failure;
}

/// The 5-minute window closed mid-flow (doc 05 §4).
class BookingHoldExpired extends BookingProgress {
  const BookingHoldExpired(this.failure);
  final ConflictFailure failure;
}

/// Anything else — offline, 500, validation.
class BookingFailed extends BookingProgress {
  const BookingFailed(this.failure);
  final Failure failure;
}

/// The diner is not signed in, and booking requires an account (C-1.6).
///
/// A STATE, not an error, for the same reason [BookingSlotTaken] is one: the
/// diner did nothing wrong and there is somewhere for them to go. It carries
/// the whole selection so the screen can hand it to [PendingBooking] and get
/// it back afterwards.
///
/// NOT DERIVED FROM `isSignedIn` BEFORE CALLING. The 401 comes from the server,
/// which is the only party that knows whether this token is still good — a
/// client-side check would also have to guess about expiry, revocation and
/// suspension, and would guess wrong in exactly the cases that matter. The
/// token being absent is just the cheapest way to fail that check.
class BookingNeedsSignIn extends BookingProgress {
  const BookingNeedsSignIn(this.selection);
  final PendingSelection selection;
}

/// The hold → confirm sequence, the highest-risk logic in the product.
///
/// It lives in a notifier and not in a widget, so it can be unit-tested
/// without a widget tree (doc 07 §4 targets ~100% on the booking state
/// machine) and so `use_build_context_synchronously` has nothing to catch.
///
/// TWO CALLS, NOT ONE, and deliberately not collapsed: the hold takes the
/// table off the market for five minutes and the confirm commits it. Between
/// them is where a deposit sheet goes (C-4.1) and where the diner can still
/// walk away.
@riverpod
class BookingFlow extends _$BookingFlow {
  @override
  BookingProgress build(String restaurantId) => const BookingIdle();

  Future<void> book({
    required String startsAt,
    required int partySize,
    String? specialRequests,
    String? occasion,
    PendingSelection? selection,
  }) async {
    state = const BookingInFlight();
    final repo = ref.read(reservationRepositoryProvider);

    try {
      final held = await repo.hold(
        restaurantId: restaurantId,
        startsAt: startsAt,
        partySize: partySize,
      );

      final confirmed = await repo.confirm(
        holdId: held.id,
        specialRequests: specialRequests,
        occasion: occasion,
      );

      state = BookingDone(confirmed);
    } on ConflictFailure catch (f) {
      // The two 409s mean different things to a diner and get different
      // screens. `slot_taken`: somebody else was faster, here are other times.
      // `hold_expired`: you were, here is the picker again.
      state = f.code == 'hold_expired'
          ? BookingHoldExpired(f)
          : BookingSlotTaken(f);

      // Either way the board on screen is now known to be wrong. Refresh it
      // BEFORE the diner looks, so the alternatives they are offered are real
      // ones rather than the same stale list that just failed.
      ref.invalidate(availableSlotsProvider(restaurantId));
    } on AuthFailure {
      // C-1.6. Only reachable with a selection to carry — a re-attempt after
      // sign-in always passes one, so a second 401 (a token that expired
      // between signing in and confirming) still lands here with something to
      // come back to rather than dropping the diner into a generic error.
      state = selection == null
          ? const BookingFailed(AuthFailure())
          : BookingNeedsSignIn(selection);
    } on Failure catch (f) {
      state = BookingFailed(f);
    }
  }

  void reset() => state = const BookingIdle();
}

/// `YYYY-MM-DD` for today on the device clock. See the note in
/// `search_notifier.dart` about why this is an approximation.
String todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Which slot the diner has tapped, as an absolute `startsAt`.
///
/// Keyed by `startsAt` rather than by the `HH:MM` label, so the selection
/// survives a refresh that reorders the board and so nothing downstream can
/// accidentally send a wall-clock string to the booking engine.
///
/// Cleared whenever the date or party size changes: a 21:00 chosen for
/// Thursday is not a 21:00 for Friday, and leaving it selected across the
/// change is how a diner books the wrong night.
@riverpod
class ChosenSlot extends _$ChosenSlot {
  @override
  String? build(String restaurantId) {
    ref.listen(bookingSelectionProvider(restaurantId), (_, __) => state = null);
    return null;
  }

  void choose(String startsAt) => state = startsAt;
}
