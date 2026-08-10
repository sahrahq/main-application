import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';

/// The theme-varying half of the design tokens, reachable from any widget as
/// `Theme.of(context).extension<SahraSemantics>()!`.
///
/// Dark mode overrides TEN tokens (`themeNight` in tokens.json) — the seven
/// surface/text values plus success/warning/error, which need per-theme values
/// to stay legible. Everything else — terracotta above all — is shared, which
/// is why the brand does not shift between themes (DESIGN-RULES.md:
/// "Terracotta #C64A2B is used unmodified in both themes").
///
/// Widgets reference the SEMANTIC names here (`surfaceCard`, `textBody`,
/// `line`), never the brand values (`cream-card`, `ink`, `border`). That is
/// what makes dark mode free: the semantic name is the same in both themes and
/// only its value moves.
@immutable
class SahraSemantics extends ThemeExtension<SahraSemantics> {
  const SahraSemantics({
    required this.surfacePage,
    required this.surfaceCard,
    required this.surfaceSunken,
    required this.textBody,
    required this.textSoft,
    required this.textFaint,
    required this.accent,
    required this.accentHover,
    required this.accentContrast,
    required this.accentOnSurface,
    required this.premium,
    required this.line,
    required this.success,
    required this.warning,
    required this.error,
    required this.successOnTint,
    required this.warningOnTint,
    required this.errorOnTint,
    required this.brightness,
  });

  /// Light: every semantic token as tokens.json defines it under `root`.
  factory SahraSemantics.light() => const SahraSemantics(
        surfacePage: SahraTokens.surfacePage,
        surfaceCard: SahraTokens.surfaceCard,
        surfaceSunken: SahraTokens.surfaceSunken,
        textBody: SahraTokens.textBody,
        textSoft: SahraTokens.textSoft,
        textFaint: SahraTokens.textFaint,
        accent: SahraTokens.accent,
        accentHover: SahraTokens.accentHover,
        accentContrast: SahraTokens.accentContrast,
        // Terracotta itself measures 4.45:1 on cream — just under WCAG AA.
        accentOnSurface: SahraTokens.terracottaDark,
        premium: SahraTokens.premium,
        line: SahraTokens.line,
        success: SahraTokens.success,
        warning: SahraTokens.warning,
        error: SahraTokens.error,
        successOnTint: SahraTokens.successOnTint,
        warningOnTint: SahraTokens.warningOnTint,
        errorOnTint: SahraTokens.errorOnTint,
        brightness: Brightness.light,
      );

  /// Dark: the same semantics, with the seven `themeNight` values swapped in.
  /// Note what does NOT change — accent, premium, success/warning/error.
  factory SahraSemantics.dark() => const SahraSemantics(
        surfacePage: SahraNightTokens.surfacePage,
        surfaceCard: SahraNightTokens.surfaceCard,
        surfaceSunken: SahraNightTokens.surfaceSunken,
        textBody: SahraNightTokens.textBody,
        textSoft: SahraNightTokens.textSoft,
        textFaint: SahraNightTokens.textFaint,
        accent: SahraTokens.accent,
        accentHover: SahraTokens.accentHover,
        accentContrast: SahraTokens.accentContrast,
        // …and 3.86:1 on the night surface. Lighter, not darker, on dark.
        accentOnSurface: SahraTokens.terracottaLight,
        premium: SahraTokens.premium,
        line: SahraNightTokens.line,
        // success and error are tuned per theme: the light values measured
        // 3.67 and 3.24 against the night surfaces. warning is the reverse —
        // gold-dark reads on night but not on cream.
        success: SahraNightTokens.success,
        warning: SahraNightTokens.warning,
        error: SahraNightTokens.error,
        successOnTint: SahraNightTokens.successOnTint,
        warningOnTint: SahraNightTokens.warningOnTint,
        errorOnTint: SahraNightTokens.errorOnTint,
        brightness: Brightness.dark,
      );

