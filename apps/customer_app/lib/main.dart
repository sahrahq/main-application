import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import 'config/env/env.dart';
import 'localization/generated/app_localizations.dart';
import 'routes/routes.dart';
import 'shared/providers/app_providers.dart';
import 'shared/widgets/device_frame.dart';

void main() => runApp(const ProviderScope(child: SahraApp()));

class SahraApp extends StatelessWidget {
  const SahraApp({this.localeOverride, super.key});

  /// FOR THE JOURNEY WALK-THROUGH ONLY. Production passes nothing.
  ///
  /// `forcedLocale()` reads a `--dart-define`, which is fixed for a whole
  /// process and therefore cannot give one test run both languages. The
  /// end-of-batch walk-through has to produce Arabic AND English pictures of
  /// the same journey (CLAUDE.md), so the language has to be a parameter
  /// somewhere.
  ///
  /// It lives here rather than in a test-only copy of this widget because the
  /// last time a test reassembled the app it got a different app — it skipped
  /// `LocaleSync` and rendered Arabic venue names in an English run. One
  /// optional argument is a smaller cost than a second app that drifts.
  final Locale? localeOverride;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,

      // Null in a real build — the device decides. `--dart-define=FORCE_LOCALE=ar`
      // pins it, so Arabic can be reviewed without changing an operating
      // system's language. Half of this product is Arabic; making it awkward
      // to look at is how it stops being looked at.
      locale: localeOverride ?? forcedLocale(),

      // ARABIC IS FIRST, and that is not alphabetical ordering.
      // `supportedLocales.first` is what Flutter falls back to when the device
      // locale matches nothing, so an app that lists English first defaults an
      // unknown device to English. SAHRA is for Egypt.
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...SahraTheme.localizationsDelegates,
      ],

      // Both themes, always. The system decides; there is no in-app toggle
      // because a diner's phone already knows whether it is night.
      theme: SahraTheme.light(),
      darkTheme: SahraTheme.dark(),

      // The theme is built per locale (the Arabic and Latin type stacks are
      // different families), so it has to be rebuilt once the locale is known
      // — `MaterialApp.theme` is resolved before `Localizations` exists.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: dark ? SahraTheme.dark(locale: locale) : SahraTheme.light(locale: locale),
          // The frame is OUTSIDE LocaleSync and inside Theme: it is chrome
          // around the app, not part of it, and it is off in every real build.
          child: SahraDeviceFrame(
            child: LocaleSync(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
