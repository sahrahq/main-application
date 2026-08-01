import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../generated/tokens.g.dart';
import 'sahra_scales.dart';
import 'sahra_semantics.dart';
import 'sahra_typography.dart';

/// The SAHRA themes.
///
/// Light and dark are built from the same call — dark is not a retrofit, it is
/// the seven `themeNight` token overrides applied to the same semantic names.
/// Building one without the other is how a codebase ends up with a dark mode
/// that is a rewrite rather than a value swap.
class SahraTheme {
  const SahraTheme._();

  /// Arabic FIRST. RTL is SAHRA's default direction, not a special case: the
  /// app is for Egypt, and `supportedLocales.first` is what Flutter falls back
  /// to when the device locale matches nothing. An app that defaults to
  /// English and "supports" Arabic is a different product.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Pass these to `MaterialApp`. They are not optional decoration: without the
  /// GLOBAL delegates, `DefaultWidgetsLocalizations` reports left-to-right for
  /// every locale, so an Arabic app renders LTR and looks merely "translated"
  /// rather than Arabic. Shipped from here so no app has to remember.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static ThemeData light({Locale locale = const Locale('ar')}) =>
      _build(SahraSemantics.light(), locale);

  static ThemeData dark({Locale locale = const Locale('ar')}) =>
      _build(SahraSemantics.dark(), locale);

  static ThemeData _build(SahraSemantics s, Locale locale) {
    final text = SahraTypography.forLocale(locale, s.textBody);
    final isDark = s.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      extensions: <ThemeExtension<dynamic>>[s],

      // Cream, never pure white (DESIGN-RULES.md). On dark, the warm
      // brown-black #1A1310 — never a cool charcoal.
      scaffoldBackgroundColor: s.surfacePage,
      canvasColor: s.surfacePage,
      dividerColor: s.line,
      textTheme: text,
      primaryTextTheme: text,
      fontFamily: SahraTokens.fontLatin.family,

      colorScheme: ColorScheme(
        brightness: s.brightness,
        primary: s.accent,
        onPrimary: s.accentContrast,
        // Gold is accent/celebration only — never a second primary
        // (DESIGN-RULES.md). It is exposed as `premium`, not as `secondary`.
        secondary: s.accent,
        onSecondary: s.accentContrast,
        error: s.error,
        onError: s.accentContrast,
        surface: s.surfaceCard,
        onSurface: s.textBody,
        surfaceContainerLowest: s.surfacePage,
        surfaceContainerLow: s.surfaceCard,
        surfaceContainer: s.surfaceSunken,
        outline: s.line,
        outlineVariant: s.line,
      ),

      // Every tap target clears 44px (DESIGN-RULES.md / CLAUDE.md rule 4).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,

      // On dark, elevation is a lighter surface, not a shadow.
      cardTheme: CardThemeData(
        color: s.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.lg),
          side: BorderSide(color: s.line),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: s.surfacePage,
        foregroundColor: s.textBody,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 1,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: s.accent,
          foregroundColor: s.accentContrast,
          disabledBackgroundColor: s.surfaceSunken,
          disabledForegroundColor: s.textFaint,
          elevation: 0,
          minimumSize: const Size(SahraRules.minTouchTarget, SahraRules.minTouchTarget),
          padding: SahraSpace.symmetric(
            horizontal: SahraSpace.s6,
            vertical: SahraSpace.s3,
          ),
          shape: RoundedRectangleBorder(borderRadius: SahraRadius.allOf(SahraRadius.md)),
          textStyle: text.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.textBody,
          minimumSize: const Size(SahraRules.minTouchTarget, SahraRules.minTouchTarget),
          padding: SahraSpace.symmetric(
            horizontal: SahraSpace.s6,
            vertical: SahraSpace.s3,
          ),
          side: BorderSide(color: s.line),
          shape: RoundedRectangleBorder(borderRadius: SahraRadius.allOf(SahraRadius.md)),
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: s.accent,
          minimumSize: const Size(SahraRules.minTouchTarget, SahraRules.minTouchTarget),
          textStyle: text.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceSunken,
        contentPadding: SahraSpace.symmetric(
          horizontal: SahraSpace.s4,
          vertical: SahraSpace.s3,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: s.textFaint),
        border: OutlineInputBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.md),
          borderSide: BorderSide(color: s.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.md),
          borderSide: BorderSide(color: s.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.md),
          borderSide: BorderSide(color: s.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.md),
          borderSide: BorderSide(color: s.error),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: s.surfaceSunken,
        selectedColor: s.accent,
        side: BorderSide(color: s.line),
        labelStyle: text.labelMedium ?? const TextStyle(),
        padding: SahraSpace.symmetric(
          horizontal: SahraSpace.s3,
          vertical: SahraSpace.s2,
        ),
        shape: RoundedRectangleBorder(borderRadius: SahraRadius.allOf(SahraRadius.pill)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: s.surfaceCard,
        selectedItemColor: s.accent,
        unselectedItemColor: s.textFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dividerTheme: DividerThemeData(color: s.line, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.accent,
        linearTrackColor: s.surfaceSunken,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.surfaceSunken,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: SahraRadius.allOf(SahraRadius.md)),
      ),
    );
  }
}
