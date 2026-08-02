import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_customer_app/features/reservations/presentation/book_screen.dart';
import 'package:sahra_customer_app/features/reservations/presentation/confirmed_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_notifier.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/search_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/venue_screen.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

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
