import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._api);

  final SahraApi _api;

  @override
  Future<NotificationFeed> feed() async {
    final res = await guarded(() => _api.listNotifications());
    return NotificationFeed(
      items: res.items.map(_toDomain).toList(),
      unreadCount: res.unreadCount,
    );
  }

  @override
  Future<int> markRead({List<String>? ids}) async {
    final res = await guarded(
      () => _api.markRead(body: MarkNotificationsReadDto(ids: ids)),
    );
    return res.unreadCount;
  }

  AppNotification _toDomain(NotificationResponse r) => AppNotification(
        id: r.id,
        // PARSED, NOT CAST. An unrecognised type becomes `unknown` and renders
        // as nothing rather than throwing — a server one release ahead of this
        // handset is an ordinary situation, and it must not empty the screen.
        kind: NotificationKind.parse(r.type),
        data: r.data,
        // UTC on the wire, local in the app. `DateTime.parse` on an ISO string
        // with a `Z` yields a UTC DateTime, and formatting that directly would
        // show a Cairo diner an hour two behind the one they booked.
        createdAt: DateTime.parse(r.createdAt).toLocal(),
        readAt: r.readAt == null ? null : DateTime.parse(r.readAt!).toLocal(),
      );
}
