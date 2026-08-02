import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import 'sahra_scales.dart';

/// Bilingual typography.
///
/// SAHRA is not "an English app that also does Arabic". The two scripts get
/// different families and different leading, because Arabic needs more room
/// between lines to stay legible — dots and diacritics sit below and above the
/// baseline where Latin has nothing.
///
///   Latin   — Poppins for UI, Newsreader (serif) for display and venue names
///   Arabic  — IBM Plex Sans Arabic for UI, Reem Kufi for display
///
/// Sizes are identical across both so a screen does not reflow when the user
/// switches language mid-session.
class SahraTypography {
  const SahraTypography._();

  /// Headline weight is capped at 600 (DESIGN-RULES.md) — SAHRA never shouts.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;

  static const _latinUi = SahraTokens.fontLatin;
  static const _latinDisplay = SahraTokens.fontDisplay;
  static const _arabicUi = SahraTokens.fontArabic;
  static const _arabicDisplay = SahraTokens.fontArabicDisplay;

  static const double _latinLeading = SahraTypeScale.leadingNormal;
  static const double _arabicLeading = SahraTypeScale.leadingArabic;

  static TextTheme latin(Color body) => _build(
        body: body,
        ui: _latinUi,
        display: _latinDisplay,
        leading: _latinLeading,
      );

  /// Arabic.
  ///
  /// LEADING: `docs/design/guidelines/type-arabic.html` sets Arabic body at
  /// `line-height: 1.7`, and DESIGN-RULES.md is explicit that the HTML wins
  /// when it disagrees with prose. tokens.json had no 1.7, so the token was
  /// what was missing rather than the guideline being wrong: `leading-arabic`
  /// was added to the JSON and this reads it. Arabic needs the extra room —
  /// dots and diacritics sit above and below the baseline where Latin has
  /// nothing.
  static TextTheme arabic(Color body) => _build(
        body: body,
        ui: _arabicUi,
        display: _arabicDisplay,
        leading: _arabicLeading,
      );

  static TextTheme forLocale(Locale locale, Color body) =>
      locale.languageCode == 'ar' ? arabic(body) : latin(body);

  static TextTheme _build({
    required Color body,
    required SahraFontStack ui,
    required SahraFontStack display,
    required double leading,
  }) {
    TextStyle s(
      double size,
      FontWeight weight, {
      SahraFontStack? family,
      double? height,
      double? letterSpacing,
    }) =>
        TextStyle(
          fontFamily: (family ?? ui).family,
          fontFamilyFallback: (family ?? ui).fallback,
          fontSize: size,
          fontWeight: weight,
          // Reem Kufi and Newsreader are VARIABLE fonts, and Flutter does not
          // drive the `wght` axis from the pubspec `weight:` key — it only
          // selects a file. Without this the display faces render at their
          // default weight regardless of what fontWeight says. Harmless on the
          // static families, which ignore it.
          fontVariations: <FontVariation>[FontVariation('wght', weight.value.toDouble())],
          height: height ?? leading,
          letterSpacing: letterSpacing,
          color: body,
        );

    // ALL FIFTEEN MATERIAL SLOTS ARE FILLED, and the five that were not are
    // why this note exists.
    //
    // `displayMedium`, `displaySmall`, `titleLarge`, `titleMedium` and
    // `titleSmall` were left null. Reaching for one of them did not fail and
    // did not even read as empty: `ThemeData` fills an unset slot from its own
    // typography, which inherits `ThemeData.fontFamily` — POPPINS, the Latin
    // UI face, which has NO ARABIC GLYPHS. So the first screen to write
    // `textTheme.titleMedium` rendered every venue name in the bookings list
    // as a row of empty boxes, in Arabic only.
    //
    // Every test passed. `flutter analyze` sees a valid nullable getter; a
    // null-check from outside reads back the substituted style and finds it
    // present; the contrast and tap-target guidelines do not look at glyph
    // shapes. It was found by looking at a golden.
    //
    // Nothing below is a new value. Each of the five gets an existing token
    // size and one of the two existing families — the fix is a mapping, not a
    // new type scale — and `typography_arabic_coverage_test.dart` asserts the
    // resolved family of all fifteen by name.
    return TextTheme(
      // Display and headlines use the serif face — Newsreader in Latin,
      // Reem Kufi in Arabic — per DESIGN-RULES.md.
      displayLarge: s(
        SahraTypeScale.display,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      displayMedium: s(
        SahraTypeScale.h1,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      displaySmall: s(
        SahraTypeScale.h2,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      headlineLarge: s(
        SahraTypeScale.h1,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      headlineMedium: s(
        SahraTypeScale.h2,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      headlineSmall: s(SahraTypeScale.h3, semibold, height: SahraTypeScale.leadingTight),

      // Titles are the display face at body sizes — which is exactly what the
      // references draw: `MyBookingsScreen.jsx` sets each card's venue name in
      // `font-display` / `font-arabic-display` at 17px, between text-h3 (18)
      // and text-body-l (16). 16 is the token that exists.
      titleLarge: s(
        SahraTypeScale.h3,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      titleMedium: s(
        SahraTypeScale.bodyL,
        semibold,
        family: display,
        height: SahraTypeScale.leadingTight,
      ),
      // Small titles stay in the UI face. Below body size the serif's
      // distinguishing features stop being legible and it just reads as a
      // slightly wrong body style.
      titleSmall: s(SahraTypeScale.bodyM, semibold, height: SahraTypeScale.leadingTight),

      bodyLarge: s(SahraTypeScale.bodyL, regular),
      bodyMedium: s(SahraTypeScale.bodyM, regular),
      bodySmall: s(SahraTypeScale.bodyS, regular),

      labelLarge: s(SahraTypeScale.bodyM, medium, height: SahraTypeScale.leadingTight),
      labelMedium: s(SahraTypeScale.caption, medium, height: SahraTypeScale.leadingTight),

      // Overline is the one uppercase style in the product (DESIGN-RULES.md:
      // "UPPERCASE only for overlines/micro-labels"), tracked out by .14em.
      labelSmall: s(
        SahraTypeScale.overline,
        semibold,
        height: SahraTypeScale.leadingTight,
        letterSpacing: SahraTypeScale.overlineTracking(SahraTypeScale.overline),
      ),
    );
  }

  /// Prices, ratings and times.
  ///
  /// DESIGN-RULES.md: "Numerals stay Latin for prices/ratings." An Arabic
  /// screen showing ٤٫٨ where the rest of the market shows 4.8 reads as a
  /// different number to a Cairo diner scanning quickly, so figures keep the
  /// Latin face and Latin digits even inside Arabic copy. Callers must also
  /// format with Latin digits — this only fixes the glyphs.
  static TextStyle numeric(TextStyle base) => base.copyWith(
        fontFamily: SahraTokens.fontLatin.family,
        fontFamilyFallback: SahraTokens.fontLatin.fallback,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
