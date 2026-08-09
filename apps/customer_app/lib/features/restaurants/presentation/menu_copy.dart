import '../../../localization/generated/app_localizations.dart';

/// Dietary tag → localised label.
///
/// Same contract as `amenityLabel`: **null** for a key with no copy, and the
/// caller skips it rather than rendering `contains_pork` at a diner.
///
/// The difference is that this vocabulary IS closed — a CHECK constraint on
/// `menu_items.dietary_tags` refuses anything outside the list, precisely so a
/// typo fails at write time instead of disappearing here. So a null return
/// means the two lists have drifted, which `menu_copy_test.dart` fails on
/// rather than leaving to be noticed on a screen.
///
/// WE MARK THE EXCEPTION, NEVER THE DEFAULT. There is no `halal`: in Cairo it
/// is the default, and tagging it would imply the unmarked dishes are not.
String? dietaryLabel(String key, AppLocalizations l10n) => switch (key) {
      'vegetarian' => l10n.dietVegetarian,
      'vegan' => l10n.dietVegan,
      'gluten_free' => l10n.dietGlutenFree,
      'nut_free' => l10n.dietNutFree,
      'dairy_free' => l10n.dietDairyFree,
      'shellfish' => l10n.dietShellfish,
      'spicy' => l10n.dietSpicy,
      'contains_alcohol' => l10n.dietContainsAlcohol,
      'contains_pork' => l10n.dietContainsPork,
      _ => null,
    };

/// Every tag the database will accept, mirrored from the CHECK constraint in
/// `20260809010000_menus_and_reviews`.
///
/// Here so a test can assert the two agree. A vocabulary defined in two places
/// with no check between them is a vocabulary that has already drifted.
const List<String> kDietaryVocabulary = <String>[
  'vegetarian',
  'vegan',
  'gluten_free',
  'nut_free',
  'dairy_free',
  'shellfish',
  'spicy',
  'contains_alcohol',
  'contains_pork',
];

/// ISO 4217 code → what a diner reads.
///
/// `EGP` becomes «ج.م» in Arabic and stays `EGP` in English. Unknown codes
/// fall through to the CODE ITSELF rather than to null: a price with no
/// currency beside it is a number a diner will read as pounds, and being told
/// `SAR` is better than being told nothing.
String currencyLabel(String code, AppLocalizations l10n) => switch (code) {
      'EGP' => l10n.currencyEgp,
      _ => code,
    };
