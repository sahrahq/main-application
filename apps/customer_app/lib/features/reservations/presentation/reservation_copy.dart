import 'package:flutter/widgets.dart';
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
    '${dayAndMonth(r.date, context)} · ${ltrRun(r.time)}';

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
