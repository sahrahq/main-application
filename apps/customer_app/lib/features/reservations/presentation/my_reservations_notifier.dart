import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
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
