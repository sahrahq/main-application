import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';
import 'package:sahra_customer_app/features/restaurants/presentation/venue_screen.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/main.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';

import '../support/fakes.dart';
import '../support/fixture_dates.dart';
import 'package:sahra_customer_app/features/onboarding/presentation/onboarding_seen.dart';
import 'package:sahra_customer_app/shared/providers/locale_override.dart';

/// THE WALK-THROUGH, AS PICTURES.
///
/// CLAUDE.md requires the app to be walked as a diner at the end of every
/// batch, in Arabic and English, with a screenshot of every step — because a
/// written account of what should happen is what let three unreachable screens
/// ship with 461 passing tests.
///
/// This is the same journey `diner_journey_test.dart` asserts, run for the
/// pictures instead of the assertions, in both languages. It shares that
/// file's fixtures rather than copying them: two sets of canned responses that
/// drift apart would mean the walk-through pictures an app the journey test
/// never walks.
///
///     flutter test test/journey/journey_screenshots_test.dart --update-goldens
///
/// Output: `test/journey/walkthrough/<locale>/NN-step.png`.
void main() {
  for (final locale in <Locale>[const Locale('en'), const Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets(
      'walk-through [$tag]',
      (tester) async {
        // THE REAL COPY, LOADED FOR THIS LOCALE. Hardcoding Arabic labels in a
        // test would make the walk-through break every time the (still
        // UNREVIEWED) Arabic copy is edited — and the point of the walk-through
        // is to survive long enough to catch something else.
        final l10n = await AppLocalizations.delegate.load(locale);

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // ── CLEAR THE FOLDER FIRST ──────────────────────────────────
        //
        // These files are NUMBERED by position, and the position of every step
        // after an insertion changes. Adding two nodes in Group D renamed
        // eighteen of them — and the old names stayed on disk, so the folder
        // held 83 pictures of a 25-step walk, three versions of some steps,
        // some of them weeks old.
        //
        // The product owner opens this folder to see what the app does. A
        // folder where a third of the pictures are of a build that no longer
        // exists is worse than no folder: every one of them looks current.
        // ONLY WHEN WRITING. Deleting them on a COMPARE run makes every
        // `matchesGoldenFile` miss a file that was there a second ago — which
        // is what the first version of this did, and it turned a stable
        // walk-through into one that failed every time it was not updating.
        final Directory dir = Directory('test/journey/walkthrough/$tag');
        if (autoUpdateGoldenFiles && dir.existsSync()) {
          for (final FileSystemEntity f in dir.listSync()) {
            if (f is File && f.path.endsWith('.png')) f.deleteSync();
          }
        }

        var shot = 0;
        Future<void> capture(String name) async {
          shot++;
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'walkthrough/$tag/${shot.toString().padLeft(2, '0')}-$name.png',
            ),
          );
        }

        final store = InMemorySessionStore();
        var signedIn = false;

        final container = ProviderContainer(
          overrides: <Override>[
            transportProvider.overrideWithValue(
              FakeTransport((method, path, query) {
                if (path.contains('/restaurants/search')) return _searchPage;
                if (path.endsWith('/availability')) return _availability;
                // GROUP D, and BEFORE the profile branch — `/menus` and
                // `/reviews` both start with `/v1/restaurants/`, so the profile
                // catch-all was answering them with a restaurant. Neither
                // section rendered, the walk-through still produced a
                // plausible-looking venue page, and the `unstubbed` throw at
                // the bottom never fired because nothing was unstubbed.
                if (path.endsWith('/menus')) return _menus;
                if (path.endsWith('/reviews')) return _reviews;
                if (path.contains('/v1/restaurants/')) return _profile;
                if (path == '/v1/auth/request-otp') {
                  // A HANDLE AND NOTHING ELSE — identical for a number
                  // nobody has ever seen. That is AUTH-3 closed.
                  return <String, Object?>{'challengeId': 'journey-challenge'};
                }
                if (path == '/v1/auth/verify-otp') {
                  // `profile_needed`, because this is a diner who has never
                  // booked before — the cold-start path, and the only one that
                  // reaches the name step. A `signed_in` stub here would walk a
                  // returning diner and never touch the third step at all.
                  return <String, Object?>{'status': 'profile_needed'};
                }
                if (path == '/v1/auth/complete-registration') return _tokenPair;
                if (path == '/v1/reservations/holds') {
                  if (!signedIn) throw envelope(401, 'unauthenticated');
                  return _reservation('held');
                }
                if (path.endsWith('/confirm')) return _reservation('confirmed');
                if (path == '/v1/reservations') return <Object>[_myReservation];
                if (path == '/v1/reservations/$_reservationId') return _myReservation;
              // C-2.7. Empty is the honest state for a diner who signed up
              // during this very walk-through.
              if (path == '/v1/saved') return <Object>[];
                // The move picker reads its OWN grid, not the public one.
                if (path == '/v1/reservations/$_reservationId/available-slots') {
                  return _availability;
                }
                throw StateError('unstubbed: $method $path');
              }),
            ),
            sessionStoreProvider.overrideWithValue(store),
            // FIRST RUN, DETERMINISTICALLY. The secure store has no platform
            // channel on the test host, and a walk that depended on what it
            // happened to answer would drift between machines.
            onboardingSeenStoreProvider.overrideWithValue(InMemoryOnboardingSeenStore()),
            localePreferenceStoreProvider.overrideWithValue(InMemoryLocalePreferenceStore()),
          ],
        );
        addTearDown(container.dispose);
        container.listen(currentSessionProvider, (_, next) => signedIn = next != null);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SahraApp(localeOverride: locale),
          ),
        );
        await tester.pumpAndSettle();
        // FIRST RUN, photographed. Splash has already handed over by the time
        // the tree settles; onboarding is what a new diner actually sees.
        await capture('onboarding');
        await tester.tap(find.widgetWithText(SahraButton, l10n.onboardNext));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SahraButton, l10n.onboardNext));
        await tester.pumpAndSettle();
        await capture('onboarding-last');
        await tester.tap(find.widgetWithText(SahraButton, l10n.onboardStart));
        await tester.pumpAndSettle();

        await capture('cold-open');

        // Search is one tap from the home screen — and the walk photographs
        // both, because "the app opens on a home screen" is the change this
        // batch is judged by.
        await capture('home');
        await tester.tap(find.text(l10n.discoverSeeAll));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'layali');
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        await capture('search-results');

        final venue = tag == 'ar' ? 'ليالي لاونج' : 'Layali Lounge';

        await tester.tap(find.text(venue).first);
        await tester.pumpAndSettle();
        await capture('venue');

        // GROUP D. Two more nodes, and they are the two the diner actually
        // uses to decide: what the kitchen serves, and what the last four
        // people thought. Reached by SCROLLING and TAPPING — the menu sheet is
        // opened by the same control a diner would press.
        await tester.scrollUntilVisible(find.text(l10n.venueMenuFull), 300);
        await tester.pumpAndSettle();
        await capture('venue-menu');

        await tester.tap(find.text(l10n.venueMenuFull));
        await tester.pumpAndSettle();
        await capture('menu-sheet');

        // Back out the way a diner does.
        Navigator.of(tester.element(find.byType(VenueScreen))).pop();
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text(l10n.venueReviewsTitle), 300);
        await tester.pumpAndSettle();
        await capture('venue-reviews');

        // And back up to the booking bar, which is where the journey resumes.
        await tester.scrollUntilVisible(find.text(l10n.venueBook).last, -300);
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.venueBook).last);
        await tester.pumpAndSettle();
        await capture('slot-picker');

        await tester.tap(find.text('18:00'));
        await tester.pumpAndSettle();
        await capture('slot-chosen');

        await tester.tap(find.textContaining(l10n.bookConfirmFor(2, '18:00')));
        await tester.pumpAndSettle();
        await capture('sign-in-wall');

        // ONE FIELD on this step now — the name moved to a third step that only
        // appears for a number with no account.
        await tester.enterText(find.byType(TextField).first, '01000000000');
        await tester.tap(find.text(l10n.signInContinue));
        await tester.pumpAndSettle();
        await capture('code-step');

        await tester.enterText(find.byType(TextField).first, '123456');
        await tester.tap(find.text(l10n.signInVerify));
        await tester.pumpAndSettle();
        await capture('name-step');

        await tester.enterText(find.byType(TextField).first, 'Nour');
        await tester.tap(find.text(l10n.signInNameSubmit));
        await tester.pumpAndSettle();
        await capture('confirmed');

        await tester.tap(find.text(l10n.confirmedDone));
        await tester.pumpAndSettle();
        await capture('back-on-discover');

        await tester.tap(find.text(l10n.tabBookings));
        await tester.pumpAndSettle();
        await capture('my-bookings');

        await tester.tap(find.text(venue).first);
        await tester.pumpAndSettle();
        await capture('reservation-detail');

        // ── Group A: the two actions, in both languages ──────────────────────
        //
        // The buttons on this screen were disabled in the last walk-through, under
        // a line saying the feature did not exist. These frames are the evidence
        // that they are not any more — pictures of what does happen, not an
        // account of what should.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
        await tester.pumpAndSettle();
        await capture('reservation-actions');

        await tester.tap(find.widgetWithText(SahraButton, l10n.reservationModify));
        await tester.pumpAndSettle();
        await capture('move-sheet');

        await tester.tap(find.text('19:00'));
        await tester.pumpAndSettle();
        await capture('move-sheet-chosen');

        // Out of the sheet the way a thumb leaves it, so the next capture is not
        // taken through a scrim.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(SahraButton, l10n.reservationCancel));
        await tester.pumpAndSettle();
        await capture('cancel-sheet');

        await tester.tap(find.widgetWithText(SahraButton, l10n.cancelSheetKeep));
        await tester.pumpAndSettle();

        // ── And the profile edit, which has no reference of its own ──────────
        await tester.tap(find.text(l10n.tabAccount));
        await tester.pumpAndSettle();
        await capture('account');

        await tester.tap(find.text(l10n.accountEditName));
        await tester.pumpAndSettle();
        await capture('edit-name-sheet');

        // ── Group C: saved places, reached the ONLY way there is ─────────────
        //
        // Out of the sheet first, then the row. A screen with no route to it
        // is a screen that does not exist, and this walk is the picture of it
        // being reachable.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.accountSavedPlaces));
        await tester.pumpAndSettle();
        await capture('saved-places');

        // ignore: avoid_print
        print('WALK-THROUGH [$tag]: $shot screenshots in '
            '${Directory('test/journey/walkthrough/$tag').absolute.path}');
      },
      tags: 'golden',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}

