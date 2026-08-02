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

/// The bottom navigation, and the round trip it owes.
///
/// Two guarantees, and they pull in opposite directions, which is why both are
/// tested rather than one:
///
///   - **Browsing is never gated.** The app opens on Discover signed out, and
///     nothing on launch asks for an account.
///   - **Bookings and Account are.** Tapping either signed out lands on
///     sign-in and, on success, RETURNS to the tab that was tapped — the same
///     contract as the pending-slot flow. Cancelling changes nothing.
void main() {
  final Map<String, Object?> emptyPage = <String, Object?>{
    'results': <Object>[],
    'next_cursor': null,
    'estimated_total': 0,
    'availability_filtered': false,
  };

  Map<String, Object?> tokenPair() => <String, Object?>{
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 900,
        'user': <String, Object?>{
          'id': 'u1',
          'phone': '+201000000000',
          'fullName': 'Nour',
          'roles': <String>['customer'],
          'status': 'active',
          'locale': 'en',
        },
      };

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    Session? session,
    FakeTransport? transport,
  }) async {
    final store = InMemorySessionStore();
    if (session != null) await store.write(session);

    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(
          transport ??
              FakeTransport((method, path, _) {
                if (path.contains('/search')) return emptyPage;
                if (path == '/v1/reservations') return <Object>[];
                if (path == '/v1/auth/request-otp') {
                  return <String, Object?>{'otpRequired': true, 'userId': 'u1'};
                }
                if (path == '/v1/auth/verify-otp') return tokenPair();
                throw StateError('unexpected $method $path');
              }),
        ),
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: SahraTheme.light(locale: const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...SahraTheme.localizationsDelegates,
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return router;
  }

  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('the app opens on Discover, signed out, with no sign-in wall', (tester) async {
    final router = await pumpApp(tester);

    expect(where(router), '/');
    expect(find.text('Sign in to book'), findsNothing);

    // And the navigation is actually there — the defect that started this was
    // three screens with no way to reach them.
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('every tab is reachable from every tab when signed in', (tester) async {
    final router = await pumpApp(
      tester,
      session: const Session(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        fullName: 'Nour',
        phone: '+201000000000',
      ),
    );
    // NOTHING READS THE SESSION HERE, deliberately. A `container.read` in the
    // test would start the restore itself and the assertions below would pass
    // because of the test rather than because of the app — which is exactly
    // what happened when this was being diagnosed.
    for (final hop in <List<String>>[
      <String>['Bookings', '/bookings'],
      <String>['Account', '/account'],
      <String>['Discover', '/'],
      <String>['Account', '/account'],
      <String>['Bookings', '/bookings'],
      <String>['Discover', '/'],
    ]) {
      await tester.tap(find.text(hop[0]));
      await tester.pumpAndSettle();
      expect(where(router), hop[1], reason: 'tapping ${hop[0]} went to ${where(router)}');
    }
  });

  testWidgets('signed out, tapping Bookings goes to sign-in and RETURNS to Bookings',
      (tester) async {
    final router = await pumpApp(tester);
    expect(where(router), '/');

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to book'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '01000000000');
    await tester.enterText(find.byType(TextField).at(1), 'Nour');
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // Back, and on the tab that was ASKED FOR — not on whatever the sign-in
    // screen's own default happens to be.
    expect(find.text('Sign in to book'), findsNothing);
    expect(where(router), '/bookings');
  });

  testWidgets('signed out, tapping Account goes to sign-in and RETURNS to Account',
      (tester) async {
    final router = await pumpApp(tester);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to book'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '01000000000');
    await tester.enterText(find.byType(TextField).at(1), 'Nour');
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(where(router), '/account');
    // The account screen's signed-in half, not its signed-out prompt.
    expect(find.text('Nour'), findsWidgets);
  });

  testWidgets('cancelling sign-in from a tab changes nothing at all', (tester) async {
    final router = await pumpApp(tester);
    expect(where(router), '/');

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to book'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Not now'));
    await tester.pumpAndSettle();

    // STILL ON DISCOVER. Not on a signed-out Bookings screen — that would be
    // asking someone to sign in twice, having just been told no.
    expect(where(router), '/');
    expect(find.text('Sign in to book'), findsNothing);
  });
}
