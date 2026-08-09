/// C-4.7 — one notification, as the app understands it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SERVER SENDS A KIND AND SOME VALUES. THE CLIENT OWNS EVERY WORD.
/// ─────────────────────────────────────────────────────────────────────────
///
/// Exactly the doc 06 §1 error-code rule, applied again: `type` is
/// machine-readable, `data` carries the substitutions, and the sentence a diner
/// reads is assembled here from the ARB. The server renders finished text in
/// only one place — a push, which is drawn by the operating system on a lock
/// screen where there is no client to localise anything.
///
/// The consequence worth stating: switching the app to Arabic re-renders the
/// whole notification centre, including notifications recorded months ago in
/// English. Copy that had been baked in at write time could not do that.
library;

/// Every kind the server can send.
///
/// MIRRORS `NOTIFICATION_TYPES` IN `notification.ports.ts`, and
/// `notification_type_test.dart` reads that file off disk and fails if the two
/// drift — the same shape as the dietary vocabulary and the report reasons.
///
/// The drift is silent in the worse direction: a type the server sends and the
/// client has no case for would render as a blank row, because the alternative
/// (throwing) would take down the whole list for one unknown entry.
enum NotificationKind {
  reservationCancelledByVenue('reservation_cancelled_by_venue'),
  reservationConfirmed('reservation_confirmed'),
  reservationReminder24h('reservation_reminder_24h'),
  reservationReminder2h('reservation_reminder_2h'),
  waitlistOffer('waitlist_offer'),
  waitlistOfferExpired('waitlist_offer_expired'),

  /// Not a server value. What an unrecognised `type` becomes.
  ///
  /// A NEWER SERVER IS A NORMAL SITUATION — the app on a diner's phone is
  /// whatever they last updated to, and a type added next month arrives at a
  /// client built today. This is why the parse cannot throw.
  unknown('');

  const NotificationKind(this.wire);

  /// The exact string on the wire. `snake_case`, never Dart's `name`.
  final String wire;

  static NotificationKind parse(String wire) {
    for (final k in NotificationKind.values) {
      if (k != NotificationKind.unknown && k.wire == wire) return k;
    }
    return NotificationKind.unknown;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.data,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final NotificationKind kind;

  /// Substitutions and the deep-link target. Values are always strings — the
  /// API declares `additionalProperties: {type: string}`, so the generated
  /// model is a `Map<String, String>` rather than an untyped map.
  final Map<String, String> data;

  final DateTime createdAt;

  /// When the diner FIRST saw it. Never re-stamped by a later read.
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// The reservation this is about, if it is about one.
  ///
  /// Read from `data` rather than promoted to a column, because most types have
  /// one and some do not — a nullable field on every notification would invite
  /// a `!` at the tap site, and the tap site is where a crash is least welcome.
  String? get reservationId => data['reservation_id'];

  /// The venue, for the types that carry one but no reservation.
  String? get restaurantId => data['restaurant_id'];
}
