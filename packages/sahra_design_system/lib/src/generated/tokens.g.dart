// GENERATED — DO NOT EDIT BY HAND.
//
// Source: docs/design/tokens.json (74 light + 7 night)
// Regenerate: dart run tool/generate_tokens.dart
//
// Editing this file instead of the JSON is the one way to make the design
// tokens and the app disagree. tokens_test.dart fails if you do.
import 'package:flutter/painting.dart';

/// A CSS font stack, split for Flutter.
class SahraFontStack {
  const SahraFontStack(this.family, this.fallback);
  final String family;
  final List<String> fallback;
}

/// Every token under `root` in tokens.json.
class SahraTokens {
  const SahraTokens._();

  /// `terracotta`: `#C64A2B`
  static const Color terracotta = Color(0xFFC64A2B);
  /// `terracotta-dark`: `#A5391F`
  static const Color terracottaDark = Color(0xFFA5391F);
  /// `terracotta-light`: `#DD7053`
  static const Color terracottaLight = Color(0xFFDD7053);
  /// `terracotta-tint`: `#F7E2DA`
  static const Color terracottaTint = Color(0xFFF7E2DA);
  /// `gold`: `#E0A96D`
  static const Color gold = Color(0xFFE0A96D);
  /// `gold-dark`: `#C48A4B`
  static const Color goldDark = Color(0xFFC48A4B);
  /// `gold-light`: `#EFC697`
  static const Color goldLight = Color(0xFFEFC697);
  /// `gold-tint`: `#FBEEDD`
  static const Color goldTint = Color(0xFFFBEEDD);
  /// `cream`: `#FDFBF7`
  static const Color cream = Color(0xFFFDFBF7);
  /// `cream-dim`: `#F3ECE0`
  static const Color creamDim = Color(0xFFF3ECE0);
  /// `cream-card`: `#FBF6EE`
  static const Color creamCard = Color(0xFFFBF6EE);
  /// `ink`: `#121212`
  static const Color ink = Color(0xFF121212);
  /// `ink-soft`: `#4A4640`
  static const Color inkSoft = Color(0xFF4A4640);
  /// `ink-faint`: `#8A8479`
  static const Color inkFaint = Color(0xFF8A8479);
  /// `border`: `#E4D9C7`
  static const Color border = Color(0xFFE4D9C7);
  /// `success`: `#4C7A4F`
  static const Color success = Color(0xFF4C7A4F);
  /// `warning`: `#C48A4B`
  static const Color warning = Color(0xFFC48A4B);
  /// `error`: `#B3412A`
  static const Color error = Color(0xFFB3412A);
  /// `night`: `#1A1310`
  static const Color night = Color(0xFF1A1310);
  /// `night-raised`: `#251B15`
  static const Color nightRaised = Color(0xFF251B15);
  /// `night-overlay`: `#31251C`
  static const Color nightOverlay = Color(0xFF31251C);
  /// `night-border`: `#413024`
  static const Color nightBorder = Color(0xFF413024);
  /// `night-text`: `#FDFBF7`
  static const Color nightText = Color(0xFFFDFBF7);
  /// `night-text-soft`: `#DCC9BA`
  static const Color nightTextSoft = Color(0xFFDCC9BA);
  /// `night-text-faint`: `#A38D7C`
  static const Color nightTextFaint = Color(0xFFA38D7C);
  /// `surface-page`: `#FBF7F0`
  static const Color surfacePage = Color(0xFFFBF7F0);
  /// `surface-card` → `var(--cream-card)`
  static const Color surfaceCard = creamCard;
  /// `surface-sunken` → `var(--cream-dim)`
  static const Color surfaceSunken = creamDim;
  /// `text-body` → `var(--ink)`
  static const Color textBody = ink;
  /// `text-soft` → `var(--ink-soft)`
  static const Color textSoft = inkSoft;
  /// `text-faint` → `var(--ink-faint)`
  static const Color textFaint = inkFaint;
  /// `accent` → `var(--terracotta)`
  static const Color accent = terracotta;
  /// `accent-hover` → `var(--terracotta-dark)`
  static const Color accentHover = terracottaDark;
  /// `accent-contrast`: `#FFFFFF`
  static const Color accentContrast = Color(0xFFFFFFFF);
  /// `premium` → `var(--gold)`
  static const Color premium = gold;
  /// `line` → `var(--border)`
  static const Color line = border;
  /// `font-latin`: `'Poppins',-apple-system,BlinkMacSystemFont,sans-serif`
  static const SahraFontStack fontLatin = SahraFontStack('Poppins', <String>['-apple-system', 'BlinkMacSystemFont', 'sans-serif']);
  /// `font-arabic`: `'IBM Plex Sans Arabic','Poppins',sans-serif`
  static const SahraFontStack fontArabic = SahraFontStack('IBM Plex Sans Arabic', <String>['Poppins', 'sans-serif']);
  /// `font-arabic-display`: `'Reem Kufi','IBM Plex Sans Arabic',sans-serif`
  static const SahraFontStack fontArabicDisplay = SahraFontStack('Reem Kufi', <String>['IBM Plex Sans Arabic', 'sans-serif']);
  /// `font-display`: `'Newsreader',Georgia,serif`
  static const SahraFontStack fontDisplay = SahraFontStack('Newsreader', <String>['Georgia', 'serif']);
  /// `font-mono`: `'SFMono-Regular',Consolas,Menlo,monospace`
  static const SahraFontStack fontMono = SahraFontStack('SFMono-Regular', <String>['Consolas', 'Menlo', 'monospace']);
  /// `text-display`: `40px`
  static const double textDisplay = 40.0;
  /// `text-h1`: `32px`
  static const double textH1 = 32.0;
  /// `text-h2`: `24px`
  static const double textH2 = 24.0;
  /// `text-h3`: `18px`
  static const double textH3 = 18.0;
  /// `text-body-l`: `16px`
  static const double textBodyL = 16.0;
  /// `text-body-m`: `14px`
  static const double textBodyM = 14.0;
  /// `text-body-s`: `13px`
  static const double textBodyS = 13.0;
  /// `text-caption`: `12px`
  static const double textCaption = 12.0;
  /// `text-overline`: `11px`
  static const double textOverline = 11.0;
  /// `leading-tight`: `1.15`
  static const double leadingTight = 1.15;
  /// `leading-normal`: `1.5`
  static const double leadingNormal = 1.5;
  /// `leading-loose`: `1.65`
  static const double leadingLoose = 1.65;
  /// `leading-arabic`: `1.7`
  static const double leadingArabic = 1.7;
  /// `tracking-overline`: `.14em`
  static const double trackingOverline = 0.14;
  /// `space-1`: `4px`
  static const double space1 = 4.0;
  /// `space-2`: `8px`
  static const double space2 = 8.0;
  /// `space-3`: `12px`
  static const double space3 = 12.0;
  /// `space-4`: `16px`
  static const double space4 = 16.0;
  /// `space-5`: `20px`
  static const double space5 = 20.0;
  /// `space-6`: `24px`
  static const double space6 = 24.0;
  /// `space-8`: `32px`
  static const double space8 = 32.0;
  /// `space-10`: `40px`
  static const double space10 = 40.0;
  /// `space-12`: `48px`
  static const double space12 = 48.0;
  /// `space-16`: `64px`
  static const double space16 = 64.0;
  /// `space-24`: `96px`
  static const double space24 = 96.0;
  /// `radius-sm`: `8px`
  static const double radiusSm = 8.0;
  /// `radius-md`: `12px`
  static const double radiusMd = 12.0;
  /// `radius-lg`: `16px`
  static const double radiusLg = 16.0;
  /// `radius-xl`: `24px`
  static const double radiusXl = 24.0;
  /// `radius-pill`: `999px`
  static const double radiusPill = 999.0;
  /// `shadow-1`: `0 1px 2px rgba(120,72,40,.07),0 1px 1px rgba(120,72,40,.05)`
  static const List<BoxShadow> shadow1 = <BoxShadow>[
      BoxShadow(color: Color(0x12784828), offset: Offset(0.0, 1.0), blurRadius: 2.0, spreadRadius: 0.0),
      BoxShadow(color: Color(0x0D784828), offset: Offset(0.0, 1.0), blurRadius: 1.0, spreadRadius: 0.0),
    ];
  /// `shadow-2`: `0 4px 14px rgba(120,72,40,.10),0 2px 4px rgba(120,72,40,.06)`
  static const List<BoxShadow> shadow2 = <BoxShadow>[
      BoxShadow(color: Color(0x1A784828), offset: Offset(0.0, 4.0), blurRadius: 14.0, spreadRadius: 0.0),
      BoxShadow(color: Color(0x0F784828), offset: Offset(0.0, 2.0), blurRadius: 4.0, spreadRadius: 0.0),
    ];
  /// `shadow-3`: `0 14px 34px rgba(120,72,40,.14),0 4px 8px rgba(120,72,40,.07)`
  static const List<BoxShadow> shadow3 = <BoxShadow>[
      BoxShadow(color: Color(0x24784828), offset: Offset(0.0, 14.0), blurRadius: 34.0, spreadRadius: 0.0),
      BoxShadow(color: Color(0x12784828), offset: Offset(0.0, 4.0), blurRadius: 8.0, spreadRadius: 0.0),
    ];

