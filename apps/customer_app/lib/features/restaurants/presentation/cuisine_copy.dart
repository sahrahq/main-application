import '../../../localization/generated/app_localizations.dart';

/// Cuisine key → localised label.
///
/// FOUND BY LOOKING AT AN ARABIC GOLDEN. The meta line read
/// `Levantine · $$$ · Zamalek` on a fully Arabic screen, because `cuisines` is
/// a `String[]` of keys and the code was title-casing the key itself. Every
/// test passed: the string was exactly what the API sent, the layout mirrored
/// correctly, and nothing asserts that a word is in the right language.
///
/// Same shape as `amenityLabel`: an unknown key returns null and is SKIPPED,
/// because rendering `street_food` on a restaurant page is a leaked database
/// column, in English, on an Arabic screen.
String? cuisineLabel(String key, AppLocalizations l10n) => switch (key) {
      'levantine' => l10n.cuisineLevantine,
      'egyptian' => l10n.cuisineEgyptian,
      'mediterranean' => l10n.cuisineMediterranean,
      'lebanese' => l10n.cuisineLebanese,
      'japanese' => l10n.cuisineJapanese,
      'sushi' => l10n.cuisineSushi,
      'street_food' => l10n.cuisineStreetFood,
      'cafe' => l10n.cuisineCafe,
      _ => null,
    };