  final Color surfacePage;
  final Color surfaceCard;
  final Color surfaceSunken;
  final Color textBody;
  final Color textSoft;
  final Color textFaint;
  final Color accent;
  final Color accentHover;
  final Color accentContrast;

  /// Terracotta as READABLE TEXT on a page or card.
  ///
  /// [accent] is the brand fill and is correct behind white (4.76:1). As text
  /// it is not: #C64A2B measures 4.45:1 on cream and 3.86:1 on the night
  /// surface, both under WCAG AA's 4.5. Found by `textContrastGuideline` on
  /// the first component built, not by inspection.
  ///
  /// This follows the precedent DESIGN-RULES.md already sets for gold —
  /// "never body text on light (use gold-dark for text)" — applied to the
  /// accent, and it composes existing tokens rather than inventing a value.
  final Color accentOnSurface;
  final Color premium;
  final Color line;
  final Color success;
  final Color warning;
  final Color error;

  /// Text ON a tinted status badge, as opposed to on a plain surface.
  ///
  /// A badge wash is the status colour at [badgeTintAlpha] over the surface,
  /// which pulls the background toward the text and eats contrast. The
  /// surface-level `success`/`warning`/`error` cannot survive that — measured
  /// at every alpha down to 6%, they all fail — so the badge gets its own,
  /// darker (or on dark, lighter) value.
  ///
  /// Targeted at 6:1 rather than 4.5, deliberately. The original badge failure
  /// happened because a value sat exactly on the threshold and the tint ate
  /// the margin; rebuilding that trap in the fix would be the same mistake
  /// twice.
  final Color successOnTint;
  final Color warningOnTint;
  final Color errorOnTint;

  final Brightness brightness;

  /// The status-badge wash strength.
  ///
  /// The reference uses 12–18%, which is barely visible (1.2:1 against the
  /// surface) — a host scanning tonight's book would have to READ each badge
  /// rather than see it. 28% makes the hue legible at a glance while the
  /// on-tint values keep the label at 6:1.
  static const double badgeTintAlpha = 0.28;

  Color tintFor(Color status) => status.withValues(alpha: badgeTintAlpha);

  // ─────────────────────────────────────────────────────── the photo well ──
  //
  // `Photo.jsx` draws a photo — or, with no `src`, a warm dark gradient with a
  // mashrabiya lattice. It hardcodes `#4A392C → #2C2018`, `rgba(253,251,247,
  // .09)`, `rgba(253,251,247,.18)`, `rgba(20,12,8,.82)` and `#FDFBF7`; none of
  // those five are in tokens.json.
  //
  // They are COMPOSED from committed tokens here rather than copied as hex
  // literals into a widget — the precedent `accentOnSurface` set, and the only
  // option that does not break "colours come from tokens only". Two of them
  // land a shade off the reference: `#4A392C` becomes `night-border #413024`
  // and `#2C2018` becomes `night-overlay #31251C`, the nearest committed
  // members of the same warm-brown family. Flagged as cosmetic; adding two
  // tokens for one component's placeholder is how a scale stops being a scale.
  //
  // DELIBERATELY NOT THEME-VARYING. A photo well is dark on a cream page too —
  // that is what makes it read as a photo. So these are derived getters rather
  // than constructor fields: there is nothing for `lerp` to interpolate, and a
  // field nobody varies is a field somebody eventually varies by accident.

  Color get photoPlaceholderTop => SahraTokens.nightBorder;
  Color get photoPlaceholderBottom => SahraTokens.nightOverlay;

  /// The lattice over the placeholder — `rgba(253,251,247,0.09)`, exactly
  /// `night-text` at 9%.
  Color get photoLattice => SahraTokens.nightText.withValues(alpha: 0.09);

  /// The centred image glyph — the same cream at 18%.
  Color get photoCue => SahraTokens.nightText.withValues(alpha: 0.18);

