import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/core/error/failure.dart';
import 'package:sahra_customer_app/features/auth/domain/auth_repository.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_notifier.dart';
import 'package:sahra_customer_app/features/auth/presentation/account_screen.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/book_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/my_bookings_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/my_reservations_notifier.dart';
import 'package:sahra_customer_app/features/reservations/presentation/pending_booking.dart';
import 'package:sahra_customer_app/features/reservations/presentation/reservation_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/confirmed_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_notifier.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/venue_screen.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/shared/location/location_notifier.dart';
import 'package:sahra_customer_app/shared/location/location_source.dart';
import 'package:sahra_customer_app/shared/push/push_registration.dart';
import 'package:sahra_customer_app/shared/push/push_token_source.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';

import 'support/fakes.dart';
import 'support/screen_harness.dart';
import 'support/fixture_dates.dart';
import 'package:sahra_customer_app/shared/widgets/venue_image_provider.dart';
import 'support/fixture_image.dart';
import 'package:sahra_customer_app/features/saved/presentation/saved_screen.dart';
import 'package:sahra_customer_app/features/notifications/presentation/notifications_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/discover_screen.dart';
import 'package:sahra_customer_app/features/onboarding/presentation/splash_screen.dart';
import 'package:sahra_customer_app/features/onboarding/presentation/onboarding_seen.dart';
import 'package:sahra_customer_app/features/onboarding/presentation/onboarding_screen.dart';
import 'dart:async';

