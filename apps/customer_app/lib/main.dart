import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import 'localization/generated/app_localizations.dart';
import 'routes/routes.dart';
import 'shared/providers/app_providers.dart';

void main() => runApp(const ProviderScope(child: SahraApp()));

class SahraApp extends StatelessWidget {
  const SahraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,

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
          child: LocaleSync(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
