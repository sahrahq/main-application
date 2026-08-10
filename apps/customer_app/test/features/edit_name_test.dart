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

/// `PATCH /auth/me` from the Account screen.
///
/// THE POINT OF THIS FILE IS THE SESSION. The endpoint could work perfectly and
/// the diner would still see their old name everywhere, for the life of a
/// 30-day refresh token, because the session holds the app's only copy of a
/// display name. That failure looks exactly like the save not working, and it
/// is invisible to any test that stops at the response.
void main() {
  Future<ProviderContainer> pumpAccount(
    WidgetTester tester, {
    required FakeTransport transport,
    String name = 'Nour Hassan',
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        transportProvider.overrideWithValue(transport),
        sessionStoreProvider.overrideWithValue(
          InMemorySessionStore(
            Session(
              accessToken: 'a',
              refreshToken: 'r',
              userId: 'u1',
              fullName: name,
              phone: '+201000000000',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/account',
      routes: buildRouter().configuration.routes,
    );
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
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  Map<String, Object?> user(String fullName) => <String, Object?>{
        'id': 'u1',
        'phone': '+201000000000',
        'email': null,
        'fullName': fullName,
        'locale': 'en',
        'status': 'active',
        'roles': <String>['customer'],
      };

  testWidgets('THE EDIT ROW IS REACHABLE FROM THE ACCOUNT TAB', (tester) async {
    // `PATCH /auth/me` had no caller before this row. A capability nothing
    // calls is indistinguishable from one that does not exist.
    final transport = FakeTransport((method, path, _) {
      throw StateError('unexpected $method $path');
    });

    await pumpAccount(tester, transport: transport);
    expect(find.text('Edit name'), findsOneWidget);
  });

  testWidgets('the sheet opens with the CURRENT name already in it', (tester) async {
    // An empty field would make a correction into a re-entry, and re-entry is
    // how somebody ends up with a blank or a half-typed name at the door.
    final transport = FakeTransport((method, path, _) {
      throw StateError('unexpected $method $path');
    });

    await pumpAccount(tester, transport: transport);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, 'Nour Hassan');
  });

  testWidgets('saving sends the trimmed name and NO email', (tester) async {
    // The email chain is paused at step 3. `UpdateProfileDto` has no field for
    // one, so this cannot regress by accident — but the server refuses an
    // `email` with a 400, and a client that started sending one would break
    // every save rather than fail quietly.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/auth/me') return user('Nour H. Hassan');
      throw StateError('unexpected $method $path');
    });

    await pumpAccount(tester, transport: transport);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  Nour H. Hassan  ');
    await tester.tap(find.widgetWithText(SahraButton, 'Save'));
    await tester.pumpAndSettle();

    final body = transport.bodyFor('/v1/auth/me')! as Map<String, Object?>;
    expect(body['fullName'], 'Nour H. Hassan');
    expect(body.containsKey('email'), isFalse);
  });

  testWidgets('THE SCREEN SHOWS THE NEW NAME AFTERWARDS', (tester) async {
    // The session, not the response. This is the assertion the whole file is
    // for: the database write can succeed and the diner still read their old
    // name until they sign out and back in.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/auth/me') return user('Nour H. Hassan');
      throw StateError('unexpected $method $path');
    });

    final container = await pumpAccount(tester, transport: transport);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nour H. Hassan');
    await tester.tap(find.widgetWithText(SahraButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Nour H. Hassan'), findsOneWidget);
    expect(container.read(currentSessionProvider)?.fullName, 'Nour H. Hassan');
  });

  testWidgets("it shows the SERVER's name, not the typed one", (tester) async {
    // If the server ever trims, normalises or truncates, the screen must show
    // what is stored. Displaying what was typed would let the two drift with
    // nothing to notice it.
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/auth/me') return user('Server Normalised');
      throw StateError('unexpected $method $path');
    });

    final container = await pumpAccount(tester, transport: transport);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'whatever i typed');
    await tester.tap(find.widgetWithText(SahraButton, 'Save'));
    await tester.pumpAndSettle();

    expect(container.read(currentSessionProvider)?.fullName, 'Server Normalised');
  });

  testWidgets('A REFUSED SAVE KEEPS THE SHEET OPEN AND THE OLD NAME', (tester) async {
    final transport = FakeTransport((method, path, _) {
      if (path == '/v1/auth/me') throw envelope(400, 'validation_failed');
      throw StateError('unexpected $method $path');
    });

    final container = await pumpAccount(tester, transport: transport);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'N');
    await tester.tap(find.widgetWithText(SahraButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Your name'), findsOneWidget, reason: 'the sheet closed on a failure');
    expect(container.read(currentSessionProvider)?.fullName, 'Nour Hassan');
  });
}