/// Every screen STATE that has to be pictured.
///
/// Not one entry per screen — one per STATE. The four-state pattern is only
/// real if all four are looked at, and the three that go wrong are exactly the
/// three nobody screenshots: empty, error, and the conflict a diner meets when
/// somebody else was faster.
///
/// Each entry supplies its own fake transport, so a state is produced by the
/// REAL notifier reacting to a REAL response rather than by a widget being
/// handed a hardcoded value. A golden of a hand-built error state proves the
/// widget renders; this proves the screen ARRIVES there.
final Map<String, ScreenCase> screenCases = <String, ScreenCase>{
  // ── Search ──────────────────────────────────────────────────────────────
  'Search/start': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => _transport((_, __, ___) => _emptyPage),
  ),
  'Search/results': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPage),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('layali')),
    ],
  ),
  'Search/no-results': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _emptyPage),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('zzz no such venue')),
    ],
  ),
  'Search/outage': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw envelope(503, 'search_unavailable')),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('koshary')),
    ],
  ),
  'Search/offline': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('koshary')),
    ],
  ),

  // ── Venue detail ────────────────────────────────────────────────────────
  'Venue/profile': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(profile: _profile)),
  ),
  'Venue/not-found': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'nope'),
    overrides: (_) => _transport((_, __, ___) => throw envelope(404, 'restaurant_not_found')),
  ),

  // ── Booking ─────────────────────────────────────────────────────────────
  'Book/slots': ScreenCase(
    build: (_) => const BookScreen(restaurantId: _venueId, venueName: 'Layali Lounge'),
    overrides: (_) => _transport((_, __, ___) => _slots),
  ),
  'Book/no-slots': ScreenCase(
    build: (_) => const BookScreen(restaurantId: _venueId, venueName: 'Layali Lounge'),
    overrides: (_) => _transport((_, __, ___) => _noSlots),
  ),

  // ── Confirmation ────────────────────────────────────────────────────────
  'Confirmed/ticket': ScreenCase(
    build: (_) => const ConfirmedScreen(
      code: 'SAH-7K2M',
      venueName: 'Layali Lounge',
      startsAt: '${kFutureDate}T18:00:00.000Z',
      partySize: 2,
      // DELIBERATELY NOT what `startsAt.toLocal()` would produce on any
      // machine. The ticket must show the venue's clock, and a fixture that
      // happened to agree with the device would make the golden unable to
      // show the difference.
      wallClock: '20:00',
    ),
    overrides: (_) => _transport((_, __, ___) => throw offline),
  ),

  // ── Sign in ─────────────────────────────────────────────────────────────
  'SignIn/phone': ScreenCase(
    build: (_) => SignInScreen(onClose: () {}),
    overrides: (_) => _transport((_, __, ___) => throw offline),
  ),
  // The state that carries the C-1.6 decision: a diner interrupted mid-booking,
  // being told what is waiting for them. If this picture is not persuasive the
  // decision is not survivable, so it gets its own cell in all four.
  'SignIn/pending-slot': ScreenCase(
    build: (_) => SignInScreen(pendingRestaurantId: _venueId, onClose: () {}),
    overrides: (cell) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      pendingBookingProvider(_venueId).overrideWith(() => _ParkedSlot(cell)),
    ],
  ),
  'SignIn/code': ScreenCase(
    build: (_) => SignInScreen(onClose: () {}),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      signInProvider.overrideWith(() => _AwaitingCode()),
    ],
  ),
  // A locked-out diner. The one sign-in state where the copy has to do real
  // work — it must say that asking for another code will not help, without
  // blaming the person for having tried.
  'SignIn/locked-out': ScreenCase(
    build: (_) => SignInScreen(onClose: () {}),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      signInProvider.overrideWith(_LockedOut.new),
    ],
  ),

  // ── My bookings ─────────────────────────────────────────────────────────
  'Bookings/signed-out': ScreenCase(
    build: (_) => const MyBookingsScreen(),
    overrides: (_) => _transport((_, __, ___) => throw offline),
  ),
  'Bookings/upcoming': ScreenCase(
    build: (_) => const MyBookingsScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[_confirmed, _pending]),
      ..._signedIn,
    ],
  ),
  // `needs_acknowledgement`. The only signal a diner gets that a table they
  // believe they hold is gone — pictured deliberately, because it is the state
  // most likely to be built once and never looked at.
  'Bookings/venue-cancelled': ScreenCase(
    build: (_) => const MyBookingsScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[_venueCancelled, _confirmed]),
      ..._signedIn,
    ],
  ),
  'Bookings/empty': ScreenCase(
    build: (_) => const MyBookingsScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[]),
      ..._signedIn,
    ],
  ),
  'Bookings/past': ScreenCase(
    build: (_) => const MyBookingsScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[_completed]),
      ..._signedIn,
      bookingsViewProvider.overrideWith(() => _PastTab()),
    ],
  ),

  // ── Account ─────────────────────────────────────────────────────────────
  'Account/signed-in': ScreenCase(
    build: (_) => const AccountScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      ..._signedIn,
    ],
  ),
  // Reachable only when a session expires while the screen is open — the tab
  // demands sign-in before it opens. Pictured because "only reachable in one
  // situation" is exactly the state nobody looks at.
  'Account/signed-out': ScreenCase(
    build: (_) => const AccountScreen(),
    overrides: (_) => _transport((_, __, ___) => throw offline),
  ),

  // ── Reservation detail ──────────────────────────────────────────────────
  'Reservation/confirmed': ScreenCase(
    build: (_) => const ReservationScreen(id: _reservationId),
    overrides: (_) => <Override>[
      ..._transport(
        (_, path, __) => path.contains('/restaurants/') ? _profile : _confirmed,
      ),
      ..._signedIn,
    ],
  ),
  'Reservation/venue-cancelled': ScreenCase(
    build: (_) => const ReservationScreen(id: _reservationId),
    overrides: (_) => <Override>[
      ..._transport(
        (_, path, __) => path.contains('/restaurants/') ? _profile : _venueCancelled,
      ),
      ..._signedIn,
    ],
  ),
  'Reservation/not-found': ScreenCase(
    build: (_) => const ReservationScreen(id: _reservationId),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw envelope(404, 'reservation_not_found')),
      ..._signedIn,
    ],
  ),

  'Venue/with-photos': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => <Override>[
      ..._transport(_venueRoutes(profile: _profileWithPhotos)),
      _fixtureImages,
    ],
  ),
  'Search/with-photos': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPageWithCovers),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('layali')),
      _fixtureImages,
    ],
  ),

  // ── review_reports ──────────────────────────────────────────────────────
  'Reviews/report-sheet': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(
      profile: <String, Object?>{..._profile, 'rating': 4.25, 'rating_count': 4},
      menus: _menusFixture,
      reviews: _reviewsFixture,
    ),),
    // Reached by tapping "All reviews" and then "Report" on a card — two real
    // controls, in order. A sheet built directly is a sheet whose only route in
    // is the test.
    after: (tester) async {
      await _tapLabel(tester, (l) => l.venueReviewsAll, scroll: true);
      final BuildContext context = tester.element(find.byType(VenueScreen));
      await tester.tap(
        find.text(AppLocalizations.of(context).reviewReport).first,
      );
      await tester.pumpAndSettle();
    },
  ),

  // ── The location half-batch ─────────────────────────────────────────────
  //
  // Two cases, and the second is the one that ships broken elsewhere: a diner
  // who declined. The filter sheet must look complete and useful without a
  // position, because most diners will not give one.
  'Filters/near-me': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPage),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('layali')),
      locationSourceProvider
          .overrideWithValue(const FixedLocationSource.zamalek()),
    ],
    interactive: true,
    after: (tester) async {
      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);
      await tester.tap(find.text(l10n.filterOpen).first);
      await tester.pumpAndSettle();
      final Finder nearMe = find.text(l10n.filterNearMe);
      await tester.ensureVisible(nearMe);
      await tester.pumpAndSettle();
      await tester.tap(nearMe);
      await tester.pumpAndSettle();
    },
  ),
  'Filters/location-refused': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPage),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('layali')),
      locationSourceProvider.overrideWithValue(
        const FixedLocationSource.refused(LocationOutcome.deniedForever),
      ),
    ],
    interactive: true,
    after: (tester) async {
      final BuildContext context = tester.element(find.byType(SearchScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);
      await tester.tap(find.text(l10n.filterOpen).first);
      await tester.pumpAndSettle();
      final Finder nearMe = find.text(l10n.filterNearMe);
      await tester.ensureVisible(nearMe);
      await tester.pumpAndSettle();
      await tester.tap(nearMe);
      await tester.pumpAndSettle();
    },
  ),

  // ── Group D: menus and reviews ──────────────────────────────────────────
  //
  // FIVE CASES, not one. The venue page with everything on it is the happy
  // picture; the other four are the states that ship broken because nobody
  // looks at them — a venue with no menu, a menu that is only a PDF, a venue
  // nobody has reviewed yet, and the composer.
  'Venue/full': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => <Override>[
      ..._transport(_venueRoutes(
        profile: <String, Object?>{
          ..._profileWithPhotos,
          'rating': 4.25,
          'rating_count': 4,
        },
        menus: _menusFixture,
        reviews: _reviewsFixture,
      ),),
      _fixtureImages,
    ],
  ),
  'Venue/menu-pdf-only': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(
      profile: _profileUnrated,
      menus: _menusPdfOnly,
      reviews: _reviewsEmpty,
    ),),
  ),
  'Venue/no-reviews': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(
      profile: _profileUnrated,
      menus: _menusFixture,
      reviews: _reviewsEmpty,
    ),),
  ),
  'Menu/sheet': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(
      profile: _profileUnrated,
      menus: _menusFixture,
      reviews: _reviewsEmpty,
    ),),
    // Opened by TAPPING, not by constructing the sheet. A sheet built directly
    // is a sheet whose only route in is the test — the failure the journey test
    // exists to catch, in miniature.
    //
    // `interactive: false` because the sheet genuinely has no tap target: it is
    // a list of dishes, dismissed by dragging it or tapping the barrier, and
    // the barrier is not ours. The flag asserts that a screen claiming to be
    // interactive exposes at least one `SemanticsAction.tap`, so setting it
    // true here would be claiming a control that does not exist. (The PDF
    // handoff IS a button, and `Venue/menu-pdf-only` covers it.)
    interactive: false,
    after: (tester) async {
      await _tapLabel(tester, (l) => l.venueMenuFull);
    },
  ),
  'Reviews/sheet': ScreenCase(
    build: (_) => const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
    overrides: (_) => _transport(_venueRoutes(
      // 4.25 from 4, matching `_reviewsFixture` exactly — the hero and the
      // histogram are the same fact and must not disagree in a picture.
      profile: <String, Object?>{..._profile, 'rating': 4.25, 'rating_count': 4},
      menus: _menusFixture,
      reviews: _reviewsFixture,
    ),),
    // Same as the menu sheet: a read-only list. "Show more" appears only when
    // there is a next page, and this fixture is one page.
    interactive: false,
    after: (tester) async {
      await _tapLabel(tester, (l) => l.venueReviewsAll, scroll: true);
    },
  ),

  // ── First run ───────────────────────────────────────────────────────────
  'Onboarding/first': ScreenCase(
    build: (_) => const OnboardingScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[]),
      onboardingSeenStoreProvider.overrideWithValue(InMemoryOnboardingSeenStore()),
    ],
  ),
  'Onboarding/last': ScreenCase(
    build: (_) => const OnboardingScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[]),
      onboardingSeenStoreProvider.overrideWithValue(InMemoryOnboardingSeenStore()),
    ],
    after: (tester) async {
      await tester.tap(find.byType(SahraButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SahraButton).first);
      await tester.pumpAndSettle();
    },
  ),
  'Splash/waiting': ScreenCase(
    build: (_) => const SplashScreen(),
    // A STORE THAT NEVER ANSWERS, so the screen never navigates. Splash exists
    // to cover a storage read; with a real store it hands over in 600ms and a
    // golden of it would race the transition.
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[]),
      onboardingSeenStoreProvider.overrideWithValue(_NeverAnswers()),
    ],
    interactive: false,
  ),

  // ── Discover — THE HOME SCREEN ──────────────────────────────────────────
  'Discover/tonight': ScreenCase(
    build: (_) => const DiscoverScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPageWithCovers),
      ..._signedIn,
      _fixtureImages,
    ],
  ),
  'Discover/nothing-tonight': ScreenCase(
    build: (_) => const DiscoverScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _emptyPage),
      ..._signedIn,
    ],
  ),
  'Discover/signed-out': ScreenCase(
    build: (_) => const DiscoverScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPageWithCovers),
      _fixtureImages,
    ],
  ),

  'Saved/list': ScreenCase(
    build: (_) => const SavedScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _savedList),
      ..._signedIn,
      _fixtureImages,
    ],
  ),
  'Saved/empty': ScreenCase(
    build: (_) => const SavedScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => <Object>[]),
      ..._signedIn,
    ],
  ),
  'Saved/signed-out': ScreenCase(
    build: (_) => const SavedScreen(),
    overrides: (_) => _transport((_, __, ___) => <Object>[]),
  ),

  // ── Notifications (C-4.7) ───────────────────────────────────────────────
  //
  // ONE CASE PER KIND, in the same list. The centre's whole job is turning a
  // `type` + `data` into a sentence, and a golden of one kind proves the row
  // renders while saying nothing about the other five — the copy switch is
  // where a missing placeholder or an un-isolated clock time actually shows up.
  'Notifications/list': ScreenCase(
    build: (_) => const NotificationsScreen(),
    overrides: (_) => <Override>[
      ..._transport(_notificationsHandler(_notificationFeed)),
      ..._signedIn,
    ],
  ),
  'Notifications/empty': ScreenCase(
    build: (_) => const NotificationsScreen(),
    overrides: (_) => <Override>[
      ..._transport(_notificationsHandler(<String, Object?>{
        'items': <Object>[],
        'unread_count': 0,
      },),),
      ..._signedIn,
    ],
  ),
  'Notifications/signed-out': ScreenCase(
    build: (_) => const NotificationsScreen(),
    overrides: (_) => _transport(_notificationsHandler(<String, Object?>{
      'items': <Object>[],
      'unread_count': 0,
    },),),
  ),
  // The Account row carrying the badge. It is the ONLY door to the centre and
  // the only signal a diner gets that anything happened, so a picture of it
  // with the count on is worth as much as the screen behind it.
  'Account/unread': ScreenCase(
    build: (_) => const AccountScreen(),
    overrides: (_) => <Override>[
      ..._transport(_notificationsHandler(_notificationFeed)),
      ..._signedIn,
    ],
  ),

  'Search/filter-sheet': ScreenCase(
    build: (_) => const SearchScreen(),
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => _resultsPage),
      searchCriteriaProvider.overrideWith(() => _TypedQuery('layali')),
    ],
    after: (tester) async {
      // BY POSITION, not by label. The registry runs every case in Arabic too,
      // where the button reads «فلاتر» — a prefix match on "Filters" found
      // nothing in half the cells. Tonight is the first chip on this row and
      // Filters is the second.
      await tester.tap(find.byType(SahraChip).at(1));
      await tester.pumpAndSettle();
    },
  ),

  // ── The two sheets ──────────────────────────────────────────────────────
  //
  // Registered as cases so they go through the SAME three matrices as every
  // screen: four goldens, four accessibility cells, six viewports and a 200%
  // text cell. A modal built with `showModalBottomSheet` is not something the
  // registry can construct, so `after` taps it open first.
  'Reservation/cancel-sheet': ScreenCase(
    build: (_) => const ReservationScreen(id: _reservationId),
    overrides: (_) => <Override>[
      ..._transport(
        (_, path, __) => path.contains('/restaurants/') ? _profile : _confirmed,
      ),
      ..._signedIn,
    ],
    after: (tester) => _openActionSheet(tester, first: false),
  ),
  'Reservation/move-sheet': ScreenCase(
    build: (_) => const ReservationScreen(id: _reservationId),
    overrides: (_) => <Override>[
      ..._transport(
        (_, path, __) => switch (path) {
          final p when p.contains('/restaurants/') => _profile,
          final p when p.contains('/available-slots') => _slots,
          _ => _confirmed,
        },
      ),
      ..._signedIn,
    ],
    after: (tester) => _openActionSheet(tester, first: true),
  ),
  'Account/edit-name-sheet': ScreenCase(
    build: (_) => const AccountScreen(),
    overrides: (_) => <Override>[..._transport((_, __, ___) => _profile), ..._signedIn],
    after: (tester) async {
      // The Account screen is a short ListView; the edit row is the second
      // tappable one and is on screen at every viewport in the matrix.
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();
    },
  ),
};

