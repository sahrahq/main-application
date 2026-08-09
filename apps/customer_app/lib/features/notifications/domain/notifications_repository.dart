import 'app_notification.dart';

/// One page of the centre, plus the count the badge is drawn from.
class NotificationFeed {
  const NotificationFeed({required this.items, required this.unreadCount});

  const NotificationFeed.empty() : items = const <AppNotification>[], unreadCount = 0;

  final List<AppNotification> items;

  /// Unread across the WHOLE history, not across [items].
  ///
  /// The server computes it separately for exactly this reason: a count taken
  /// over one page reads wrong for the diner with more notifications than fit
  /// in one, who is the diner most likely to have unread ones.
  final int unreadCount;
}

abstract class NotificationsRepository {
  /// The caller's notifications, newest first.
  ///
  /// OWNERSHIP IS NOT A PARAMETER, and must never become one — the server takes
  /// it from the token. Same rule as `SavedRepository`.
  Future<NotificationFeed> feed();

  /// Mark read. `ids` omitted means every unread one.
  ///
  /// Returns the unread count AFTER the call, so the badge is drawn from the
  /// server's answer rather than from the client's arithmetic. Idempotent: a
  /// replay marks nothing and returns the same count.
  Future<int> markRead({List<String>? ids});
}