  /// The bottom scrim that makes overlaid text readable at all.
  Color get photoScrim => SahraTokens.night.withValues(alpha: 0.82);
  Color get photoScrimClear => SahraTokens.night.withValues(alpha: 0.0);

  /// Text and icons drawn ON a photo, in both themes. `#FDFBF7` in the
  /// reference, which is `night-text` (and `cream`) exactly.
  ///
  /// `textContrastGuideline` CANNOT evaluate this — it skips text over an
  /// image — so the scrim above is the mechanism, and a human looking at the
  /// golden is the only check.
  Color get onPhoto => SahraTokens.nightText;

  /// A translucent well for an icon button floating over a photo
  /// (`VenueDetailScreen.jsx` IconBtn: `rgba(20,12,8,.5)`).
  Color get photoControlWell => SahraTokens.night.withValues(alpha: 0.5);

  /// EVERY token from tokens.json, resolved for this theme, keyed by its exact
  /// JSON name.
  ///
  /// This is what the coverage test walks. A token added to the JSON and not
  /// wired up here has no entry, and the test fails — which is the whole point:
  /// adding a token later cannot silently go unimplemented.
  Map<String, Object> get byToken => <String, Object>{
        ...SahraTokens.byToken,
        if (brightness == Brightness.dark) ...SahraNightTokens.byToken,
      };

  /// On dark, elevation is a LIGHTER SURFACE, not a shadow (DESIGN-RULES.md).
  /// A warm ink-tinted shadow over a brown-black page reads as a smudge.
  List<BoxShadow> shadow(List<BoxShadow> token) =>
      brightness == Brightness.dark ? const <BoxShadow>[] : token;

  @override
  SahraSemantics copyWith({
    Color? surfacePage,
    Color? surfaceCard,
    Color? surfaceSunken,
    Color? textBody,
    Color? textSoft,
    Color? textFaint,
    Color? accent,
    Color? accentHover,
    Color? accentContrast,
    Color? accentOnSurface,
    Color? premium,
    Color? line,
    Color? success,
    Color? warning,
    Color? error,
    Color? successOnTint,
    Color? warningOnTint,
    Color? errorOnTint,
    Brightness? brightness,
  }) =>
      SahraSemantics(
        surfacePage: surfacePage ?? this.surfacePage,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        textBody: textBody ?? this.textBody,
        textSoft: textSoft ?? this.textSoft,
        textFaint: textFaint ?? this.textFaint,
        accent: accent ?? this.accent,
        accentHover: accentHover ?? this.accentHover,
        accentContrast: accentContrast ?? this.accentContrast,
        accentOnSurface: accentOnSurface ?? this.accentOnSurface,
        premium: premium ?? this.premium,
        line: line ?? this.line,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        successOnTint: successOnTint ?? this.successOnTint,
        warningOnTint: warningOnTint ?? this.warningOnTint,
        errorOnTint: errorOnTint ?? this.errorOnTint,
        brightness: brightness ?? this.brightness,
      );

  @override
  SahraSemantics lerp(covariant SahraSemantics? other, double t) {
    if (other == null) return this;
    return SahraSemantics(
      surfacePage: Color.lerp(surfacePage, other.surfacePage, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentContrast: Color.lerp(accentContrast, other.accentContrast, t)!,
      accentOnSurface: Color.lerp(accentOnSurface, other.accentOnSurface, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      successOnTint: Color.lerp(successOnTint, other.successOnTint, t)!,
      warningOnTint: Color.lerp(warningOnTint, other.warningOnTint, t)!,
      errorOnTint: Color.lerp(errorOnTint, other.errorOnTint, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// `Theme.of(context).sahra` — the accessor widget code actually uses.
extension SahraThemeAccess on ThemeData {
  SahraSemantics get sahra => extension<SahraSemantics>()!;
}

extension SahraContextAccess on BuildContext {
  SahraSemantics get sahra => Theme.of(this).sahra;
}
