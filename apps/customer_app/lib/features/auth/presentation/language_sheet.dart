import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/providers/locale_override.dart';

/// Choosing the language the app is read in.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE DEVICE IS A DEFAULT, NOT THE LAW — AMENDED 2026-08-09
/// ─────────────────────────────────────────────────────────────────────────
///
/// The original decision, recorded in `account_screen.dart`, was that the app
/// follows the device and an in-app switch would be "a second source of truth
/// for something the phone already knows".
///
/// **That reasoning was wrong about this market.** A large share of people in
/// Egypt run their phone in English and want to read Arabic, or the reverse —
/// the handset language is a signal about the handset, not about what somebody
/// wants to read over dinner. Overruled by the product owner as a market fact,
/// not a preference.
///
/// So the phone still supplies the DEFAULT, and this overrides it. The
/// distinction matters: a diner who never opens this screen gets the device
/// locale forever, exactly as before, and nothing about first launch changes.
///
/// THEME IS UNCHANGED and still follows the device. The original argument
/// holds there — light and dark are about the room you are in, which the phone
/// genuinely does know, and nobody wants a restaurant app to be the one thing
/// glowing white at 1am.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final override = ref.watch(localeOverrideProvider);

    return SingleChildScrollView(
      child: SahraPageWidth(
        child: Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: s.line,
                    borderRadius: BorderRadius.circular(SahraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: SahraSpace.s5),
              Text(
                l10n.accountLanguage,
                style: text.headlineSmall?.copyWith(color: s.textBody),
              ),
              const SizedBox(height: SahraSpace.s4),

              // EACH OPTION IS WRITTEN IN ITS OWN LANGUAGE. A diner who has the
              // app in a language they cannot read needs to find the other one,
              // and "Arabic" spelled in English is no help to them at all —
              // «العربية» is. This is the one list in the app that must not be
              // localised.
              _Option(
                label: l10n.languageFollowDevice,
                selected: override == null,
                onTap: () => _choose(context, ref, null),
              ),
              const _Option.divider(),
              _Option(
                // i18n-exempt: A LANGUAGE NAME IS NOT COPY. This is the one
                // list in the app that must never be translated: a diner who
                // has it in a language they cannot read needs to find the
                // other one, and "Arabic" spelled in English is no help to
                // them at all — «العربية» is. Translating these would make the
                // escape hatch unreadable to exactly the person using it.
                label: 'العربية',
                selected: override == 'ar',
                onTap: () => _choose(context, ref, 'ar'),
              ),
              const _Option.divider(),
              _Option(
                // i18n-exempt: as above — an endonym, not copy.
                label: 'English',
                selected: override == 'en',
                onTap: () => _choose(context, ref, 'en'),
              ),
              const SizedBox(height: SahraSpace.s5),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, String? code) async {
    await ref.read(localeOverrideProvider.notifier).set(code);
    if (context.mounted) await Navigator.of(context).maybePop();
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap})
      : isDivider = false;

  const _Option.divider()
      : label = '',
        selected = false,
        onTap = null,
        isDivider = true;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool isDivider;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    if (isDivider) return Divider(height: 1, color: s.line);

    return MergeSemantics(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            // 48, like every other row in this app.
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    // THE OPTION'S OWN DIRECTION, not the app's. «العربية» in a
                    // left-to-right app still reads right-to-left; forcing the
                    // ambient direction on it is how a language name renders
                    // backwards to the only people who need to read it.
                    textDirection: _directionOf(label),
                    style: text.bodyLarge?.copyWith(
                      color: s.textBody,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected) SahraIcon('check', size: 18, color: s.accentOnSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Arabic script reads RTL whatever the app is set to.
  TextDirection _directionOf(String label) =>
      RegExp(r'[؀-ۿ]').hasMatch(label)
          ? TextDirection.rtl
          : TextDirection.ltr;
}