class ScreenCase {
  const ScreenCase({
    required this.build,
    required this.overrides,
    this.interactive = true,
    this.after,
  });

  final Widget Function(Cell) build;
  final List<Override> Function(Cell) overrides;

  /// Drive the screen to the state under test — opening a sheet, typically.
  /// Runs in all three matrices, so a modal is covered exactly as a screen is.
  final ScreenSettle? after;

  /// A screen with no tappable control. `Confirmed` has one (Done), so the
  /// only honest members here would be states that genuinely offer nothing —
  /// listed explicitly rather than inferred, because "this one has no action"
  /// is exactly the excuse a broken screen would offer.
  final bool interactive;
}

/// Scroll to the actions, then open one of the two sheets.
///
/// THE SCROLL IS NOT DEFENSIVE PADDING. At 390x844 the buttons are on screen
/// and a bare `tap` works; at 320x568 they are below the fold, and a `ListView`
/// does not build what is not visible — so the finder matched nothing and the
/// viewport case died with "Bad state: No element" rather than reporting a
/// layout fault. The small phone is the one this project cares most about.
///
/// [first] picks modify; otherwise cancel. By index rather than by label, so
/// the case works in both locales without knowing either.
Future<void> _openActionSheet(WidgetTester tester, {required bool first}) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
  await tester.pumpAndSettle();

  final buttons = find.byType(SahraButton);
  await tester.tap(first ? buttons.first : buttons.last);
  await tester.pumpAndSettle();
}


