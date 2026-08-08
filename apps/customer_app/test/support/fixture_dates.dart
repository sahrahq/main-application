/// EVERY DATE THE TEST SUITE PINS, IN ONE PLACE.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS FILE EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// `Reservation/confirmed` was pinned to 2026-08-05. When modify shipped three
/// days after that date passed, the reservation screen correctly began hiding
/// its move button for any booking whose time had gone — and the golden named
/// "confirmed" quietly stopped picturing a confirmed booking that can be
/// changed.
///
/// **Nothing failed.** 103 goldens, 194 accessibility checks and 168 viewport
/// checks were all green while the picture changed meaning, because every one
/// of them asks "does this still look like last time" and the answer was yes:
/// it had looked like a settled booking the day before too.
///
/// A stale fixture does not break a test. It narrows what the test covers, and
/// the coverage number stays exactly where it was. That is the same class of
/// hole as a screen nothing routes to, one level down.
///
/// A golden must be deterministic, so these cannot be `now + n days`. They are
/// fixed values with `fixture_dates_test.dart` asserting they still mean what
/// they say — and, more importantly, SCANNING the test tree for any other date
/// literal that has escaped this file.
library;

/// A day comfortably ahead of now.
///
/// Use for anything that must read as UPCOMING: a confirmed booking that can
/// still be moved or cancelled, an availability grid, a slot a diner is about
/// to take. Anything whose screen branches on `startsAt.isAfter(now)`.
const String kFutureDate = '2027-08-05';

/// The day after [kFutureDate], for a second booking that must not collide.
const String kFutureDateNext = '2027-08-06';

/// A day comfortably behind now.
///
/// Use for anything that must read as SETTLED: a completed booking, a past
/// reservation, history. The guard on this one runs the other way — a
/// "completed" booking dated in the future is the same failure wearing the
/// opposite sign.
const String kPastDate = '2026-07-18';

/// How much warning the guard gives before [kFutureDate] goes stale.
///
/// Ninety days, because a month is not warning. It fails while moving the date
/// is a one-line change somebody makes deliberately, rather than a surprise in
/// the middle of an unrelated batch.
const int kFixtureNoticeDays = 90;
