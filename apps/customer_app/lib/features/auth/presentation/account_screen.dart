import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import 'sign_out_notifier.dart';

/// `docs/design/ui_kits/app/ProfileScreen.jsx`.
///
/// WHAT THE REFERENCE DRAWS AND THIS DOES NOT:
///
///   - **The stats row** — 12 bookings / 34 saved / 4.9 rating. Two of the
///     three have no source (saved is unbuilt, a diner has no rating) and the
///     third would need a count endpoint. Three numbers where two are invented
///     is worse than none.
///   - **The loyalty card** — "240 points, 60 to your free dessert". C-4.5 is
///     **P2** and `Env.enableLoyalty` gates it.
///   - **Four of the seven rows** — saved places, invite friends, payment
///     methods, help & support. None has an implementation. Rather than draw
///     rows that fail on tap, one line says which are missing: a diner looking
///     for payment methods learns they are not there, instead of tapping and
///     finding out.
///   - **The avatar and "member since"** — there is no avatar upload and no
///     join date in `UserResponse`. The initials avatar is real; the date is
///     not, so it is absent.
///
/// What is here is what exists: who you are signed in as, the way to your
/// bookings, the language the app is following, and the way out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    return Scaffold(
      body: SahraPageWidth(
        child: SafeArea(
          child: session == null
              ? const _SignedOut()
              : _SignedIn(name: session.fullName, phone: session.phone),
        ),
      ),
    );
  }
}

/// Reachable, because a session can end while this screen is open — the tab
/// itself demands sign-in before it opens (see `AppShell`), so this is the
/// expiry case rather than the ordinary one.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: SahraSpace.all(SahraSpace.s5),
      child: SahraEmptyState(
        icon: 'user',
        title: l10n.accountSignedOutTitle,
        message: l10n.accountSignedOutMessage,
        actionLabel: l10n.bookingsSignedOutAction,
        onAction: () => const SignInRoute().go(context),
      ),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final signingOut = ref.watch(signOutProvider);

    return ListView(
      padding: SahraSpace.all(SahraSpace.s5),
      children: <Widget>[
        Column(
          children: <Widget>[
            SahraAvatar(name: name, size: 76),
            const SizedBox(height: SahraSpace.s3),
            Text(name, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: SahraSpace.s1),
            Text(
              // The number is Latin digits inside possibly-Arabic prose — the
              // isolate stops the leading `+` from being dragged to the far end.
              ltrRun(phone),
              style: SahraTypography.numeric(
                text.bodyMedium!.copyWith(color: s.textFaint),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: SahraSpace.s6),
        _Row(
          icon: 'calendar',
          label: l10n.accountMyBookings,
          onTap: () => const BookingsRoute().go(context),
        ),
        _Row(
          icon: 'globe',
          label: l10n.accountLanguage,
          // Not a control. The app follows the device (main.dart), and an
          // in-app language switch that disagreed with the phone's setting is
          // a second source of truth for something the phone already knows.
          value: l10n.accountLanguageValue,
        ),
        const SizedBox(height: SahraSpace.s5),
        Text(
          l10n.accountNotBuilt,
          style: text.bodySmall?.copyWith(color: s.textFaint),
        ),
        const SizedBox(height: SahraSpace.s6),
        SahraButton(
          label: signingOut ? l10n.accountSigningOut : l10n.accountSignOut,
          variant: SahraButtonVariant.secondary,
          onPressed: signingOut
              ? null
              : () => ref.read(signOutProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.value, this.onTap});

  final String icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final row = Container(
      // 48, matching the tab targets. A list row is a tap target like any
      // other, and the two non-tappable rows keep the height so the list does
      // not visibly jump between them.
      constraints: const BoxConstraints(minHeight: 48),
      padding: SahraSpace.symmetric(vertical: SahraSpace.s2),
      child: Row(
        children: <Widget>[
          SahraIcon(icon, size: 20, color: s.textSoft),
          const SizedBox(width: SahraSpace.s3),
          Expanded(child: Text(label, style: text.bodyLarge)),
          if (value != null)
            Text(value!, style: text.bodySmall?.copyWith(color: s.textFaint)),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: SahraSpace.s2),
            SahraIcon('chevron-forward', size: 14, color: s.textFaint),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
