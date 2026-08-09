// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadNotificationCountHash() =>
    r'14ff18e1648cf09200f91e777c4735448d161fd2';

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
///
/// Copied from [unreadNotificationCount].
@ProviderFor(unreadNotificationCount)
final unreadNotificationCountProvider = AutoDisposeProvider<int>.internal(
  unreadNotificationCount,
  name: r'unreadNotificationCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadNotificationCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationCountRef = AutoDisposeProviderRef<int>;
String _$notificationFeedNotifierHash() =>
    r'553815d4afaeb57745e9019a860f1c72107f157b';

/// C-4.7 — the centre's contents.
///
/// WATCHES THE SESSION, like `savedVenues` and `myReservations`: signing in on
/// another screen has to make this appear, and signing out has to make it
/// vanish. Signed out it returns EMPTY rather than calling and catching the
/// 401 — the round trip would log an error for a situation that is not one.
///
/// A CLASS RATHER THAN A FUNCTION, so `markAll` can drop the badge without
/// refetching. See [MarkNotificationsRead] for why that matters.
///
/// Copied from [NotificationFeedNotifier].
@ProviderFor(NotificationFeedNotifier)
final notificationFeedNotifierProvider = AutoDisposeAsyncNotifierProvider<
    NotificationFeedNotifier, NotificationFeed>.internal(
  NotificationFeedNotifier.new,
  name: r'notificationFeedNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationFeedNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationFeedNotifier = AutoDisposeAsyncNotifier<NotificationFeed>;
String _$markNotificationsReadHash() =>
    r'5d7af8d40062f43d50685c42a2d57bf9d1355dfd';

/// Marking read, which the centre does on open.
///
/// ── WHY ON OPEN AND NOT PER ROW ──────────────────────────────────────────
///
/// The badge means "there is something here you have not seen". Opening the
/// screen is seeing it. Requiring a tap per row would leave the badge lit over
/// a screen the diner has read, and the obvious way to clear it — tapping rows
/// — would navigate them somewhere they did not want to go.
///
/// Copied from [MarkNotificationsRead].
@ProviderFor(MarkNotificationsRead)
final markNotificationsReadProvider =
    AutoDisposeNotifierProvider<MarkNotificationsRead, bool>.internal(
  MarkNotificationsRead.new,
  name: r'markNotificationsReadProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$markNotificationsReadHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MarkNotificationsRead = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
