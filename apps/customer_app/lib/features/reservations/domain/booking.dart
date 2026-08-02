/// Reservation entities. Pure Dart.
library;

/// A bookable slot.
///
/// TWO TIME FIELDS, AND THEY ARE NOT INTERCHANGEABLE. [label] is what a diner
/// reads; [startsAt] is what the server accepts. Reconstructing an instant
/// from the label plus a guessed timezone books the wrong hour, and in Cairo
/// that is a 2–3 hour error depending on the date
/// (sahra_api_client/README.md §2).
class Slot {
  const Slot({required this.label, required this.startsAt, required this.zones});

  /// `HH:MM` on the RESTAURANT's wall clock.
  final String label;

  /// The absolute instant, ISO-8601 UTC. POST this back, never [label].
  final String startsAt;

  final List<String> zones;
}

class SlotBoard {
  const SlotBoard({
    required this.date,
    required this.partySize,
    required this.timezone,
    required this.slots,
  });

  final String date;
  final int partySize;
  final String timezone;

  /// ALREADY STALE. Availability is derived, never stored (doc 05 §1), and the
  /// engine decides under a per-restaurant advisory lock at the moment of the
  /// write. Creating a hold can and will return 409 `slot_taken` for a time
  /// this list is displaying — that is correct behaviour, not a bug to
  /// suppress.
  final List<Slot> slots;
}

/// A held or confirmed reservation.
class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.partySize,
    this.holdExpiresAt,
  });

  final String id;

  /// Human-readable, e.g. `SAH-7K2M`. What a diner quotes at the door.
  final String code;

  /// `held` → `confirmed`. Anything else on this path is a bug.
  final String status;

  final String startsAt;
  final String endsAt;
  final int partySize;

  /// When the hold lapses. Null once confirmed.
  final String? holdExpiresAt;

  bool get isHeld => status == 'held';
}