/// One stored photo, as the API serves it. Three renditions, real dimensions.
Map<String, Object?> _imageJson({bool cover = true, int position = 0}) =>
    <String, Object?>{
      'id': '33333333-3333-4333-8333-33333333330$position',
      'urls': <String, String>{
        '160': 'https://cdn.test/venue/160.webp',
        '400': 'https://cdn.test/venue/400.webp',
        '1200': 'https://cdn.test/venue/1200.webp',
      },
      'width': 1600,
      'height': 1200,
      'position': position,
      'is_cover': cover,
    };

/// The same venue, photographed.
/// A venue handler that answers the THREE calls the venue screen makes.
///
/// The single-response `(_, __, ___) => _profile` shape was fine while the
/// screen made one request. Group D added menus and reviews, and a handler that
/// returns a profile for every path answers those two with a profile the
/// mappers cannot read — so both sections were absent from the golden and the
/// picture still looked plausible. Which is the fixture failure this repo keeps
/// finding, one layer up: the artefact rendered, it just stopped showing what
/// it was there to show.
Object? Function(String, String, Map<String, String>?) _venueRoutes({
  required Map<String, Object?> profile,
  List<Object>? menus,
  Map<String, Object?>? reviews,
}) =>
    (method, path, query) {
      if (path.endsWith('/menus')) return menus ?? <Object>[];
      if (path.endsWith('/reviews')) return reviews ?? _reviewsEmpty;
      return profile;
    };

