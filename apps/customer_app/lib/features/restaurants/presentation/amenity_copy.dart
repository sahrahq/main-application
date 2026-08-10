import '../../../localization/generated/app_localizations.dart';

/// Amenity key → localised label.
///
/// Returns **null** for a key with no copy, and the caller skips it. That is
/// deliberate: the alternative is rendering the raw key, and `nile_view`
/// appearing on a restaurant page is a leaked database column, in English, on
/// an Arabic screen.
///
/// `amenities` is a JSONB blob whose shape the schema does not pin
/// (search-doc.ts), so the set of keys is open. A closed lookup here means new
/// keys appear when somebody writes copy for them, not the moment somebody
/// types one into the owner console.
String? amenityLabel(String key, AppLocalizations l10n) => switch (key) {
      'outdoor' => l10n.amenityOutdoor,
      'shisha' => l10n.amenityShisha,
      'nile_view' => l10n.amenityNileView,
      'valet' => l10n.amenityValet,
      'family_section' => l10n.amenityFamilySection,
      'alcohol_free' => l10n.amenityAlcoholFree,
      _ => null,
    };