/// Pinned FORWARD, like every other fixture in this suite.
///
/// A booking dated in the past renders as a settled one — no modify button —
/// so the walk would photograph a screen missing the thing it is there to
/// show, and nothing would say so. See `kFixtureDate` in the screen registry.
const String _userId = '99999999-9999-4999-8999-999999999999';
const String _reservationId = '22222222-2222-4222-8222-222222222222';

final Map<String, Object?> _searchPage = <String, Object?>{
  'results': <Object>[
    <String, Object?>{
      'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
      'slug': 'layali-lounge-zamalek',
      'name_en': 'Layali Lounge',
      'name_ar': 'ليالي لاونج',
      'cuisines': <String>['levantine'],
      'neighborhood': 'Zamalek',
      'price_band': 3,
      'rating': 4.8,
      'rating_count': 312,
      'next_available': <String>['18:00'],
    },
  ],
  'next_cursor': null,
  'estimated_total': 1,
  'availability_filtered': true,
};

/// GROUP D fixtures for the walk-through.
///
/// Small on purpose: this is a JOURNEY, not a menu screenshot. One category and
/// two dishes is enough to prove the section reaches the screen, and a single
/// review with a reply proves the reviews block does. The four-cell pictures
/// of the full thing live in the screen registry.
final List<Object> _menus = <Object>[
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
          <String, Object?>{
            'id': 'i1',
            'name_en': 'Charred halloumi & date honey',
            'name_ar': 'حلومي مشوي بعسل البلح',
            'description_en': null,
            'description_ar': null,
            'price': '320.00',
            'currency': 'EGP',
            'dietary_tags': <String>['vegetarian'],
            'image': null,
          },
          <String, Object?>{
            'id': 'i2',
            'name_en': 'Mixed grill for two',
            'name_ar': 'مشوي مشكل لفردين',
            'description_en': null,
            'description_ar': null,
            'price': '980.00',
            'currency': 'EGP',
            'dietary_tags': const <String>[],
            'image': null,
          },
        ],
      },
    ],
  },
];