  /// Keyed by the token name exactly as it appears in tokens.json.
  /// The coverage test walks this, so a token cannot go unimplemented.
  static const Map<String, Object> byToken = <String, Object>{
    'terracotta': terracotta,
    'terracotta-dark': terracottaDark,
    'terracotta-light': terracottaLight,
    'terracotta-tint': terracottaTint,
    'gold': gold,
    'gold-dark': goldDark,
    'gold-light': goldLight,
    'gold-tint': goldTint,
    'cream': cream,
    'cream-dim': creamDim,
    'cream-card': creamCard,
    'ink': ink,
    'ink-soft': inkSoft,
    'ink-faint': inkFaint,
    'border': border,
    'success': success,
    'warning': warning,
    'error': error,
    'night': night,
    'night-raised': nightRaised,
    'night-overlay': nightOverlay,
    'night-border': nightBorder,
    'night-text': nightText,
    'night-text-soft': nightTextSoft,
    'night-text-faint': nightTextFaint,
    'surface-page': surfacePage,
    'surface-card': surfaceCard,
    'surface-sunken': surfaceSunken,
    'text-body': textBody,
    'text-soft': textSoft,
    'text-faint': textFaint,
    'accent': accent,
    'accent-hover': accentHover,
    'accent-contrast': accentContrast,
    'premium': premium,
    'line': line,
    'font-latin': fontLatin,
    'font-arabic': fontArabic,
    'font-arabic-display': fontArabicDisplay,
    'font-display': fontDisplay,
    'font-mono': fontMono,
    'text-display': textDisplay,
    'text-h1': textH1,
    'text-h2': textH2,
    'text-h3': textH3,
    'text-body-l': textBodyL,
    'text-body-m': textBodyM,
    'text-body-s': textBodyS,
    'text-caption': textCaption,
    'text-overline': textOverline,
    'leading-tight': leadingTight,
    'leading-normal': leadingNormal,
    'leading-loose': leadingLoose,
    'leading-arabic': leadingArabic,
    'tracking-overline': trackingOverline,
    'space-1': space1,
    'space-2': space2,
    'space-3': space3,
    'space-4': space4,
    'space-5': space5,
    'space-6': space6,
    'space-8': space8,
    'space-10': space10,
    'space-12': space12,
    'space-16': space16,
    'space-24': space24,
    'radius-sm': radiusSm,
    'radius-md': radiusMd,
    'radius-lg': radiusLg,
    'radius-xl': radiusXl,
    'radius-pill': radiusPill,
    'shadow-1': shadow1,
    'shadow-2': shadow2,
    'shadow-3': shadow3,
  };
}

