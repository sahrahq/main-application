import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';

/// The theme-varying half of the design tokens, reachable from any widget as
/// `Theme.of(context).extension<SahraSemantics>()!`.
///
/// Dark mode overrides exactly SEVEN tokens (`themeNight` in tokens.json).
/// Everything else — terracotta above all — is shared, which is why the brand
/// does not shift between themes (DESIGN-RULES.md: "Terracotta #C64A2B is used
/// unmodified in both themes").
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
        success: SahraTokens.success,
        warning: SahraTokens.warning,
        error: SahraTokens.error,
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
  final Brightness brightness;

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
