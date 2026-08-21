import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/providers/locale_override.dart';
import '../../notifications/presentation/notifications_notifier.dart';
import 'edit_name_sheet.dart';
import 'language_sheet.dart';
import 'sign_out_notifier.dart';

/// `docs/design/ui_kits/app/ProfileScreen.jsx`.
///
/// WHAT THE REFERENCE DRAWS AND THIS DOES NOT:
///
///   - **The stats row** — 12 bookings / 34 saved / 4.9 rating. Two of the
///     three have no source (no saved COUNT endpoint, a diner has no rating)
///     and the
///     third would need a count endpoint. Three numbers where two are invented
///     is worse than none.
///   - **The loyalty card** — "240 points, 60 to your free dessert". C-4.5 is
///     **P2** and `Env.enableLoyalty` gates it.
///   - **Three of the seven rows** — invite friends, payment methods, help &
///     support. None has an implementation. Rather than draw rows that fail on
///     tap, one line says which are missing: a diner looking for payment
///     methods learns they are not there, instead of tapping and finding out.
///     (Saved places was the fourth until C-2.7 landed in Group C.)
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
        // NOT IN `ProfileScreen.jsx`. The reference has seven rows and an edit
        // control is not among them — the design package has no profile-edit
        // screen at all. Reported rather than invented: this row is built from
        // the same `_Row` as its neighbours and opens a sheet made of
        // `SahraInput` + `SahraButton`, so nothing new was designed, but it is
        // a deviation and it is named here.
        //
        // It exists because `PATCH /auth/me` otherwise has no caller, and a
        // capability nothing calls is indistinguishable from one that does not
        // exist. A diner whose name was mistyped at sign-up currently has no
        // way to correct the name shown to the restaurant at the door.
        _Row(
          icon: 'user',
          label: l10n.accountEditName,
          onTap: () => showEditNameSheet(context, ref, currentName: name),
        ),
        // C-2.7, and this row is the ONLY way to reach it. `SavedScreen` with
        // no route to it would be a screen that passes its own tests and does
        // not exist — the failure this project has already shipped once.
        _Row(
          icon: 'heart',
          label: l10n.accountSavedPlaces,
          onTap: () => const SavedRoute().go(context),
        ),
        // C-4.7 — `bell / Notifications`, the fourth of the reference's seven
        // rows to become real, and the only way to reach the centre.
        //
        // THE COUNT IS THE POINT. Without it the row is a door with nothing
        // visible behind it, and since push does not exist yet this row is the
        // ONLY signal a diner ever gets that a restaurant cancelled their
        // table. A bell with no number is a bell nobody presses.
        _Row(
          icon: 'bell',
          label: l10n.accountNotifications,
          badge: ref.watch(unreadNotificationCountProvider),
          onTap: () => const NotificationsRoute().go(context),
        ),
        // AMENDED 2026-08-09 — it IS a control now.
        //
        // The original decision, kept here because the reasoning is still
        // instructive: "the app follows the device, and an in-app language
        // switch that disagreed with the phone's setting is a second source of
        // truth for something the phone already knows."
        //
        // That was wrong about this market. A large share of people in Egypt
        // run their phone in English and want to read Arabic, or the reverse;
        // the handset language is a fact about the handset, not about what
        // somebody wants to read over dinner. Overruled by the product owner
        // as a market fact.
        //
        // The phone is still the DEFAULT — see `LocaleOverride`, where null is
        // the ordinary state and nothing is written until somebody chooses.
        // THEME still follows the device, and that half of the original
        // decision stands: light and dark are about the room you are in, which
        // the phone genuinely does know.
        _Row(
          icon: 'globe',
          label: l10n.accountLanguage,
          value: ref.watch(localeOverrideProvider) == null
              ? l10n.languageFollowDevice
              : l10n.accountLanguageValue,
          onTap: () => showLanguageSheet(context, ref),
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
          onPressed: signingOut ? null : () => ref.read(signOutProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.badge = 0,
    this.onTap,
  });

  final String icon;
  final String label;
  final String? value;

  /// Unread count. Zero draws nothing — a badge reading "0" is a control
  /// telling you something and telling you nothing at the same time.
  final int badge;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

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
          // `w500`, and the reason is measured rather than aesthetic.
          //
          // Adding the Notifications row moved the pixel `textContrastGuideline`
          // samples on this screen, and it began failing at 3.02:1 in ARABIC
          // ONLY. The pair is `textBody` on `surfacePage`, which measures
          // **17.54:1** — the strongest text combination in the whole palette —
          // so no colour change could have been the fix, and none was possible:
          // the ceiling at a 50% anti-aliased edge on this surface is 3.93.
          //
          // Third time this check has bitten, and the first time the failure
          // itself explained why (see `kEdgeSampledContrastCaveat`). Its remedy
          // is more INK, not a different hue: Reem Kufi at 16pt regular has
          // thin strokes, so a sampler landing between them finds mostly
          // background. A medium weight on a navigation label is a defensible
          // choice on its own terms and it is what a list row wants anyway.
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (badge > 0) ...<Widget>[
            const SizedBox(width: SahraSpace.s2),
            // A WORD, NOT A BARE NUMERAL. "3 new" survives being read aloud by
            // a screen reader; a lone "3" beside "Notifications" is announced
            // as "Notifications 3" and could be a count of anything.
            SahraBadge(
              label: l10n.notificationsUnreadBadge(badge),
              variant: SahraBadgeVariant.warning,
            ),
          ],
          if (value != null) Text(value!, style: text.bodySmall?.copyWith(color: s.textFaint)),
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
