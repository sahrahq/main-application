import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pending_booking.g.dart';

/// A slot the diner chose but has not yet been able to hold, kept across a
/// sign-in detour.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS IS IN MEMORY AND NOT IN THE URL. Do not "improve" it into a route
/// parameter.
/// ─────────────────────────────────────────────────────────────────────────
///
/// A slot in the URL is a slot that survives a browser refresh, a bookmark, a
/// paste into a chat, and a back-button return an hour later. **Every one of
/// those re-attempts a hold against availability that has since moved.** The
/// diner then gets a `slot_taken` they cannot explain, at the exact moment
/// they have just finished signing in — the worst possible moment to hand
/// someone an error they did not cause.
///
/// This notifier is PROCESS-SCOPED, and that is the feature rather than a
/// limitation: if the app restarts, the pending selection is correctly gone,
/// because a selection made before a restart is a selection whose availability
/// we can no longer vouch for.
///
/// TWO THINGS THAT ARE NOT THE SAME, and must not be conflated:
///
///  1. **The post-401 round trip** — this. Ephemeral, in-memory, never
///     shareable. It exists to carry a selection across one sign-in.
///  2. **A shareable venue/slot deep link** — a distinct future feature. If it
///     is ever built it must RE-VALIDATE availability on arrival and land the
///     recipient on a FRESH slot picker with the date and party prefilled. It
///     must never re-attempt a stale hold. Do not smuggle it in through the
///     URL as a side effect of this.
class PendingSelection {
  const PendingSelection({
    required this.restaurantId,
    required this.venueName,
    required this.startsAt,
    required this.slotLabel,
    required this.date,
    required this.partySize,
  });

  final String restaurantId;
  final String venueName;

  /// The absolute instant, as availability gave it. Still the only bookable
  /// form — see sahra_api_client/README.md §2.
  final String startsAt;

  /// `HH:MM` on the venue's clock, for showing the diner what they chose.
  final String slotLabel;

  /// `YYYY-MM-DD`. THE MACHINE FORM — it goes back to `BookingSelection` on the
  /// return trip, so it must stay exactly as availability was asked for.
  /// Anything shown to a diner goes through [dateLabel] instead.
  final String date;
  final int partySize;

  /// Whether this selection can be turned into the sentence a diner reads on
  /// the sign-in screen.
  ///
  /// EVERY FIELD HERE IS REQUIRED AND NON-NULLABLE, so this is not guarding
  /// against a missing field — it is guarding against an EMPTY one. A venue
  /// with no name, a date the server sent blank, a party size of zero: each is
  /// individually plausible and each produces a sentence that still reads as
  /// finished. "Your table: , 4 August at 18:00, 2 guests" is not obviously
  /// broken to the person reading it; it just looks like the restaurant has no
  /// name.
  ///
  /// The caller renders nothing at all when this is false. A partial sentence
  /// that reads as complete is worse than no sentence, because nobody reports
  /// it.
  bool get canDescribe =>
      venueName.trim().isNotEmpty &&
      date.trim().isNotEmpty &&
      slotLabel.trim().isNotEmpty &&
      partySize > 0;
}

/// Keyed by venue, so a diner who wandered between two restaurants before
/// signing in comes back to the right one.
///
/// `keepAlive`, and the round-trip test is what proved it has to be. An
/// auto-disposing notifier is disposed the moment nothing watches it — which
/// is precisely the moment the booking screen parks a selection and navigates
/// away. The selection was written and destroyed in the same frame, and the
/// sign-in screen then created a fresh one and read null out of it.
///
/// This does NOT weaken the process-scoping above. `keepAlive` binds the
/// selection to the ProviderContainer, and the container dies with the app: a
/// restart still loses it, which is still the feature.
@Riverpod(keepAlive: true)
class PendingBooking extends _$PendingBooking {
  @override
  PendingSelection? build(String restaurantId) => null;

  void remember(PendingSelection selection) => state = selection;

  /// Cleared once the hold has been re-attempted, successfully or not. Leaving
  /// it set would re-fire on the next rebuild.
  void clear() => state = null;
}
