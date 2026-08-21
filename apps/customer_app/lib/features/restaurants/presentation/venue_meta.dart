/// The meta line, exactly as DESIGN-RULES.md specifies it:
/// `★ 4.8 (312) · Levantine · $$$`.
///
/// Composed here rather than in each screen, so Search and Venue Detail cannot
/// disagree about the separator or the order — which is precisely the kind of
/// inconsistency nobody reports and everybody notices.
library;

import 'package:flutter/widgets.dart';
import '../../reservations/presentation/reservation_copy.dart';

import '../../../localization/generated/app_localizations.dart';
import '../domain/venue.dart';
import 'cuisine_copy.dart';

/// Everything after the stars.
///
/// The cuisine is LOOKED UP, not title-cased. Title-casing the API's key put
/// `Levantine` on a fully Arabic screen — found by looking at a golden, not by
/// any assertion, because the string was exactly what the server sent.
String venueMeta(
  AppLocalizations l10n,
  List<String> cuisines,
  int? priceBand,
  String? neighborhood,
) {
  final cuisine = cuisines.isEmpty ? null : cuisineLabel(cuisines.first, l10n);

  final parts = <String>[
    if (cuisine != null) cuisine,
    if (priceBand != null) priceSymbols(priceBand),
    // NOT TRANSLATED, and it cannot be from here: `neighborhood` is a single
    // `VARCHAR(80)` column in the schema, so the database holds one spelling
    // and it is the Latin one. CLAUDE.md rule 5 says bilingual BY COLUMN
    // (`name_en`/`name_ar`), which this column predates. Raised as a schema
    // finding rather than papered over with a client-side lookup — a hardcoded
    // list of Cairo neighbourhoods in the app would drift from the venues the
    // owners actually enter.
    if (neighborhood != null && neighborhood.isNotEmpty) neighborhood,
  ];
  return parts.join(' · ');
}

/// 1–4 → `$`–`$$$$`.
///
/// DESIGN-RULES.md writes the price band as dollar signs in both locales,
/// alongside "numerals stay Latin" — a price BAND is a market convention, not
/// a currency. Actual money is EGP and formatted separately.
String priceSymbols(int band) => r'$' * band.clamp(1, 4);

/// One sentence for a screen reader, instead of a name, two numbers, a badge
/// and a heart announced in layout order.
///
/// `labeledTapTargetGuideline` would accept the word "button" here, so this is
/// the part no test can check — it is written for a human listening, and only
/// a manual TalkBack pass can confirm it reads well (ENGINEERING-STANDARDS §4,
/// a launch blocker).
String venueSemanticLabel(BuildContext context, VenueSummary venue) {
  final l10n = AppLocalizations.of(context);
  final next = venue.nextAvailable.isEmpty
      ? ''
      : ', ${l10n.searchNextAvailable(timeOfDay(venue.nextAvailable.first, context))}';
  return '${venue.name}, '
      '${venue.rating} (${venue.ratingCount}), '
      '${venueMeta(l10n, venue.cuisines, venue.priceBand, venue.neighborhood)}$next';
}
