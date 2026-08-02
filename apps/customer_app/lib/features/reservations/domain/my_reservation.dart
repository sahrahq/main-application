/// A diner's own reservation, as `GET /reservations` returns it. Pure Dart.
library;

class ReservationVenue {
  const ReservationVenue({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.city,
    required this.timezone,
    this.neighborhood,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameAr;
  final String city;

  /// The IANA zone the reservation's `date` and `time` are expressed in.
  final String timezone;

  final String? neighborhood;
}

/// Who ended it. Derived server-side, so nothing here parses a status string.
enum CancelledBy { user, restaurant }

class MyReservation {
  const MyReservation({
    required this.id,
    required this.code,
    required this.status,
    required this.source,
    required this.startsAt,
    required this.endsAt,
    required this.date,
    required this.time,
    required this.partySize,
    required this.needsAcknowledgement,
    required this.venue,
    this.cancelledBy,
    this.cancelledAt,
    this.cancelReason,
    this.specialRequests,
    this.occasion,
  });

  final String id;

  /// Human-readable, quoted at the door.
  final String code;

  /// `pending | confirmed | seated | completed | no_show | cancelled_*`.
  final String status;

  /// `app | walk_in | phone` — which door it came through. A walk-in appears
  /// here because it is genuinely the diner's visit; it just was not booked in
  /// this app, and the detail screen says so rather than offering to modify it.
  final String source;

  /// The absolute instant.
  final String startsAt;
  final String endsAt;

  /// `YYYY-MM-DD` and `HH:MM` **on the restaurant's wall clock**, computed by
  /// the server in [ReservationVenue.timezone].
  ///
  /// USE THESE, not `DateTime.parse(startsAt).toLocal()`. A diner in Cairo
  /// gets the same answer either way; a diner who booked from Dubai and is
  /// reading the list on the plane does not, and the number they need is the
  /// one the restaurant will be looking at.
  final String date;
  final String time;

  final int partySize;

  /// The RESTAURANT cancelled and this diner has not seen it yet.
  ///
  /// The one field on this object that the client must not merely display. It
  /// is the only signal that a booking the diner believes they hold is gone,
  /// and it keeps the reservation in `upcoming` regardless of date until
  /// `POST /reservations/{id}/acknowledge-cancellation`.
  final bool needsAcknowledgement;

  final ReservationVenue venue;

  final CancelledBy? cancelledBy;
  final String? cancelledAt;
  final String? cancelReason;
  final String? specialRequests;
  final String? occasion;

  bool get isCancelled => status.startsWith('cancelled');

  /// Booked in this app, as opposed to walked in or phoned through. The two
  /// non-app sources have no client-side actions at all.
  bool get isAppBooking => source == 'app';
}
