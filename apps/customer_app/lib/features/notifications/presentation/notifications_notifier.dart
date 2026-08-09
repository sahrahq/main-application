import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../domain/notifications_repository.dart';

part 'notifications_notifier.g.dart';

/// C-4.7 — the centre's contents.
///
/// WATCHES THE SESSION, like `savedVenues` and `myReservations`: signing in on
/// another screen has to make this appear, and signing out has to make it
/// vanish. Signed out it returns EMPTY rather than calling and catching the
/// 401 — the round trip would log an error for a situation that is not one.
///
/// A CLASS RATHER THAN A FUNCTION, so `markAll` can drop the badge without
/// refetching. See [MarkNotificationsRead] for why that matters.
@riverpod
class NotificationFeedNotifier extends _$NotificationFeedNotifier {
  @override
  Future<NotificationFeed> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const NotificationFeed.empty();

    return ref.watch(notificationsRepositoryProvider).feed();
  }

  /// Drop the badge to [remaining] without touching the rows.
  ///
  /// The list must not reorder or re-render under the diner's thumb the instant
  /// they arrive, so the rows keep the unread styling they were drawn with for
  /// this visit. Only the count changes. The next real fetch shows them read.
  void setUnread(int remaining) {
    final current = state.valueOrNull;
    if (current == null || current.unreadCount == remaining) return;
    state = AsyncData(
      NotificationFeed(items: current.items, unreadCount: remaining),
    );
  }
}

/// The dot on the Account row.
///
/// ── DERIVED, AND DELIBERATELY NOT ITS OWN REQUEST ────────────────────────
///
/// A `GET /notifications/unread-count` would be a second source of truth for a
/// number the list already carries, and the two would disagree for exactly as
/// long as one was stale. That is the window in which a diner taps a badge
/// showing 3 and finds nothing new — which teaches them to stop trusting it.
///
/// The cost is that the count is only as fresh as the last fetch of the list.
/// Acceptable while there is no push: **nothing can arrive without the app
/// asking**, so a stale count and a fresh one are the same number. When push
/// lands, an arriving message invalidates the feed and this follows — which is
/// the reason it is derived rather than stored.
@riverpod
int unreadNotificationCount(Ref ref) =>
    ref.watch(notificationFeedNotifierProvider).valueOrNull?.unreadCount ?? 0;

/// Marking read, which the centre does on open.
///
/// ── WHY ON OPEN AND NOT PER ROW ──────────────────────────────────────────
///
/// The badge means "there is something here you have not seen". Opening the
/// screen is seeing it. Requiring a tap per row would leave the badge lit over
/// a screen the diner has read, and the obvious way to clear it — tapping rows
/// — would navigate them somewhere they did not want to go.
@riverpod
class MarkNotificationsRead extends _$MarkNotificationsRead {
  @override
  bool build() => false;

  Future<void> markAll() async {
    if (state) return;
    state = true;
    try {
      final remaining = await ref.read(notificationsRepositoryProvider).markRead();
      ref.read(notificationFeedNotifierProvider.notifier).setUnread(remaining);
    } catch (_) {
      // SWALLOWED, AND THAT IS THE RIGHT CALL HERE. The diner did not ask for
      // this — they opened a screen. An error banner over a list they can read
      // perfectly well would report a failure of bookkeeping as a failure of
      // the thing they wanted. The badge stays lit, which is honest: we did not
      // record that they saw it, so we should not claim we did.
      state = false;
    }
  }
}
