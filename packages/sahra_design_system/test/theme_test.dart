// The theme itself: both brightnesses, both directions, from the start.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

Widget _host(ThemeData theme, Locale locale, Widget child) => MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: SahraTheme.supportedLocales,
      localizationsDelegates: SahraTheme.localizationsDelegates,
      home: child,
    );

void main() {
  group('both themes exist and are wired to the extension', () {
    for (final entry in {'light': SahraTheme.light(), 'dark': SahraTheme.dark()}.entries) {
      test('${entry.key}: the semantics extension is registered', () {
        expect(entry.value.extension<SahraSemantics>(), isNotNull);
      });
    }

    test('light and dark disagree on surface but agree on brand', () {
      final l = SahraTheme.light().sahra;
      final d = SahraTheme.dark().sahra;
      expect(l.surfacePage, isNot(d.surfacePage));
      expect(l.textBody, isNot(d.textBody));
      expect(l.accent, d.accent); // terracotta, unmodified
      expect(l.premium, d.premium); // gold, unmodified
    });

    test('light never uses pure white (DESIGN-RULES.md: cream, never white)', () {
      final l = SahraTheme.light().sahra;
      for (final c in <Color>[l.surfacePage, l.surfaceCard, l.surfaceSunken]) {
        expect(c, isNot(const Color(0xFFFFFFFF)));
      }
    });

    test('dark is warm brown-black, not cool charcoal', () {
      final page = SahraTheme.dark().sahra.surfacePage;
      // Warm means the red channel leads the blue one.
      expect((page.r * 255).round(), greaterThan((page.b * 255).round()));
    });

    test('scaffold and divider come from tokens, not Material defaults', () {
      final t = SahraTheme.light();
      expect(t.scaffoldBackgroundColor, t.sahra.surfacePage);
      expect(t.dividerColor, t.sahra.line);
    });
  });

  group('RTL is the default, not a special case', () {
    test('Arabic is the first supported locale, so it is the fallback', () {
      expect(SahraTheme.supportedLocales.first.languageCode, 'ar');
    });

    testWidgets('an Arabic locale lays out right-to-left', (tester) async {
      late TextDirection dir;
      await tester.pumpWidget(
        _host(
          SahraTheme.light(locale: const Locale('ar')),
          const Locale('ar'),
          Builder(
            builder: (context) {
              dir = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(dir, TextDirection.rtl);
    });

    testWidgets('EdgeInsetsDirectional resolves to the RIGHT edge in Arabic', (tester) async {
      // The property that matters: `start` means right in Arabic. A widget
      // written with EdgeInsets.only(left:) would put padding on the wrong
      // side here and never fail a test.
      final padding = SahraSpace.inset(start: SahraSpace.s4);
      expect(padding.resolve(TextDirection.rtl).right, SahraSpace.s4);
      expect(padding.resolve(TextDirection.rtl).left, 0);
      expect(padding.resolve(TextDirection.ltr).left, SahraSpace.s4);
    });
  });

  group('bilingual typography', () {
    test('Arabic and Latin use different families', () {
      final ar = SahraTypography.arabic(const Color(0xFF000000));
      final en = SahraTypography.latin(const Color(0xFF000000));
      expect(ar.bodyMedium!.fontFamily, isNot(en.bodyMedium!.fontFamily));
      expect(ar.bodyMedium!.fontFamily, SahraTokens.fontArabic.family);
      expect(en.bodyMedium!.fontFamily, SahraTokens.fontLatin.family);
    });

    test('Arabic display uses the Arabic display face, not the Latin serif', () {
      final ar = SahraTypography.arabic(const Color(0xFF000000));
      expect(ar.displayLarge!.fontFamily, SahraTokens.fontArabicDisplay.family);
      expect(ar.displayLarge!.fontFamily, isNot(SahraTokens.fontDisplay.family));
    });

    test('Arabic gets looser leading than Latin — the script needs the room', () {
      final ar = SahraTypography.arabic(const Color(0xFF000000));
      final en = SahraTypography.latin(const Color(0xFF000000));
      expect(ar.bodyMedium!.height, greaterThan(en.bodyMedium!.height!));
      expect(ar.bodyMedium!.height, SahraTypeScale.leadingArabic);
    });

    test('sizes are identical across scripts, so switching does not reflow', () {
      final ar = SahraTypography.arabic(const Color(0xFF000000));
      final en = SahraTypography.latin(const Color(0xFF000000));
      expect(ar.displayLarge!.fontSize, en.displayLarge!.fontSize);
      expect(ar.bodyMedium!.fontSize, en.bodyMedium!.fontSize);
      expect(ar.labelSmall!.fontSize, en.labelSmall!.fontSize);
    });

    test('headline weight never exceeds 600', () {
      final t = SahraTypography.latin(const Color(0xFF000000));
      for (final s in <TextStyle?>[
        t.displayLarge,
        t.headlineLarge,
        t.headlineMedium,
        t.headlineSmall,
      ]) {
        expect(s!.fontWeight!.value, lessThanOrEqualTo(FontWeight.w600.value));
      }
    });

    test('overline is tracked out by .14em', () {
      final t = SahraTypography.latin(const Color(0xFF000000));
      expect(
        t.labelSmall!.letterSpacing,
        SahraTokens.trackingOverline * SahraTypeScale.overline,
      );
    });

    test('numerals keep the Latin face even inside Arabic copy', () {
      final ar = SahraTypography.arabic(const Color(0xFF000000));
      final price = SahraTypography.numeric(ar.bodyLarge!);
      expect(price.fontFamily, SahraTokens.fontLatin.family);
    });
  });

  group('touch targets and motion', () {
    test('every button clears 44px', () {
      final t = SahraTheme.light();
      for (final size in <Size?>[
        t.elevatedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        t.outlinedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        t.textButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      ]) {
        expect(size!.height, greaterThanOrEqualTo(SahraRules.minTouchTarget));
      }
    });

    test('motion stays inside the 150-200ms band', () {
      expect(SahraRules.motionFast.inMilliseconds, greaterThanOrEqualTo(150));
      expect(SahraRules.motionNormal.inMilliseconds, lessThanOrEqualTo(200));
    });
  });

  group('elevation on dark is a lighter surface, not a shadow', () {
    test('shadow() returns nothing on dark and the token on light', () {
      expect(SahraSemantics.dark().shadow(SahraElevation.e2), isEmpty);
      expect(SahraSemantics.light().shadow(SahraElevation.e2), SahraElevation.e2);
    });
  });
}