final Map<String, Object?> _reviews = <String, Object?>{
  'summary': <String, Object?>{
    'rating': 4.8,
    'rating_count': 1,
    'breakdown': <String, Object?>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 1},
  },
  'results': <Object>[
    <String, Object?>{
      'id': 'rev-1',
      'rating': 5,
      'food_rating': 5,
      'service_rating': 5,
      'ambience_rating': null,
      'body': 'We sat on the terrace until the oud player finished.',
      'author': 'Nour H.',
      'created_at': '${kPastDate}T20:30:00.000Z',
      'owner_reply': 'Thank you Nour — the oud is every night after ten.',
      'owner_replied_at': '${kPastDate}T22:00:00.000Z',
    },
  ],
  'next_cursor': null,
};

final Map<String, Object?> _profile = <String, Object?>{
  'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
  'slug': 'layali-lounge-zamalek',
  'name_en': 'Layali Lounge',
  'name_ar': 'ليالي لاونج',
  'cuisines': <String>['levantine'],
  'neighborhood': 'Zamalek',
  'city': 'Cairo',
  'rating': 4.8,
  'rating_count': 312,
  'phone': '+20 2 2735 0000',
  'amenities': <String>['outdoor'],
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

final Map<String, Object?> _availability = <String, Object?>{
  'date': kFutureDate,
  'partySize': 2,
  'timezone': 'Africa/Cairo',
  'slots': <Object>[
    for (final t in <String>['18:00', '18:30', '19:00'])
      <String, Object?>{
        'time': t,
        'startsAt': '${kFutureDate}T$t:00.000Z',
        'zones': <String>['indoor'],
      },
  ],
};

final Map<String, Object?> _tokenPair = <String, Object?>{
  'accessToken': 'journey-access',
  'refreshToken': 'journey-refresh',
  'expiresIn': 900,
  'user': <String, Object?>{
    'id': _userId,
    'phone': '+201000000000',
    'fullName': 'Nour',
    'roles': <String>['customer'],
    'status': 'active',
    'locale': 'en',
  },
};

Map<String, Object?> _reservation(String status) => <String, Object?>{
      'id': _reservationId,
      'code': 'SAH-7K2M',
      'restaurantId': '4f743baa-3054-4fda-90ce-1a602faf1e77',
      'partySize': 2,
      'startsAt': '${kFutureDate}T18:00:00.000Z',
      'endsAt': '${kFutureDate}T19:30:00.000Z',
      'status': status,
      'source': 'app',
    };

final Map<String, Object?> _myReservation = <String, Object?>{
  'id': _reservationId,
  'code': 'SAH-7K2M',
  'status': 'confirmed',
  'source': 'app',
  'starts_at': '${kFutureDate}T18:00:00.000Z',
  'ends_at': '${kFutureDate}T19:30:00.000Z',
  'date': kFutureDate,
  'time': '21:00',
  'party_size': 2,
  'needs_acknowledgement': false,
  // Group D. The SERVER decides this; a fixture that
  // omitted it would be testing a response shape the API
  // never sends.
  'can_review': false,
  'review_id': null,
  'cancelled_by': null,
  'cancelled_at': null,
  'cancel_reason': null,
  'occasion': null,
  'special_requests': null,
  'restaurant': <String, Object?>{
    'id': '4f743baa-3054-4fda-90ce-1a602faf1e77',
    'slug': 'layali-lounge-zamalek',
    'name_en': 'Layali Lounge',
    'name_ar': 'ليالي لاونج',
    'neighborhood': 'Zamalek',
    'city': 'Cairo',
    'timezone': 'Africa/Cairo',
  },
};