final List<Object> _menusFixture = <Object>[
  <String, Object?>{
    'id': 'menu-1',
    'name_en': 'Kitchen',
    'name_ar': 'المطبخ',
    'kind': 'food',
    'pdf_url': null,
    'categories': <Object>[
      <String, Object?>{
        'id': 'cat-1',
        'name_en': 'Mezze',
        'name_ar': 'مقبّلات',
        'items': <Object>[
          _menuItem(
            'item-1',
            'Charred halloumi & date honey',
            'حلومي مشوي بعسل البلح',
            '320.00',
            <String>['vegetarian'],
          ),
          _menuItem(
            'item-2',
            'Muhammara, walnut',
            'محمرة بالجوز',
            '180.00',
            <String>['vegan'],
          ),
        ],
      },
      <String, Object?>{
        'id': 'cat-2',
        'name_en': 'Charcoal',
        'name_ar': 'فحم',
        'items': <Object>[
          _menuItem(
            'item-3',
            'Mixed grill for two',
            'مشوي مشكل لفردين',
            '980.00',
            const <String>[],
          ),
        ],
      },
    ],
  },
];

/// A venue whose whole menu is one scanned file — R-2.3's fallback, which has
/// no other way of being seen.
final List<Object> _menusPdfOnly = <Object>[
  <String, Object?>{
    'id': 'menu-pdf',
    'name_en': 'The menu',
    'name_ar': 'المنيو',
    'kind': 'food',
    'pdf_url': 'https://example.test/menus/carte.pdf',
    'categories': <Object>[],
  },
];

Map<String, Object?> _menuItem(
  String id,
  String en,
  String ar,
  String price,
  List<String> tags,
) =>
    <String, Object?>{
      'id': id,
      'name_en': en,
      'name_ar': ar,
      'description_en': null,
      'description_ar': null,
      'price': price,
      'currency': 'EGP',
      'dietary_tags': tags,
      'image': null,
    };

final Map<String, Object?> _reviewsEmpty = <String, Object?>{
  'summary': <String, Object?>{
    'rating': 0,
    'rating_count': 0,
    'breakdown': <String, Object?>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
  },
  'results': <Object>[],
  'next_cursor': null,
};

final Map<String, Object?> _reviewsFixture = <String, Object?>{
  'summary': <String, Object?>{
    'rating': 4.25,
    'rating_count': 4,
    'breakdown': <String, Object?>{'1': 0, '2': 0, '3': 1, '4': 1, '5': 2},
  },
  'results': <Object>[
    <String, Object?>{
      'id': 'rev-1',
      'rating': 5,
      'food_rating': 5,
      'service_rating': 5,
      'ambience_rating': 5,
      'body': 'We sat on the terrace until the oud player finished. The mixed '
          'grill is enough for three, whatever the menu says.',
      'author': 'Nour H.',
      // FIXED, and from the module every other date in this tree comes from.
      // A hardcoded ISO literal here is exactly what fixture_dates_test.dart
      // scans for, and for the reason it was written: a date that drifts past
      // now stops picturing what it was chosen to picture.
      'created_at': '${kPastDate}T20:30:00.000Z',
      'owner_reply': 'Thank you Nour — the oud is every night after ten.',
      'owner_replied_at': '${kPastDate}T22:00:00.000Z',
    },
    <String, Object?>{
      'id': 'rev-2',
      'rating': 4,
      'food_rating': 5,
      'service_rating': 3,
      'ambience_rating': null,
      'body': 'Food was excellent. Service slowed once it filled up.',
      'author': 'Omar A.',
      'created_at': '${kPastDate}T19:00:00.000Z',
      'owner_reply': null,
      'owner_replied_at': null,
    },
    <String, Object?>{
      // STARS ONLY — the nullable body, which is the majority case everywhere
      // it is allowed and would otherwise never appear in a picture.
      'id': 'rev-3',
      'rating': 5,
      'food_rating': null,
      'service_rating': null,
      'ambience_rating': null,
      'body': null,
      'author': 'Laila F.',
      'created_at': '${kPastDate}T18:00:00.000Z',
      'owner_reply': null,
      'owner_replied_at': null,
    },
  ],
  'next_cursor': null,
};

/// A venue nobody has reviewed yet — and whose HERO says so too.
///
/// `_profile` carries the seeded 4.8 from 312 reviews. Pairing it with an empty
/// review page pictured a venue claiming 312 reviews above a panel saying it
/// has none, which cannot happen in the product: the trigger in
/// `20260809010000_menus_and_reviews` recomputes `rating_avg` and
/// `rating_count` from the rows, so the two are the same fact.
///
/// A fixture that shows an impossible state is a fixture that stops being
/// evidence. Same class as the corrupt PNG and the stale dates.
final Map<String, Object?> _profileUnrated = <String, Object?>{
  ..._profile,
  'rating': 0,
  'rating_count': 0,
};

final Map<String, Object?> _profileWithPhotos = <String, Object?>{
  ..._profile,
  'images': <Object>[_imageJson(), _imageJson(cover: false, position: 1)],
};

/// EVERY IMAGE IN A GOLDEN IS A REAL, DECODABLE ONE.
///
/// `flutter_test` answers every HTTP request with a 400 and opens no socket,
/// so the real `CachedNetworkImageProvider` draws nothing — indistinguishable
/// from the designed empty state. A golden named "with photos" would picture a
/// venue without any and pass forever. Overriding the seam is what makes the
/// picture mean what its name says.
/// The results page, with a cover on every row.
final Map<String, Object?> _resultsPageWithCovers = <String, Object?>{
  ..._resultsPage,
  'results': [
    for (final r in _resultsPage['results']! as List<Object?>)
      <String, Object?>{...r! as Map<String, Object?>, 'cover': _imageJson()},
  ],
};

