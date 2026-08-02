/// GoRouter (doc 07 §3).
///
/// The venue path is `/r/{slug}` because doc 07 §3 names
/// `sahra.app/r/{slug}` as the deep link every restaurant share carries.
/// Making the in-app route the SAME path means a shared link and a tap from
/// search land in one place, with no branch anywhere asking how the diner got
/// here — and on Flutter Web (which is how this runs locally) it is simply the
/// browser URL.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/reservations/presentation/book_screen.dart';
import '../features/reservations/presentation/confirmed_screen.dart';
import '../features/restaurants/presentation/search_screen.dart';
import '../features/restaurants/presentation/venue_screen.dart';

class SearchRoute {
  const SearchRoute();
  static const String path = '/';
  void go(BuildContext context) => context.go(path);
}

class VenueRoute {
  const VenueRoute(this.idOrSlug);
  final String idOrSlug;
  static const String path = '/r/:idOrSlug';
  void go(BuildContext context) => context.push('/r/$idOrSlug');
}

class BookRoute {
  const BookRoute(this.restaurantId, this.venueName);
  final String restaurantId;
  final String venueName;
  static const String path = '/r/:idOrSlug/book';

  /// The venue NAME travels as a query parameter, not just the id.
  ///
  /// Without it the booking screen would have to load the whole profile again
  /// to put a title on itself, and a diner would watch "Book a table" sit above
  /// a blank space while it did. The id is still the thing the API is called
  /// with — the name is display only.
  void go(BuildContext context) =>
      context.push('/r/$restaurantId/book?name=${Uri.encodeComponent(venueName)}');
}

class ConfirmedRoute {
  const ConfirmedRoute(this.code, this.venueName, this.startsAt, this.partySize);
  final String code;
  final String venueName;
  final String startsAt;
  final int partySize;
  static const String path = '/booked/:code';

  /// `go`, not `push`: a confirmed booking is the end of the flow, and a diner
  /// must not be able to swipe back into the form that produced it and submit
  /// it twice.
  void go(BuildContext context) => context.go(
        '/booked/$code'
        '?name=${Uri.encodeComponent(venueName)}'
        '&at=${Uri.encodeComponent(startsAt)}'
        '&party=$partySize',
      );
}

GoRouter buildRouter() => GoRouter(
      initialLocation: SearchRoute.path,
      routes: <RouteBase>[
        GoRoute(
          path: SearchRoute.path,
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: VenueRoute.path,
          builder: (_, state) =>
              VenueScreen(idOrSlug: state.pathParameters['idOrSlug']!),
          routes: <RouteBase>[
            GoRoute(
              path: 'book',
              builder: (_, state) => BookScreen(
                restaurantId: state.pathParameters['idOrSlug']!,
                venueName: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ],
        ),
        GoRoute(
          path: ConfirmedRoute.path,
          builder: (_, state) => ConfirmedScreen(
            code: state.pathParameters['code']!,
            venueName: state.uri.queryParameters['name'] ?? '',
            startsAt: state.uri.queryParameters['at'] ?? '',
            partySize: int.tryParse(state.uri.queryParameters['party'] ?? '') ?? 2,
          ),
        ),
      ],
    );
