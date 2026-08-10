/// Why a diner is reporting a review — C-4.4.
///
/// A CLOSED SET, mirrored from the `report_reason` enum in
/// `20260809030000_review_reports`. A reason picked from five is one a moderator
/// can sort a queue by; free text is one they have to read first.
///
/// `report_reason_test.dart` reads the enum out of the migration on disk and
/// fails if the two lists drift — the same shape as the dietary vocabulary,
/// and for the same reason: a value the database accepts but the client has no
/// label for would silently vanish from the sheet.
enum ReportReason {
  spam,
  abusive,

  /// The one that is about US rather than the reviewer. A review attached to
  /// the wrong reservation is a bug in the verified-diner guarantee, not a
  /// moderation question, so it is reachable rather than folded into `other`.
  notMyVisit,
  wrongVenue,
  other;

  /// The wire value. `snake_case`, because that is what the enum in Postgres
  /// is — Dart's `name` would send `notMyVisit` and the API would refuse it.
  String get wire => switch (this) {
        ReportReason.spam => 'spam',
        ReportReason.abusive => 'abusive',
        ReportReason.notMyVisit => 'not_my_visit',
        ReportReason.wrongVenue => 'wrong_venue',
        ReportReason.other => 'other',
      };
}
