import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../domain/my_reservation.dart';

/// Reservation status → words and a badge, in ONE place.
///
/// Seven statuses, three screens. Left to each screen this becomes three
/// slightly different vocabularies — the list saying "Cancelled", the detail
/// saying "Cancelled by the restaurant", and the third one having forgotten
/// `no_show` exists.
///
/// The fallback is the status string itself rather than an empty box. A server
/// that gains an eighth status must not produce a blank badge on a screen a
/// diner is trying to read, and a raw `seated_late` on screen is at least a
/// reportable bug rather than an invisible one.
String reservationStatusLabel(MyReservation r, AppLocalizations l10n) =>
    switch (r.status) {
      'pending' => l10n.statusPending,
      'confirmed' => l10n.statusConfirmed,
      'seated' => l10n.statusSeated,
      'completed' => l10n.statusCompleted,
      'no_show' => l10n.statusNoShow,
      'cancelled_by_user' => l10n.statusCancelledByUser,
      'cancelled_by_restaurant' => l10n.statusCancelledByRestaurant,
      _ => r.status,
    };

SahraBadgeVariant reservationStatusVariant(MyReservation r) => switch (r.status) {
      'confirmed' || 'seated' => SahraBadgeVariant.success,
      'pending' => SahraBadgeVariant.warning,
      'no_show' => SahraBadgeVariant.error,
      // Cancelled is NEUTRAL, not error. It is often the correct outcome —
      // plans change — and painting every cancellation red tells a diner
      // looking down their history that something went wrong seven times.
      _ => SahraBadgeVariant.neutral,
    };

/// The venue's name in the reading language.
///
/// Falls back across the pair rather than to an empty string: a venue that has
/// only registered one of the two names still has to be nameable on the screen
/// where someone is trying to find their booking.
String venueName(ReservationVenue v, BuildContext context) {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final preferred = ar ? v.nameAr : v.nameEn;
  return preferred.isNotEmpty ? preferred : (ar ? v.nameEn : v.nameAr);
}

/// `YYYY-MM-DD` + `HH:MM`, both already on the venue's wall clock, rendered as
/// "5 August · 21:00".
///
/// The month name is localised and the DIGITS stay Latin — DESIGN-RULES.md
/// rules out Arabic-Indic numerals for figures, and `intl` has no flag that
/// localises the month while holding the numeral. Same reasoning, and the same
/// month table, as the confirmation ticket.
String reservationWhen(MyReservation r, BuildContext context) =>
    '${dayAndMonth(r.date, context)} · ${timeOfDay(r.time, context)}';

/// `20:00` → `8:00 م` / `8:00 PM`, or `20:00` where the phone says 24-hour.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE ACTUAL DEFECT WAS THAT THIS FUNCTION DID NOT EXIST
/// ─────────────────────────────────────────────────────────────────────────
///
/// Dates had a convention — [dayAndMonth] — and times had none, so thirteen
/// sites each interpolated a raw `HH:MM` and every one of them was wrong in
/// the same way. Nobody in Egypt reads a booking as "20:00"; they read
/// "8 مساءً". Every test passed, because the strings were correct and wrong
/// for humans, and no test was ever going to catch that.
///
/// One owner. Thirteen edits would have been the same defect thirteen times.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY LOCALE `ar` AND NOT `ar_EG`, WHEN THE APP IS FOR EGYPT
/// ─────────────────────────────────────────────────────────────────────────
///
/// The obvious question, and the answer is not obvious. Measured on
/// 2026-08-10, both produce the IDENTICAL marker — `ص` / `م`, one letter,
/// after the numeral:
///
///     DateFormat('jm', 'ar_EG')  →  ٨:٠٠ م   (U+0668 …)
///     DateFormat('jm', 'ar')     →  8:00 م   (U+0038 …)
///
/// The only difference is the digit family, and **`ar_EG` forces
/// Arabic-Indic**, including in the 24-hour form (`٢٠:٠٠`). That collides
/// head-on with ENGINEERING-STANDARDS §Numerals — "Latin digits in both
/// locales" — a rule already enforced by a guard and already found violated
/// twice. `ar` gives the Egyptian reading with the required figures.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SEPARATOR IS NOT OURS TO CHOOSE
/// ─────────────────────────────────────────────────────────────────────────
///
/// English separates the numeral from AM/PM with **U+202F** (narrow no-break
/// space); Arabic uses a plain **U+0020**. `DateFormat` emits the right one.
/// Hardcoding either would be subtly wrong in one locale, and
/// `time_format_test.dart` asserts the two DIFFER so a future tidy-up that
/// normalises them fails loudly.
///
/// 12 vs 24 FOLLOWS THE DEVICE, exactly as theme does —
/// `MediaQuery.alwaysUse24HourFormat`. No in-app toggle: the phone already
/// knows, and most phones here are not set to 24-hour.
///
/// The whole expression is bidi-ISOLATED, so `8:00 م` cannot reorder inside a
/// sentence — the marker and the digits are opposite directions in one run.
///
/// Falls back to the raw string on anything unparseable, for the same reason
/// [dayAndMonth] does: a machine time on screen is bad, a screen that throws
/// because the server sent something unexpected is worse.
String timeOfDay(String wallClock, BuildContext context) {
  final List<String> parts = wallClock.split(':');
  if (parts.length < 2) return wallClock;
  final int? h = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return wallClock;

  final bool ar = Localizations.localeOf(context).languageCode == 'ar';
  // `ar`, never `ar_EG` — see above. `en` for the Latin locale.
  final String locale = ar ? 'ar' : 'en';
  final bool use24 = MediaQuery.of(context).alwaysUse24HourFormat;

  // A wall clock is a time of day, not an instant. The date is arbitrary and
  // never rendered; only the hour and minute reach the formatter.
  final DateTime t = DateTime(2000, 1, 1, h, m);
  final String out = DateFormat(use24 ? 'Hm' : 'jm', locale).format(t);
  return isolate(out);
}

/// `2026-08-05` → `5 August` / `٥ أغسطس`… no: `5 أغسطس`. Latin digit, localised
/// month.
///
/// Falls back to the raw string on anything it cannot parse. A machine date on
/// screen is bad; a screen that throws because a server sent an unexpected
/// format is worse, and this is a label, not a booking parameter.
String dayAndMonth(String isoDate, BuildContext context) {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final parts = isoDate.split('-');
  final day = parts.length == 3 ? int.tryParse(parts[2]) : null;
  final month = parts.length == 3 ? int.tryParse(parts[1]) : null;

  if (day == null || month == null || month < 1 || month > 12) return isoDate;
  return '$day ${monthNames[ar ? 'ar' : 'en']![month - 1]}';
}

const Map<String, List<String>> monthNames = <String, List<String>>{
  'en': <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ],
  'ar': <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ],
};
