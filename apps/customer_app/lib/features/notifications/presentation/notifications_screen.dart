import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';
import 'notification_copy.dart';
import 'notifications_notifier.dart';

/// C-4.7 — the notification centre.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NO REFERENCE. `ProfileScreen.jsx` DRAWS THE DOOR AND NOT THE ROOM.
/// ─────────────────────────────────────────────────────────────────────────
///
/// The profile reference lists a `bell / Notifications` row, so the entry point
/// is designed; the screen behind it is not, in any of the fourteen references.
/// Per the standing instruction — where you must invent, keep it plain and
/// boring — this is a list of rows made of `SahraIcon`, two `Text`s and a
/// divider. Nothing is drawn here that the app does not draw elsewhere.
///
/// ── THE APOLOGY IS GONE, AND THAT IS THE POINT ───────────────────────────
///
/// This screen carried a line for one day:
///
/// > "We can't alert your phone yet, so check back here."
///
/// **Deleted 2026-08-10, in the commit that bound the FCM adapter** — the
/// arrangement written down when it was added. It stopped being true: the
/// Firebase project exists, the adapter is bound, and an Android handset that
/// has agreed to notifications is registered after its first booking and rings.
///
/// It was NOT deleted when the server adapter was bound. Binding the carrier
/// makes push possible; it delivers nothing until a handset has registered a
/// token, and until `push_registration.dart` existed nothing in this app ever
/// called `POST /devices`. Removing the notice at that point would have
/// replaced a true statement with a false one.
///
/// **iOS is still unreachable** — no Apple Developer account, so no APNs key.
/// That is not hidden either; it is refused at the server before the network
/// and reported by `GET /health` as a 503. It is not surfaced HERE because no
/// iOS build exists to show it to.
///
/// ── MARKED READ ON OPEN, AND THE ROWS DO NOT MOVE ────────────────────────
///
/// Opening the screen is seeing it, so the badge clears here rather than per
/// row. But the LIST is not refetched: rows keep the unread styling they were
/// drawn with for this visit, because a list that re-renders under a diner's
/// thumb the instant they arrive is a list they cannot read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // AFTER THE FIRST FRAME. Reading a provider during `initState` throws, and
    // the mark has to wait for the fetch anyway — there is nothing to mark
    // until the list has loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    if (!mounted) return;
    if (ref.read(currentSessionProvider) == null) return;
    await ref.read(markNotificationsReadProvider.notifier).markAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentSessionProvider) != null;

    return Scaffold(
      appBar: SahraAppBar(
        title: Text(l10n.notificationsTitle),
        leading: IconButton(
          icon: const SahraIcon('arrow-back'),
          tooltip: l10n.venueBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SahraPageWidth(
        child: signedIn ? const _Feed() : const _SignedOut(),
      ),
    );
  }
}

