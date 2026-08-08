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

import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/reservations/presentation/book_screen.dart';
import '../features/reservations/presentation/confirmed_screen.dart';
import '../features/reservations/presentation/my_bookings_screen.dart';
import '../features/saved/presentation/saved_screen.dart';
import '../features/reservations/presentation/reservation_screen.dart';
import '../features/restaurants/presentation/search_screen.dart';
import '../features/restaurants/presentation/venue_screen.dart';
import '../shared/widgets/app_shell.dart';

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

/// Sign-in, pushed OVER whatever the diner was doing.
///
/// `push`, never `go`, and it returns `true` when the diner got in. The book
/// screen awaits that answer to decide whether to re-attempt the hold — which
/// is what makes "cancelled sign-in leaves the selection alone" a property of
/// the navigation rather than a flag somebody has to remember to check.
///
/// [venueId] IS in the URL; the SLOT is not, and the difference is the whole
/// argument in [PendingSelection]. A venue id is a place, and a refresh landing
/// on "sign in, you were booking at Layali" is harmless. A slot is a claim on
/// availability that expires, and a refresh landing on one re-attempts a hold
/// that has since become somebody else's table.
class SignInRoute {
  const SignInRoute([this.venueId]);
  final String? venueId;
  static const String path = '/sign-in';

  Future<bool?> push(BuildContext context) => context.push<bool>(
        venueId == null ? path : '$path?venue=$venueId',
      );

  /// For entry points with nothing underneath — the signed-out bookings tab.
  void go(BuildContext context) => context.go(path);
}

class BookingsRoute {
  const BookingsRoute();
  static const String path = '/bookings';
  void go(BuildContext context) => context.go(path);
}

class AccountRoute {
  const AccountRoute();
  static const String path = '/account';
  void go(BuildContext context) => context.go(path);
}

/// C-2.7. Reached from the Account screen, not a tab.
///
/// FOUR TABS WERE CONSIDERED AND REJECTED. `ProfileScreen.jsx` lists "Saved
/// places" as a row inside the profile, and the bottom bar in every reference
/// has three items. Adding a fourth would be a change to the navigation the
/// designer drew, to save one tap on a screen a diner visits occasionally.
class SavedRoute {
  const SavedRoute();

  static const String path = '/saved';
  void go(BuildContext context) => context.push(path);
}

class ReservationRoute {
  const ReservationRoute(this.id);
  final String id;
  static const String path = '/bookings/:id';
  void go(BuildContext context) => context.push('/bookings/$id');
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

/// THE TAB BAR IS A SHELL, NOT A WIDGET EACH SCREEN REMEMBERS TO ADD.
///
/// A `ShellRoute` wraps every top-level destination, so the navigation exists
/// because of where you are rather than because a screen opted in — the same
/// argument as `SahraPageWidth`, one level up. Adding a fourth tab later is one
/// entry here, not an edit to four files.
///
/// What is deliberately OUTSIDE the shell: venue detail, the booking form, the
/// confirmation, and sign-in. Those are a flow, not a destination — a diner
/// mid-booking should not be one tap from silently abandoning it, and the
/// confirmation is a full-screen moment in the reference.
GoRouter buildRouter() => GoRouter(
      initialLocation: SearchRoute.path,
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => AppShell(
            location: state.uri.path,
            child: child,
          ),
          routes: <RouteBase>[
            GoRoute(
              path: SearchRoute.path,
              builder: (_, __) => const SearchScreen(),
            ),
            GoRoute(
              path: BookingsRoute.path,
              builder: (_, __) => const MyBookingsScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      ReservationScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: SavedRoute.path,
              builder: (_, __) => const SavedScreen(),
            ),
            GoRoute(
              path: AccountRoute.path,
              builder: (_, __) => const AccountScreen(),
            ),
          ],
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
          path: SignInRoute.path,
          builder: (context, state) => SignInScreen(
            pendingRestaurantId: state.uri.queryParameters['venue'],
            // Both callbacks come from the ROUTE, not from inside the screen,
            // because both answers depend on how the diner arrived. Pushed over
            // a booking there is something to pop back to and something to tell
            // it; opened from the bookings tab there is neither.
            onClose: context.canPop() ? () => context.pop(false) : null,
            onSignedIn: () => context.canPop()
                ? context.pop(true)
                : const BookingsRoute().go(context),
          ),
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
