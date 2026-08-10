import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../domain/booking.dart';
import '../domain/my_reservation.dart';

part 'my_reservations_notifier.g.dart';

/// Which half of the bookings screen is showing.
@riverpod
class BookingsView extends _$BookingsView {
  @override
  String build() => 'upcoming';

  void show(String view) => state = view;
}

/// The diner's reservations for the selected view.
///
/// WATCHES THE SESSION, and that is not incidental. Signing in on another
/// screen has to make this list appear, and signing out has to make it vanish
/// — if it only read the session once, a diner who signed in from the empty
/// state would be looking at "sign in to see your bookings" while holding a
/// valid token.
///
/// Signed out it returns EMPTY rather than calling and catching the 401. The
/// screen shows its own signed-out state; making the round trip first would put
/// an error in the log for a situation that is not an error.
@riverpod
Future<List<MyReservation>> myReservations(Ref ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const <MyReservation>[];

  return ref.watch(reservationRepositoryProvider).myReservations(
        view: ref.watch(bookingsViewProvider),
      );
}

/// One reservation, for the detail screen.
@riverpod
Future<MyReservation> reservationDetail(Ref ref, String id) {
  ref.watch(currentSessionProvider);
  return ref.watch(reservationRepositoryProvider).reservation(id);
}

/// "I have seen that the restaurant cancelled."
///
/// A NOTIFIER RATHER THAN A CALL FROM THE WIDGET, because it has to invalidate
/// two things afterwards: the detail this was tapped on, and the list that is
/// still showing the reservation in `upcoming` because of the very flag being
/// cleared. Acknowledging on the detail screen and going back to a list that
/// still says "the restaurant cancelled — got it?" is the bug this prevents.
@riverpod
class AcknowledgeCancellation extends _$AcknowledgeCancellation {
  @override
  bool build() => false;

  Future<void> acknowledge(String id) async {
    if (state) return;
    state = true;
    try {
      await ref.read(reservationRepositoryProvider).acknowledgeCancellation(id);
      ref.invalidate(reservationDetailProvider(id));
      ref.invalidate(myReservationsProvider);
    } finally {
      state = false;
    }
  }
}

/// What the diner has picked so far in the move sheet, for one reservation.
///
/// Seeded from the booking itself, so opening the sheet shows where they
/// currently are rather than an empty form — the change is almost always
/// relative to the existing booking, and making them re-enter it is how a
/// modify screen ends up being used to book the wrong day.
class MoveSelection {
  const MoveSelection({
    required this.date,
    required this.partySize,
    this.startsAt,
  });

  /// YYYY-MM-DD, the venue's wall-clock day.
  final String date;
  final int partySize;

  /// The chosen slot, or null while they are still looking.
  final String? startsAt;

  MoveSelection copyWith({String? date, int? partySize, String? startsAt}) => MoveSelection(
        date: date ?? this.date,
        partySize: partySize ?? this.partySize,
        startsAt: startsAt ?? this.startsAt,
      );
}

@riverpod
class MoveDraft extends _$MoveDraft {
  @override
  MoveSelection build(String id, String date, int partySize) =>
      MoveSelection(date: date, partySize: partySize);

  /// Changing the day or the party invalidates the chosen slot.
  ///
  /// A slot id is only meaningful for the query that produced it. Keeping it
  /// across a change would let the diner submit Tuesday's 8pm having switched
  /// to Wednesday — the server would accept it, because it is a valid instant,
  /// and they would be booked on the wrong day.
  void setDate(String value) => state = MoveSelection(date: value, partySize: state.partySize);

  void setPartySize(int value) => state = MoveSelection(date: state.date, partySize: value);

  void choose(String startsAt) => state = state.copyWith(startsAt: startsAt);
}

/// The grid for the move sheet.
///
/// `movableSlots`, NOT `slots`. The difference is the reservation being moved:
/// its own tables count as free, so the times either side of the current
/// booking are offered. See the repository note.
@riverpod
Future<SlotBoard> movableSlots(Ref ref, String id, String date, int partySize) {
  ref.watch(currentSessionProvider);
  return ref.watch(reservationRepositoryProvider).movableSlots(
        id: id,
        date: date,
        partySize: partySize,
      );
}

/// What a cancel or a modify is currently doing, for one reservation.
///
/// Sealed rather than a pair of booleans plus a nullable failure: the states
/// are mutually exclusive, and three independent flags can express
/// "succeeded and failed at once", which a `switch` on this cannot.
sealed class ReservationActionState {
  const ReservationActionState();
}

/// Nothing in flight. The buttons are live.
class ReservationActionIdle extends ReservationActionState {
  const ReservationActionIdle();
}

/// A call is out. Both buttons are disabled — a diner who taps cancel while a
/// modify is still travelling would otherwise race their own request.
class ReservationActionBusy extends ReservationActionState {
  const ReservationActionBusy();
}

/// The server refused, and [failure] says why in the diner's language.
class ReservationActionFailed extends ReservationActionState {
  const ReservationActionFailed(this.failure);
  final Failure failure;
}

/// Cancel and modify for one reservation (C-3.4, C-3.5).
///
/// ONE NOTIFIER FOR BOTH, keyed by reservation id, because they share the
/// thing that actually needs coordinating: while either is in flight, neither
/// button may be tapped. Two notifiers would each know only their own half.
///
/// EVERY SUCCESS INVALIDATES THE LIST AS WELL AS THE DETAIL. A booking that
/// was cancelled or moved is wrong in both places, and the list is the screen
/// the diner returns to — leaving it stale shows the old time on the card they
/// just changed, which reads as the change having failed.
@riverpod
class ReservationAction extends _$ReservationAction {
  @override
  ReservationActionState build(String id) => const ReservationActionIdle();

  Future<bool> cancel({String? reason}) => _run(
        () => ref.read(reservationRepositoryProvider).cancel(id: id, reason: reason),
      );

  Future<bool> modify({String? startsAt, int? partySize}) => _run(
        () => ref.read(reservationRepositoryProvider).modify(
              id: id,
              startsAt: startsAt,
              partySize: partySize,
            ),
      );

  /// Returns whether it worked, so the caller can close a sheet only on
  /// success — a sheet that closes on failure takes the error message with it.
  Future<bool> _run(Future<MyReservation> Function() call) async {
    if (state is ReservationActionBusy) return false;
    state = const ReservationActionBusy();

    try {
      await call();
      ref.invalidate(reservationDetailProvider(id));
      ref.invalidate(myReservationsProvider);
      state = const ReservationActionIdle();
      return true;
    } on Failure catch (f) {
      state = ReservationActionFailed(f);
      return false;
    }
  }
}
