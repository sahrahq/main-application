import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/routes/routes.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/fakes.dart';

/// C-2.7 — saving a venue, from the diner's side.
///
/// DRIVEN THROUGH THE ROUTER, because every property here is about what a
/// thumb can reach and what happens after it lands: that the heart fills
/// before the server answers, that it goes back if the call fails, and that
/// the saved screen is reachable at all.
void main() {
  const venueId = '11111111-1111-4111-8111-111111111111';
  const otherId = '11111111-1111-4111-8111-111111111112';

  Map<String, Object?> savedRow(String id, String nameEn, String nameAr) => <String, Object?>{
        'id': id,
        'slug': 'venue-$id',
        'name_en': nameEn,
        'name_ar': nameAr,
        'cuisines': <String>['levantine'],
        'neighborhood': 'Zamalek',
        'city': 'Cairo',
        'price_band': 3,
        'rating': 4.8,
        'rating_count': 312,
        'cover': null,
        'saved_at': '2027-08-05T18:00:00.000Z',
      };

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required FakeTransport transport,
    String at = '/saved',
    Locale locale = const Locale('en'),
    bool signedIn = true,
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(transport),
        sessionStoreProvider.overrideWithValue(
          InMemorySessionStore(
            signedIn
                ? const Session(
                    accessToken: 'a',
                    refreshToken: 'r',
                    userId: 'u1',
                    fullName: 'Nour Hassan',
                    phone: '+201000000000',
                  )
                : null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: at,
      routes: buildRouter().configuration.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: SahraTheme.light(locale: locale),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...SahraTheme.localizationsDelegates,
          ],
        ),
      ),
    );
    // THE LOCALE IS SET EXPLICITLY, not left to `LocaleSync`.
    //
    // `localeCodeProvider` defaults to Arabic (the app is Arabic-first), and
    // `LocaleSync` corrects it from the widget tree in a POST-FRAME callback.
    // A fetch that starts before that callback runs resolves the name pair
    // with the default — which is exactly what happened here first time: an
    // English test rendering "ليالي لاونج".
    //
    // Worth naming rather than papering over: on a device the sync lands on
    // frame one and the fetch follows, so this is a test-timing artefact. But
    // it is the same ordering, and if a screen ever fetched inside `build`
    // before the first frame settled it would show the wrong language once.
    container.read(localeCodeProvider.notifier).set(locale.languageCode);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('THE SAVED SCREEN IS REACHABLE FROM THE ACCOUNT TAB', (tester) async {
    // A screen with no route to it is a screen that does not exist. This app
    // has shipped that failure once already.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/saved') return <Object>[];
      throw StateError('unexpected $method $path');
    });

    await pump(tester, transport: transport, at: '/account');
    expect(find.text('Saved places'), findsOneWidget);

    await tester.tap(find.text('Saved places'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsWidgets, reason: 'the saved screen did not open');
  });

  testWidgets('an empty list offers a way out, not a dead end', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/saved') return <Object>[];
      throw StateError('unexpected $method $path');
    });

    await pump(tester, transport: transport);

    expect(find.text('Nothing saved yet'), findsOneWidget);
    // An empty screen a diner chose to open, with nothing to do on it, is a
    // dead end. The action is the difference.
    expect(find.widgetWithText(SahraButton, 'Find somewhere'), findsOneWidget);
  });

  testWidgets('saved venues render as cards, newest first', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/saved') {
        return <Object>[
          savedRow(venueId, 'Layali Lounge', 'ليالي لاونج'),
          savedRow(otherId, 'El Fishawy', 'الفيشاوي'),
        ];
      }
      throw StateError('unexpected $method $path');
    });

    await pump(tester, transport: transport);

    expect(find.text('Layali Lounge'), findsOneWidget);
    expect(find.text('El Fishawy'), findsOneWidget);
    // The server orders; the client does not re-sort. Asserting the ORDER here
    // is what stops somebody "helpfully" sorting alphabetically later.
    final first = tester.getTopLeft(find.text('Layali Lounge'));
    final second = tester.getTopLeft(find.text('El Fishawy'));
    expect(first.dy <= second.dy, isTrue);
  });

  testWidgets('signed out, it asks for a sign-in rather than an empty grid', (tester) async {
    final transport = FakeTransport((method, path, _) {
      throw StateError('unexpected $method $path');
    });

    await pump(tester, transport: transport, signedIn: false);
    expect(find.text('Sign in to see your saved places'), findsOneWidget);
  });

  group('the heart on the venue screen', () {
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
          'rating': 4.8,
          'rating_count': 312,
          'phone': null,
          'website': null,
          'amenities': <String>[],
          'policies': null,
          'images': <Object>[],
          'timezone': 'Africa/Cairo',
          'booking_mode': 'instant',
          'hours': <Object>[],
        };

    testWidgets('IT FILLS BEFORE THE SERVER ANSWERS', (tester) async {
      // Optimistic. A save that waited for a round trip on a Cairo mobile
      // connection feels broken, and the diner taps again — which is exactly
      // why the endpoint is idempotent.
      // THE POST IS DELAYED ON PURPOSE. `FakeTransport` resolves on the
      // microtask queue, so without this the whole round trip completes inside
      // the first `pump()` and the optimistic window — the thing under test —
      // never exists to observe. The first version of this test asserted
      // against a state that had already been overwritten.
      var savePosted = false;
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/saved' && method == 'GET') {
          return savePosted ? <Object>[savedRow(venueId, 'Layali Lounge', 'ليالي لاونج')] : <Object>[];
        }
        if (path == '/v1/saved' && method == 'POST') {
          savePosted = true;
          return Future<Map<String, Object?>>.delayed(
            const Duration(milliseconds: 200),
            () => <String, Object?>{},
          );
        }
        if (path.contains('/restaurants/')) return profile();
        throw StateError('unexpected $method $path');
      });

      await pump(tester, transport: transport, at: '/r/layali-lounge-zamalek');

      final heart = find.byWidgetPredicate(
        (w) => w is SahraPhotoIconButton && w.icon == 'heart',
      );
      expect(heart, findsOneWidget, reason: 'no save control on the venue hero');
      expect(tester.widget<SahraPhotoIconButton>(heart).active, isFalse);

      await tester.tap(heart);
      // ONE pump, not settle: the point is the state BEFORE the round trip.
      await tester.pump();

      expect(
        tester.widget<SahraPhotoIconButton>(heart).active,
        isTrue,
        reason: 'the heart waited for the server',
      );

      // AN EXPLICIT DURATION, not `pumpAndSettle`. Settle advances only while
      // frames are scheduled, and a delayed Future schedules no frames — so it
      // returns before the timer fires and the test ends with it still
      // pending, which `flutter_test` reports as an error rather than a
      // failure. Pumping past the delay is what actually runs it.
      await tester.pump(const Duration(milliseconds: 300));
      expect(savePosted, isTrue);
    });

    testWidgets('AND IT ROLLS BACK WHEN THE SAVE FAILS', (tester) async {
      // An optimistic update that cannot roll back is a lie: the heart stays
      // filled, the venue is not saved, and the diner finds out when the list
      // is empty.
      final transport = FakeTransport((method, path, _) {
        if (path == '/v1/saved' && method == 'GET') return <Object>[];
        if (path == '/v1/saved' && method == 'POST') {
          // Delayed, so the optimistic state is observable before the failure
          // lands. See the note in the test above.
          return Future<Map<String, Object?>>.delayed(
            const Duration(milliseconds: 200),
            () => throw envelope(503, 'service_unavailable'),
          );
        }
        if (path.contains('/restaurants/')) return profile();
        throw StateError('unexpected $method $path');
      });

      await pump(tester, transport: transport, at: '/r/layali-lounge-zamalek');

      final heart = find.byWidgetPredicate(
        (w) => w is SahraPhotoIconButton && w.icon == 'heart',
      );
      await tester.tap(heart);
      await tester.pump();
      expect(tester.widget<SahraPhotoIconButton>(heart).active, isTrue);

      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<SahraPhotoIconButton>(heart).active,
        isFalse,
        reason: 'a failed save left the heart filled — the diner now believes '
            'the venue is in a list it is not',
      );

      // AND IT SAYS SO. A heart that quietly un-fills is a signal somebody
      // watching their thumb never sees.
      expect(find.textContaining('did not save'), findsOneWidget);
    });

    testWidgets('signed out there is NO heart, not a disabled one', (tester) async {
      // Saving needs an account. A heart that opens a sign-in wall is a
      // promise this screen has not earned.
      final transport = FakeTransport((method, path, _) {
        if (path.contains('/restaurants/')) return profile();
        throw StateError('unexpected $method $path');
      });

      await pump(
        tester,
        transport: transport,
        at: '/r/layali-lounge-zamalek',
        signedIn: false,
      );

      expect(
        find.byWidgetPredicate((w) => w is SahraPhotoIconButton && w.icon == 'heart'),
        findsNothing,
      );
    });
  });
}