final Override _fixtureImages =
    networkImageFactoryProvider.overrideWithValue((_) => fixtureImage());

/// A saved venue, as the API serves it.
Map<String, Object?> _savedRow(String id, String en, String ar) => <String, Object?>{
      'id': id,
      'slug': 'saved-$id',
      'name_en': en,
      'name_ar': ar,
      'cuisines': <String>['levantine'],
      'neighborhood': 'Zamalek',
      'city': 'Cairo',
      'price_band': 3,
      'rating': 4.8,
      'rating_count': 312,
      'cover': _imageJson(),
      'saved_at': '${kFutureDate}T18:00:00.000Z',
    };


/// One notification, as the API serves it.
Map<String, Object?> _notification(
  String id,
  String type,
  Map<String, String> data, {
  bool read = false,
}) =>
    <String, Object?>{
      'id': id,
      'type': type,
      'data': data,
      'created_at': '${kFutureDate}T18:00:00.000Z',
      'read_at': read ? '${kFutureDate}T19:00:00.000Z' : null,
    };

/// EVERY KIND, INCLUDING ONE THIS BUILD HAS NEVER HEARD OF.
///
/// `future_kind_from_a_newer_server` is in the fixture on purpose. The app on a
/// diner's phone is whatever they last updated to, so a type added next month
/// arrives at a client built today — and the golden is what proves it is
/// SKIPPED rather than drawn as a blank row. Without it the "unknown renders
/// nothing" branch has no picture and no witness.
final Map<String, Object?> _notificationFeed = <String, Object?>{
  'items': <Object>[
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000001',
      'reservation_cancelled_by_venue',
      <String, String>{
        'reservation_id': '22222222-2222-4222-8222-222222222222',
        'venue': 'Layali Lounge',
        'venue_ar': 'ليالي لاونج',
        'date': kFutureDate,
        'time': '21:00',
        'reason': 'A burst pipe in the kitchen',
      },
    ),
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000002',
      'waitlist_offer',
      <String, String>{
        'waitlist_id': '33333333-3333-4333-8333-333333333333',
        'venue': 'El Fishawy',
        'venue_ar': 'الفيشاوي',
        'date': kFutureDate,
        'time': '20:30',
      },
    ),
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000003',
      'reservation_reminder_24h',
      <String, String>{
        'reservation_id': '22222222-2222-4222-8222-222222222223',
        'venue': 'Zooba',
        'venue_ar': 'زوبا',
        'date': kFutureDate,
        'time': '19:00',
      },
      read: true,
    ),
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000004',
      'reservation_confirmed',
      <String, String>{
        'reservation_id': '22222222-2222-4222-8222-222222222224',
        'venue': 'Layali Lounge',
        'venue_ar': 'ليالي لاونج',
        'date': kFutureDate,
        'time': '21:00',
        'party': '4',
        'code': 'SHR-8241',
      },
      read: true,
    ),
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000005',
      'waitlist_offer_expired',
      <String, String>{
        'waitlist_id': '33333333-3333-4333-8333-333333333334',
        'venue': 'El Fishawy',
        'venue_ar': 'الفيشاوي',
        'date': kFutureDate,
      },
      read: true,
    ),
    _notification(
      'aaaaaaaa-0000-4000-8000-000000000006',
      'future_kind_from_a_newer_server',
      <String, String>{'venue': 'Somewhere New'},
    ),
  ],
  // 3, not 6: three of the six carry a `read_at`, and the badge on the Account
  // row is drawn from THIS number rather than counted from the list.
  'unread_count': 3,
};

/// `GET /notifications` answers [feed]; `POST /notifications/read` answers the
/// mark-read shape.
///
/// ONE HANDLER, TWO PATHS, because the screen calls both — it marks read on
/// open. A single-response handler would answer the POST with a notification
/// LIST, which the generated client would fail to parse, and the failure would
/// surface as an error state in a golden named "list".
Object? Function(String, String, Map<String, String>?) _notificationsHandler(
  Map<String, Object?> feed,
) =>
    (method, path, _) {
      if (method == 'POST') {
        return <String, Object?>{'marked': 0, 'unread_count': feed['unread_count']};
      }
      return feed;
    };

final List<Object> _savedList = <Object>[
  _savedRow('11111111-1111-4111-8111-111111111111', 'Layali Lounge', 'ليالي لاونج'),
  _savedRow('11111111-1111-4111-8111-111111111112', 'El Fishawy', 'الفيشاوي'),
  _savedRow('11111111-1111-4111-8111-111111111113', 'Zooba', 'زوبا'),
];

/// Never resolves, so `OnboardingSeen` stays null and Splash stays put.
class _NeverAnswers implements OnboardingSeenStore {
  @override
  Future<bool> read() => Completer<bool>().future;

  @override
  Future<void> markSeen() async {}
}

const String _venueId = '11111111-1111-4111-8111-111111111111';
const String _reservationId = '22222222-2222-4222-8222-222222222222';

/// A session, so the bookings screens render their signed-in half.
///
/// The store is overridden too: a golden must never reach a keystore, and on
/// the test host `flutter_secure_storage` has no platform channel at all.
/// A FIXED TODAY, so the seven-day strips are the same picture every day.
///
/// The move sheet's first golden held "8 9 10 11 12" — correct on the day it
/// was written and wrong by the following morning. See `todayProvider`.
final Override _fixedToday =
    todayProvider.overrideWithValue(DateTime.parse('${kFutureDate}T12:00:00.000Z'));