/// The `themeNight` overrides. Dark mode changes ONLY these 7
/// tokens; everything else — terracotta above all — is shared, which is
/// why the brand does not shift between themes (DESIGN-RULES.md).
class SahraNightTokens {
  const SahraNightTokens._();

  /// `surface-page` → `var(--night)`
  static const Color surfacePage = SahraTokens.night;
  /// `surface-card` → `var(--night-raised)`
  static const Color surfaceCard = SahraTokens.nightRaised;
  /// `surface-sunken` → `var(--night-overlay)`
  static const Color surfaceSunken = SahraTokens.nightOverlay;
  /// `text-body` → `var(--night-text)`
  static const Color textBody = SahraTokens.nightText;
  /// `text-soft` → `var(--night-text-soft)`
  static const Color textSoft = SahraTokens.nightTextSoft;
  /// `text-faint` → `var(--night-text-faint)`
  static const Color textFaint = SahraTokens.nightTextFaint;
  /// `line` → `var(--night-border)`
  static const Color line = SahraTokens.nightBorder;

  static const Map<String, Object> byToken = <String, Object>{
    'surface-page': surfacePage,
    'surface-card': surfaceCard,
    'surface-sunken': surfaceSunken,
    'text-body': textBody,
    'text-soft': textSoft,
    'text-faint': textFaint,
    'line': line,
  };
}
