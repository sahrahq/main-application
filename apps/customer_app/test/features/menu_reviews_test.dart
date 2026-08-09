import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/reservations/presentation/reservation_screen.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/venue_screen.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';
import '../support/fixture_dates.dart';
import '../support/screen_harness.dart';

/// One pump, in ENGLISH.
///
/// The locale is stated rather than left to `LocaleSync`: `localeCodeProvider`
/// defaults to Arabic and the correction lands in a post-frame callback, so a
/// test that asserts on English copy races the fetch that already started.
/// Same reasoning, and the same fix, as `saved_test.dart`.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    screenHarness(Cell.enLight, screen, overrides: overrides),
  );
  await tester.pumpAndSettle();
}

/// GROUP D behaviour — the things a picture cannot show.
///
/// The goldens cover what the menu and the reviews LOOK like in four cells.
/// This covers what they DO: that the sheet is reachable by tapping, that the
/// price survives as the string the API sent, that a diner who cannot review is
/// not offered the control, and that a failure is shown where the diner is
/// looking rather than behind a sheet that closed.
void main() {
  const String venueId = '11111111-1111-4111-8111-111111111111';
  const String reservationId = '22222222-2222-4222-8222-222222222222';

  Map<String, Object?> profile() => <String, Object?>{
        'id': venueId,
        'slug': 'layali-lounge-zamalek',
        'name_en': 'Layali Lounge',
        'name_ar': 'ليالي لاونج',
        'description_en': null,
        'description_ar': null,
        'cuisines': <String>['levantine'],
        'neighborhood': 'Zamalek',
        'city': 'Cairo',
        'address_en': null,
        'address_ar': null,
        'lat': null,
        'lng': null,
        'price_band': 3,
        'rating': 4.25,
        'rating_count': 4,
        'phone': null,
        'website': null,
        'amenities': <String>[],
        'policies': null,
        'timezone': 'Africa/Cairo',
        'booking_mode': 'instant',
        'hours': <Object>[],
        'images': <Object>[],
      };

  Map<String, Object?> menuItem(String id, String en, String price) =>
      <String, Object?>{
        'id': id,
        'name_en': en,
        'name_ar': en,
        'description_en': null,
        'description_ar': null,
        'price': price,
        'currency': 'EGP',
        'dietary_tags': <String>['vegetarian'],
        'image': null,
      };

  List<Object> menus() => <Object>[
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
                menuItem('i1', 'Charred halloumi', '320.00'),
                menuItem('i2', 'Muhammara', '180.50'),
                menuItem('i3', 'Vine leaves', '190.00'),
                menuItem('i4', 'Fattoush', '140.00'),
                // A FIFTH, so the preview's "first four" is a real cut rather
                // than "all of them" wearing a limit.
                menuItem('i5', 'Labneh', '110.00'),
              ],
            },
          ],
        },
      ];

  Map<String, Object?> reviews({int count = 1}) => <String, Object?>{
        'summary': <String, Object?>{
          'rating': count == 0 ? 0 : 4.25,
          'rating_count': count,
          'breakdown': <String, Object?>{
            '1': 0,
            '2': 0,
            '3': 0,
            '4': 0,
            '5': count,
          },
        },
        'results': <Object>[
          for (var i = 0; i < count; i++)
            <String, Object?>{
              'id': 'rev-$i',
              'rating': 5,
              'food_rating': null,
              'service_rating': null,
              'ambience_rating': null,
              'body': 'Lovely evening.',
              'author': 'Nour H.',
              'created_at': '${kPastDate}T20:00:00.000Z',
              'owner_reply': null,
              'owner_replied_at': null,
            },
        ],
        'next_cursor': null,
      };

  FakeTransport venueTransport({
    List<Object>? menuList,
    Map<String, Object?>? reviewPage,
  }) =>
      FakeTransport((method, path, query) {
        if (path.endsWith('/menus')) return menuList ?? <Object>[];
        if (path.endsWith('/reviews')) return reviewPage ?? reviews(count: 0);
        return profile();
      });

  group('the menu', () {
    testWidgets('shows FOUR dishes in the preview, not the whole menu',
        (tester) async {
      // The reference draws four. A preview that quietly showed everything
      // would make "Full menu" a control that opens nothing new — the failure
      // this project keeps naming.
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(venueTransport(menuList: menus())),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Charred halloumi'), findsOneWidget);
      expect(find.text('Fattoush'), findsOneWidget);
      expect(find.text('Labneh'), findsNothing);
    });

    testWidgets('the price is the string the API sent, scale and all',
        (tester) async {
      // `180.50` through a JSON number and back is `180.5`, and a menu that
      // prints 180.5 where the kitchen prints 180.50 has lost the scale
      // CLAUDE.md rule 5 exists to keep. Asserted on the RENDERED text, which
      // is the only place the loss would show.
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(venueTransport(menuList: menus())),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('180.50'), findsOneWidget);
      expect(find.textContaining('180.5 '), findsNothing);
    });

    testWidgets('"Full menu" opens the rest of it', (tester) async {
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(venueTransport(menuList: menus())),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(VenueScreen));
      await tester.tap(find.text(AppLocalizations.of(context).venueMenuFull));
      await tester.pumpAndSettle();

      // The fifth dish is the proof: it exists only inside the sheet.
      expect(find.text('Labneh'), findsOneWidget);
    });

    testWidgets('a venue with no menu shows no menu heading at all',
        (tester) async {
      // Not an empty state. A heading over "nothing here yet" on a page that
      // already has content is worse than the absence — and most venues have no
      // menu, because every row of one is typed in by hand.
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(venueTransport()),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(VenueScreen));
      expect(find.text(AppLocalizations.of(context).venueMenuTitle), findsNothing);
    });
  });

  group('the reviews', () {
    testWidgets('a venue with none still gets the section, and the reason why',
        (tester) async {
      // The opposite call from the menu, and the reason is what the absence
      // MEANS: no menu is a gap in our data, no reviews is a fact about the
      // venue. The empty state is also the only place the verified-only rule
      // gets explained.
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(venueTransport()),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(VenueScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);
      expect(find.text(l10n.venueReviewsTitle), findsOneWidget);
      expect(find.text(l10n.reviewsEmptyTitle), findsOneWidget);
      // And no "All reviews" link, because there are none to see.
      expect(find.text(l10n.venueReviewsAll), findsNothing);
    });

    testWidgets('the author is only ever a first name and an initial',
        (tester) async {
      await _pump(
        tester,
        const VenueScreen(idOrSlug: 'layali-lounge-zamalek'),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            venueTransport(reviewPage: reviews()),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nour H.'), findsOneWidget);
    });
  });

  group('writing one', () {
    Map<String, Object?> reservation({required bool canReview, String? reviewId}) =>
        <String, Object?>{
          'id': reservationId,
          'code': 'SAH-7K2M',
          'status': 'completed',
          'source': 'app',
          'starts_at': '${kPastDate}T18:00:00.000Z',
          'ends_at': '${kPastDate}T19:30:00.000Z',
          'date': kPastDate,
          'time': '18:00',
          'party_size': 2,
          'special_requests': null,
          'occasion': null,
          'cancelled_by': null,
          'cancelled_at': null,
          'cancel_reason': null,
          'needs_acknowledgement': false,
          'can_review': canReview,
          'review_id': reviewId,
          'restaurant': <String, Object?>{
            'id': venueId,
            'slug': 'layali-lounge-zamalek',
            'name_en': 'Layali Lounge',
            'name_ar': 'ليالي لاونج',
            'neighborhood': 'Zamalek',
            'city': 'Cairo',
            'timezone': 'Africa/Cairo',
          },
        };

    testWidgets('the CTA appears only when the SERVER says it may',
        (tester) async {
      // `can_review` is computed by `review-eligibility.ts` and reported. A
      // client that re-derived it from the status would be a second copy of the
      // one invariant in Group D with no schema behind it.
      await _pump(
        tester,
        const ReservationScreen(id: reservationId),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            FakeTransport((_, __, ___) => reservation(canReview: false)),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ReservationScreen));
      expect(
        find.text(AppLocalizations.of(context).writeReviewCta),
        findsNothing,
        reason: 'The server said no and the button appeared anyway — which '
            'means the client is deciding, and it will disagree.',
      );
    });

    testWidgets('and it does when the server says it may', (tester) async {
      await _pump(
        tester,
        const ReservationScreen(id: reservationId),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            FakeTransport((_, __, ___) => reservation(canReview: true)),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ReservationScreen));
      expect(find.text(AppLocalizations.of(context).writeReviewCta), findsOneWidget);
    });

    testWidgets('an already-reviewed visit says so rather than showing nothing',
        (tester) async {
      // A diner who remembers writing one and finds no trace assumes it was
      // lost.
      await _pump(
        tester,
        const ReservationScreen(id: reservationId),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            FakeTransport(
              (_, __, ___) => reservation(canReview: false, reviewId: 'rev-1'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ReservationScreen));
      expect(
        find.text(AppLocalizations.of(context).reviewAlreadyWritten),
        findsOneWidget,
      );
    });

    testWidgets('the submit button is dead until a rating is picked',
        (tester) async {
      await _pump(
        tester,
        const ReservationScreen(id: reservationId),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            FakeTransport((_, __, ___) => reservation(canReview: true)),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ReservationScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tester.tap(find.text(l10n.writeReviewCta));
      await tester.pumpAndSettle();

      // Enabled-and-then-refused teaches a diner the app is unreliable, when
      // the app knew all along.
      expect(find.text(l10n.writeReviewNeedsRating), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l10n.writeReviewStar(4)).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.writeReviewNeedsRating), findsNothing);
    });

    testWidgets('a refusal is shown IN the sheet, not behind it', (tester) async {
      // The three real failures here — already reviewed, not eligible, too
      // early — are all things the diner needs to read while looking at what
      // they wrote. A SnackBar under a sheet that closed is not that.
      await _pump(
        tester,
        const ReservationScreen(id: reservationId),
        overrides: <Override>[
          transportProvider.overrideWithValue(
            FakeTransport((method, path, query) {
              if (method == 'POST' && path.endsWith('/reviews')) {
                throw envelope(409, 'review_already_exists');
              }
              return reservation(canReview: true);
            }),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ReservationScreen));
      final AppLocalizations l10n = AppLocalizations.of(context);

      await tester.tap(find.text(l10n.writeReviewCta));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l10n.writeReviewStar(5)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.writeReviewSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errReviewAlreadyExists), findsOneWidget);
      // And the sheet is still open, with the rating the diner chose still on
      // it.
      expect(find.text(l10n.writeReviewSubmit), findsOneWidget);
    });
  });
}