final List<Override> _signedIn = <Override>[
  sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
  currentSessionProvider.overrideWith(_SignedInSession.new),
];

class _SignedInSession extends CurrentSession {
  @override
  Session? build() => const Session(
        accessToken: 'golden',
        refreshToken: 'golden',
        userId: '99999999-9999-4999-8999-999999999999',
        fullName: 'Nour',
        phone: '+201000000000',
      );
}

class _PastTab extends BookingsView {
  @override
  String build() => 'past';
}

/// THE VENUE NAME FOLLOWS THE LOCALE, and that is the point of this fixture.
///
/// An Arabic diner sees «الفيشاوي», not "El Fishawy", so the Arabic cells have
/// to picture an Arabic name inside an Arabic sentence — that is the layout
/// that actually ships. The English cells keep the Latin name, which is also
/// the harder bidi case for anyone who checks the English string inside Arabic
/// prose separately.
class _ParkedSlot extends PendingBooking {
  _ParkedSlot(this.cell);

  final Cell cell;

  @override
  PendingSelection build(String restaurantId) => PendingSelection(
        restaurantId: _venueId,
        venueName: cell.locale.languageCode == 'ar' ? 'الفيشاوي' : 'El Fishawy',
        startsAt: '${kFutureDate}T18:00:00.000Z',
        slotLabel: '20:30',
        date: kFutureDate,
        partySize: 4,
      );
}

class _AwaitingCode extends SignIn {
  @override
  SignInState build() => const SignInCode(
        challenge: OtpChallenge(
          challengeId: 'test-challenge-handle',
          phone: '+20 100 000 0000',
        ),
      );
}

class _LockedOut extends SignIn {
  @override
  SignInState build() => const SignInCode(
        challenge: OtpChallenge(
          challengeId: 'test-challenge-handle',
          phone: '+20 100 000 0000',
        ),
        failure: ConflictFailure(code: 'too_many_attempts', requestId: 'req_golden'),
      );
}

