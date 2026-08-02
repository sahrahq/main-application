import 'package:flutter/material.dart';
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
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';

import 'support/fakes.dart';
import 'support/screen_harness.dart';

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
    overrides: (_) => _transport((_, __, ___) => _profile),
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
      startsAt: '2026-08-05T18:00:00.000Z',
      partySize: 2,
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
    overrides: (_) => <Override>[
      ..._transport((_, __, ___) => throw offline),
      pendingBookingProvider(_venueId).overrideWith(() => _ParkedSlot()),
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
};

class ScreenCase {
  const ScreenCase({required this.build, required this.overrides, this.interactive = true});

  final Widget Function(Cell) build;
  final List<Override> Function(Cell) overrides;

  /// A screen with no tappable control. `Confirmed` has one (Done), so the
  /// only honest members here would be states that genuinely offer nothing —
  /// listed explicitly rather than inferred, because "this one has no action"
  /// is exactly the excuse a broken screen would offer.
  final bool interactive;
}

const String _venueId = '11111111-1111-4111-8111-111111111111';
const String _reservationId = '22222222-2222-4222-8222-222222222222';

/// A session, so the bookings screens render their signed-in half.
///
/// The store is overridden too: a golden must never reach a keystore, and on
/// the test host `flutter_secure_storage` has no platform channel at all.
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

class _ParkedSlot extends PendingBooking {
  @override
  PendingSelection build(String restaurantId) => const PendingSelection(
        restaurantId: _venueId,
        venueName: 'Layali Lounge',
        startsAt: '2026-08-05T18:00:00.000Z',
        slotLabel: '21:00',
        date: '2026-08-05',
        partySize: 2,
      );
}

class _AwaitingCode extends SignIn {
  @override
  SignInState build() => const SignInCode(
        challenge: OtpChallenge(
          userId: '99999999-9999-4999-8999-999999999999',
          phone: '+20 100 000 0000',
          isNewAccount: false,
        ),
      );
}

class _LockedOut extends SignIn {
  @override
  SignInState build() => const SignInCode(
        challenge: OtpChallenge(
          userId: '99999999-9999-4999-8999-999999999999',
          phone: '+20 100 000 0000',
          isNewAccount: false,
        ),
        failure: ConflictFailure(code: 'too_many_attempts', requestId: 'req_golden'),
      );
}

List<Override> _transport(
  Object? Function(String, String, Map<String, String>?) handler,
) =>
    <Override>[transportProvider.overrideWithValue(FakeTransport(handler))];

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
  String date = '2026-08-05',
  String? occasion,
  String? specialRequests,
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

final Map<String, Object?> _pending = _reservation(status: 'pending', date: '2026-08-09');

final Map<String, Object?> _completed = _reservation(status: 'completed', date: '2026-07-18');

final Map<String, Object?> _venueCancelled = _reservation(
  status: 'cancelled_by_restaurant',
  needsAcknowledgement: true,
  cancelledBy: 'restaurant',
  cancelReason: 'A burst pipe in the kitchen — we are closed tonight.',
);

final Map<String, Object?> _slots = <String, Object?>{
  'date': '2026-08-05',
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[
    for (final t in <String>['18:00', '18:30', '19:00', '19:30', '20:00', '21:00'])
      <String, Object?>{
        'time': t,
        'startsAt': '2026-08-05T${t.split(':').first}:${t.split(':').last}:00.000Z',
        'zones': <String>['indoor', 'outdoor'],
      },
  ],
};

final Map<String, Object?> _noSlots = <String, Object?>{
  'date': '2026-08-05',
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[],
};
