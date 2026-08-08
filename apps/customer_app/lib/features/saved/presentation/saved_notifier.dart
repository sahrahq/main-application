import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../domain/saved_repository.dart';

part 'saved_notifier.g.dart';

/// The diner's saved venues.
///
/// WATCHES THE SESSION, like `myReservations` and for the same reason: signing
/// in on another screen has to make this list appear, and signing out has to
/// make it vanish. Signed out it returns EMPTY rather than calling and
/// catching the 401 — the screen shows its own signed-out state, and making
/// the round trip first would log an error for a situation that is not one.
@riverpod
Future<List<SavedVenue>> savedVenues(Ref ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const <SavedVenue>[];

  return ref.watch(savedRepositoryProvider).saved();
}

/// Which venue ids are saved, for the heart on a card.
///
/// DERIVED FROM THE ONE LIST, not fetched per card. A `savedIds` that made its
/// own request would be a second source of truth for the same fact, and the
/// two would disagree for exactly as long as one of them was stale — which is
/// the window in which a diner taps a filled heart and it fills again.
@riverpod
Set<String> savedVenueIds(Ref ref) {
  final list = ref.watch(savedVenuesProvider).valueOrNull;
  return (list ?? const <SavedVenue>[]).map((s) => s.venue.id).toSet();
}

/// Save and unsave, for one venue.
///
/// ── OPTIMISTIC, AND IT ROLLS BACK ────────────────────────────────────────
///
/// The heart fills on tap, before the server answers. A save that waited for a
/// round trip on a Cairo mobile connection would feel broken, and the diner
/// would tap again — which is exactly why both endpoints are idempotent.
///
/// But an optimistic update that cannot roll back is a lie: if the call fails,
/// the heart stays filled and the venue is not saved, and the diner finds out
/// when the list is empty. So the failure path puts the list back.
@riverpod
class SaveToggle extends _$SaveToggle {
  @override
  bool build(String restaurantId) => ref.watch(savedVenueIdsProvider).contains(restaurantId);

  /// Returns whether it worked, so the caller can say something when it did
  /// not.
  ///
  /// **DOES NOT RETHROW.** The first version did, and the throw had no
  /// handler: `onPressed` is fire-and-forget, so a failed save became an
  /// unhandled async error — a red screen in debug and a silent nothing in
  /// release. Returning a result is the same shape `ReservationAction` uses,
  /// and for the same reason.
  Future<bool> toggle() async {
    final wasSaved = state;
    // Optimistic.
    state = !wasSaved;

    try {
      final repo = ref.read(savedRepositoryProvider);
      if (wasSaved) {
        await repo.unsave(restaurantId);
      } else {
        await repo.save(restaurantId);
      }
      // The list is now wrong in the other direction; refetch it so the saved
      // screen and every other heart agree with the server rather than with
      // this widget's local guess.
      ref.invalidate(savedVenuesProvider);
      return true;
    } catch (_) {
      // ROLLED BACK. A heart left filled over a failed save is worse than one
      // that never filled: it tells the diner the venue is in a list it is
      // not, and they find out when they go looking for it.
      state = wasSaved;
      return false;
    }
  }
}

/// Toggle, and tell the diner if it did not work.
///
/// A HEART THAT UN-FILLS IS A SIGNAL, BUT A QUIET ONE. Somebody watching their
/// thumb rather than the corner of the screen sees nothing at all, and
/// concludes the save worked. The snack bar is the difference between a
/// failure they can act on and one they discover a week later when the list is
/// short.
Future<void> toggleSavedAndReport(
  BuildContext context,
  WidgetRef ref, {
  required String restaurantId,
}) async {
  final ok = await ref.read(saveToggleProvider(restaurantId).notifier).toggle();
  if (ok || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).savedFailed)),
  );
}