/// Tap a control by its LOCALISED label.
///
/// `find.text('Full menu')` found nothing in the two Arabic cells, where the
/// same control reads «المنيو كامل» — and a golden that fails to open the sheet
/// it is named after pictures the screen behind it, which looks like a
/// perfectly good screenshot.
///
/// The existing workaround in this file taps `find.byType(SahraChip).at(1)`,
/// which is position-dependent and breaks when a chip is inserted. Reading the
/// live `AppLocalizations` off the tree costs three lines and survives both.
Future<void> _tapLabel(
  WidgetTester tester,
  String Function(AppLocalizations) pick, {
  bool scroll = false,
}) async {
  final BuildContext context = tester.element(find.byType(VenueScreen));
  final Finder target = find.text(pick(AppLocalizations.of(context))).first;
  if (scroll) {
    await tester.scrollUntilVisible(target, 300);
    // SETTLE BEFORE TAPPING. A list that is still moving claims the next tap
    // to stop itself, so the control never fires — and the golden then shows
    // the page behind the sheet it is named after, which looks like a
    // perfectly good screenshot. That is exactly what `Reviews/sheet`
    // pictured on its first run.
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

List<Override> _transport(
  Object? Function(String, String, Map<String, String>?) handler,
) =>
    <Override>[
      transportProvider.overrideWithValue(FakeTransport(handler)),
      // Every case funnels through here, so every case gets a fixed clock.
      _fixedToday,
      // AND A FIXED POSITION. `geolocator` is a platform channel; in a test
      // binding it either throws or hangs for the eight-second timeout, per
      // cell, in four cells. Overriding here rather than per case means a
      // screen added tomorrow cannot forget it — the same reason the clock is
      // here.
      //
      // `refused`, not a position: the DEFAULT state of every golden is a
      // diner who has not shared one, which is what almost every diner is.
      // The cases that want a position say so.
      locationSourceProvider.overrideWithValue(
        const FixedLocationSource.refused(LocationOutcome.denied),
      ),
      // AND A FAKE PUSH SOURCE, here for the same reason as the clock and the
      // position: `firebase_messaging` is a platform channel that does not
      // exist in a test binding. The real one degrades to `unavailable` rather
      // than throwing, so nothing broke — it just printed two lines of
      // "No Firebase App '[DEFAULT]'" into every run that reached the
      // confirmation screen, which is noise that trains people to ignore
      // output.
      //
      // Centralised rather than per case so a screen added tomorrow cannot
      // forget it, and so `push_test.dart` can swap in its own counting
      // instance by listing its override AFTER these.
      pushTokenSourceProvider.overrideWithValue(FakePushTokenSource()),
    ];

/// A criteria notifier that starts with text already typed, so the golden
/// pictures a screen mid-use rather than one waiting for input.
class _TypedQuery extends SearchCriteria {
  _TypedQuery(this._text);
  final String _text;

  @override
  SearchQuery build() => SearchQuery(text: _text);
}

final Map<String, Object?> _emptyPage = <String, Object?>{
  'results': <Object>[],
  'next_cursor': null,
  'estimated_total': 0,
  'availability_filtered': false,
};

final Map<String, Object?> _resultsPage = <String, Object?>{
  'results': <Object>[
    <String, Object?>{
      'id': _venueId,
      'slug': 'layali-lounge-zamalek',
      'name_en': 'Layali Lounge',
      'name_ar': 'ليالي لاونج',
      'cuisines': <String>['levantine'],
      'neighborhood': 'Zamalek',
      'price_band': 3,
      'rating': 4.8,
      'rating_count': 312,
      'next_available': <String>['21:00', '21:30'],
    },
    <String, Object?>{
      'id': '33333333-3333-4333-8333-333333333333',
      'slug': 'el-fishawy-khan',
      'name_en': 'El Fishawy',
      'name_ar': 'الفيشاوي',
      'cuisines': <String>['egyptian'],
      'neighborhood': 'Khan el-Khalili',
      'price_band': 1,
      'rating': 4.5,
      'rating_count': 2841,
    },
  ],
  'next_cursor': null,
  'estimated_total': 2,
  'availability_filtered': true,
};

final Map<String, Object?> _profile = <String, Object?>{
  'id': _venueId,
  'slug': 'layali-lounge-zamalek',
  'name_en': 'Layali Lounge',
  'name_ar': 'ليالي لاونج',
  'description_en': 'A Nile-side terrace built for long evenings — mezze, charcoal '
      'grills and live oud after ten.',
  'description_ar': 'تراس على النيل متصمم للسهرات الطويلة — مقبّلات، مشويات على الفحم، '
      'وعود حي بعد العاشرة.',
  'cuisines': <String>['levantine', 'egyptian'],
  'neighborhood': 'Zamalek',
  'city': 'Cairo',
  'address_en': '26th of July St, Zamalek',
  'address_ar': 'شارع 26 يوليو، الزمالك',
  'lat': 30.0622,
  'lng': 31.2185,
  'price_band': 3,
  'rating': 4.8,
  'rating_count': 312,
  'phone': '+20 2 2735 0000',
  'amenities': <String>['outdoor', 'shisha', 'nile_view'],
  'timezone': 'Africa/Cairo',
  'booking_mode': 'instant',
  // REQUIRED by the wire model. A venue with no photos is the ordinary case
  // (doc 10 §3b — they arrive by hand), and `SahraPhoto` draws the reference's
  // mashrabiya placeholder for it rather than a broken image.
  'images': <Object>[],
  'hours': <Object>[
    for (var day = 0; day < 7; day++)
      <String, Object?>{
        'day_of_week': day,
        'specific_date': null,
        'name_en': 'Dinner',
        'name_ar': 'العشاء',
        'opens_at': '18:00',
        'closes_at': '23:30',
        'spans_midnight': false,
      },
  ],
};

Map<String, Object?> _reservation({
  required String status,
  bool needsAcknowledgement = false,
  String? cancelledBy,
  String? cancelReason,
  String date = kFutureDate,
  String? occasion,
  String? specialRequests,
  /// Group D — whether the SERVER says this visit can be reviewed. Named here
  /// so a fixture cannot accidentally assert the review CTA into existence.
  bool canReview = false,
}) =>
    <String, Object?>{
      'id': _reservationId,
      'code': 'SAH-7K2M',
      'status': status,
      'source': 'app',
      'starts_at': '${date}T18:00:00.000Z',
      'ends_at': '${date}T19:30:00.000Z',
      // The venue's wall clock, as the server computes it — NOT derived here
      // from starts_at, which would quietly rebuild the timezone bug these
      // fields exist to prevent.
      'date': date,
      'time': '21:00',
      'party_size': 2,
      'needs_acknowledgement': needsAcknowledgement,
      // Group D. The SERVER decides this; a fixture that
      // omitted it would be testing a response shape the API
      // never sends.
      'can_review': canReview,
      'review_id': null,
      'cancelled_by': cancelledBy,
      'cancelled_at': cancelledBy == null ? null : '${date}T09:00:00.000Z',
      'cancel_reason': cancelReason,
      'occasion': occasion,
      'special_requests': specialRequests,
      'restaurant': <String, Object?>{
        'id': _venueId,
        'slug': 'layali-lounge-zamalek',
        'name_en': 'Layali Lounge',
        'name_ar': 'ليالي لاونج',
        'neighborhood': 'Zamalek',
        'city': 'Cairo',
        'timezone': 'Africa/Cairo',
      },
    };

final Map<String, Object?> _confirmed = _reservation(
  status: 'confirmed',
  occasion: 'Anniversary',
  specialRequests: 'A quiet table away from the speakers, please.',
);

final Map<String, Object?> _pending = _reservation(status: 'pending', date: kFutureDateNext);

final Map<String, Object?> _completed = _reservation(status: 'completed', date: kPastDate);

final Map<String, Object?> _venueCancelled = _reservation(
  status: 'cancelled_by_restaurant',
  needsAcknowledgement: true,
  cancelledBy: 'restaurant',
  cancelReason: 'A burst pipe in the kitchen — we are closed tonight.',
);

final Map<String, Object?> _slots = <String, Object?>{
  'date': kFutureDate,
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[
    for (final t in <String>['18:00', '18:30', '19:00', '19:30', '20:00', '21:00'])
      <String, Object?>{
        'time': t,
        'startsAt': '${kFutureDate}T${t.split(':').first}:${t.split(':').last}:00.000Z',
        'zones': <String>['indoor', 'outdoor'],
      },
  ],
};

final Map<String, Object?> _noSlots = <String, Object?>{
  'date': kFutureDate,
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[],
};