/// Reachable, because a session can end while this screen is open.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: SahraSpace.all(SahraSpace.s5),
      child: SahraEmptyState(
        icon: 'bell',
        title: l10n.notificationsSignedOutTitle,
        message: l10n.accountSignedOutMessage,
        actionLabel: l10n.bookingsSignedOutAction,
        onAction: () => const SignInRoute().go(context),
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SahraAsyncView<NotificationFeed>(
      value: ref.watch(notificationFeedNotifierProvider),
      onRetry: () => ref.invalidate(notificationFeedNotifierProvider),
      isEmpty: (feed) => feed.items.isEmpty,
      loading: (_) => ListView(
        padding: SahraSpace.all(SahraSpace.s5),
        children: const <Widget>[
          SahraSkeleton(height: 64, radius: SahraRadius.md),
          SizedBox(height: SahraSpace.s3),
          SahraSkeleton(height: 64, radius: SahraRadius.md),
          SizedBox(height: SahraSpace.s3),
          SahraSkeleton(height: 64, radius: SahraRadius.md),
        ],
      ),
      empty: (context) => SingleChildScrollView(
        padding: SahraSpace.all(SahraSpace.s5),
        child: SahraEmptyState(
          icon: 'bell',
          title: l10n.notificationsEmptyTitle,
          message: l10n.notificationsEmptyMessage,
        ),
      ),
      content: (context, feed) {
        // Unrenderable kinds are dropped HERE rather than returning a blank
        // row from the builder, so a server one release ahead cannot leave gaps
        // in the list or make the divider logic wrong.
        final rows = <(AppNotification, NotificationCopy)>[
          for (final n in feed.items)
            if (notificationCopy(n, context) case final NotificationCopy c) (n, c),
        ];

        return ListView.separated(
          padding: SahraSpace.all(SahraSpace.s5),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final (notification, copy) = rows[i];
            return _Row(notification: notification, copy: copy);
          },
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.copy});

  final AppNotification notification;
  final NotificationCopy copy;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final target = notification.reservationId;

    final row = Container(
      // 48 minimum, matching every other list row in the app. Rows without a
      // destination keep the height so the list does not visibly jump.
      constraints: const BoxConstraints(minHeight: 48),
      padding: SahraSpace.symmetric(vertical: SahraSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // THE UNREAD MARK IS A DOT PLUS A WEIGHT, not colour alone. WCAG
          // 1.4.1: colour cannot be the only carrier of meaning, and "which of
          // these have I already seen" is meaning.
          Padding(
            padding: SahraSpace.inset(top: SahraSpace.s1),
            child: SahraIcon(
              copy.icon,
              size: 18,
              color: notification.isUnread ? s.accentOnSurface : s.textSoft,
            ),
          ),
          const SizedBox(width: SahraSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.title,
                  style: text.bodyLarge?.copyWith(
                    color: s.textBody,
                    fontWeight:
                        notification.isUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (copy.body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: SahraSpace.s1),
                  Text(
                    copy.body,
                    // NO `textDirection`, and that is the considered answer.
                    //
                    // The first version passed `contentDirection(copy.body)`
                    // and the Arabic golden showed why it is wrong: this is OUR
                    // sentence in the reading language, with foreign runs
                    // inside it. Letting a venue called "Zooba" flip the whole
                    // line to left-to-right left an Arabic reminder starting
                    // at the wrong edge.
                    //
                    // The runs are isolated individually instead — see
                    // `notification_copy.dart`. `contentDirection` is for a
                    // paragraph that is ENTIRELY somebody else's, which is the
                    // next widget down.
                    style: text.bodySmall?.copyWith(color: s.textSoft),
                  ),
                ],
                if (copy.quote != null) ...<Widget>[
                  const SizedBox(height: SahraSpace.s1),
                  Text(
                    copy.quote!,
                    // ITS OWN LINE AND ITS OWN DIRECTION. Somebody at the venue
                    // typed this, in a language we did not choose — the same
                    // call the reviews list makes for a review body.
                    textDirection: contentDirection(copy.quote!),
                    style: text.bodySmall?.copyWith(color: s.textFaint),
                  ),
                ],
              ],
            ),
          ),
          if (target != null) ...<Widget>[
            const SizedBox(width: SahraSpace.s2),
            Padding(
              padding: SahraSpace.inset(top: SahraSpace.s1),
              child: SahraIcon('chevron-forward', size: 14, color: s.textFaint),
            ),
          ],
        ],
      ),
    );

    // A ROW WITH NOWHERE TO GO IS NOT TAPPABLE, and does not pretend to be.
    // An `InkWell` that ripples and then does nothing is the control-that-looks-
    // like-it-is-telling-you-something problem in miniature.
    if (target == null) return row;

    // MERGED, NOT RELABELLED.
    //
    // The first version built `label: '${copy.title}. ${copy.body}'`, which
    // `label-literal` refused — correctly. The second moved the separator into
    // the ARB, which `arb_test` refused as an untranslated string, because
    // `'{title}. {body}'` is byte-identical in both languages.
    //
    // Both were solving a problem that does not exist. `MergeSemantics` folds
    // the row's own Texts into one node, so a screen reader announces exactly
    // what is on screen, in the order it is on screen, with no third copy of
    // the sentence to keep in step. Two guards said so before this did.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => ReservationRoute(target).go(context),
          child: row,
        ),
      ),
    );
  }
}
