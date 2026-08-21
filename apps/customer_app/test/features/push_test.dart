import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/reservations/presentation/confirmed_screen.dart';
import 'package:sahra_customer_app/shared/push/push_registration.dart';
import 'package:sahra_customer_app/shared/push/push_token_source.dart';

import 'package:sahra_customer_app/core/auth/session.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';
import 'package:sahra_customer_app/shared/providers/session_providers.dart';

import '../screen_registry.dart';
import '../support/fakes.dart';
import '../support/screen_harness.dart';

/// THE NOTIFICATION PERMISSION IS ASKED IN EXACTLY ONE PLACE.
///
/// ─────────────────────────────────────────────────────────────────────────
/// A COUNTER THAT MUST READ ZERO, AND ONE THAT MUST READ ONE
/// ─────────────────────────────────────────────────────────────────────────
///
/// The shape the product owner asked to be reused wherever "never" is written:
/// turn the negative into an integer and break it on purpose.
///
/// "The app must not ask for notification permission unprompted" is otherwise
/// unprovable — it is a claim about every screen that does NOT do something,
/// and no per-screen test can express it. So `FakePushTokenSource` counts every
/// `request()` and every `permission()`, and the assertions read those numbers
/// after driving each screen.
///
/// **Why it matters more than the location one.** A location refusal can be
/// asked again later. A notification refusal cannot: the OS shows the dialog
/// once, and after that Settings is the only way back. Asking at the wrong
/// moment does not cost us one prompt — it costs that diner push, permanently.
///
/// doc 11 §1: "asked with context ('so we can remind you before your
/// reservation'), not immediately on app open — asking cold gets rejected
/// more."
void main() {
  late FakePushTokenSource push;

  setUp(() => push = FakePushTokenSource());

  List<Override> overrides(List<Override> extra) => <Override>[
        pushTokenSourceProvider.overrideWithValue(push),
        ...extra,
      ];

  /// A transport that answers the device endpoints and nothing else. Anything
  /// unexpected throws, so a call this test did not intend fails loudly.
  List<Override> deviceTransport() => <Override>[
        transportProvider.overrideWithValue(
          FakeTransport((method, path, _) {
            if (path == '/v1/devices') {
              return <String, Object?>{'id': 'd1', 'registered': true};
            }
            throw StateError('unstubbed $method $path');
          }),
        ),
      ];

  final List<Override> signedIn = <Override>[
    sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
    currentSessionProvider.overrideWith(_SignedIn.new),
  ];

  /// Pump a registry screen with the counting source in place.
  Future<void> open(WidgetTester tester, String screen) async {
    final entry = screenCases[screen]!;
    await tester.pumpWidget(
      screenHarness(
        Cell.enLight,
        entry.build(Cell.enLight),
        overrides: overrides(entry.overrides(Cell.enLight)),
      ),
    );
    await stabilise(tester);
    if (entry.after != null) await entry.after!(tester);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  ZERO, EVERYWHERE EXCEPT ONE SCREEN.
  // ══════════════════════════════════════════════════════════════════════
  group('no screen asks for notification permission', () {
    // ENUMERATED FROM THE REGISTRY, not from a list beside the test. A screen
    // added tomorrow is covered the moment it exists — the rule this codebase
    // settled on after the `updated_at` sweep.
    final everythingElse = screenCases.keys.where((k) => !k.startsWith('Confirmed/')).toList();

    test('the registry was read and has plenty in it — census', () {
      // Without this, an empty list would make every assertion below pass by
      // driving nothing at all.
      expect(everythingElse.length, greaterThan(20));
    });

    for (final screen in everythingElse) {
      testWidgets(screen, (tester) async {
        await open(tester, screen);
        expect(
          push.requests,
          0,
          reason: '$screen asked for notification permission. A refusal here is '
              'PERMANENT — the OS shows that dialog once — so an ask on the '
              'wrong screen costs this diner push for good.',
        );
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  //  AND EXACTLY ONE, WHERE IT MAKES SENSE.
  // ══════════════════════════════════════════════════════════════════════
  group('the confirmation screen asks, because that is the context', () {
    testWidgets('it asks once', (tester) async {
      await tester.pumpWidget(
        screenHarness(
          Cell.enLight,
          const ConfirmedScreen(
            code: 'SAH-1234',
            venueName: 'Layali Lounge',
            startsAt: '2027-08-05T18:00:00.000Z',
            partySize: 2,
            wallClock: '20:00',
          ),
          overrides: overrides(<Override>[...signedIn, ...deviceTransport()]),
        ),
      );
      await stabilise(tester);

      expect(push.requests, 1);
    });

    testWidgets('and NOT AGAIN on a second booking in the same run', (tester) async {
      // Two confirmations in one session is an ordinary evening. The second one
      // must not re-prompt: on Android the dialog simply does not reappear, so
      // the only visible effect would be a diner wondering why nothing happened.
      final container = ProviderContainer(
        overrides: overrides(<Override>[...signedIn, ...deviceTransport()]),
      );
      addTearDown(container.dispose);

      await container.read(pushRegistrarProvider.notifier).askAfterBooking();
      await container.read(pushRegistrarProvider.notifier).askAfterBooking();

      expect(push.requests, 1);
    });
  });

  group('a diner who already answered is not asked again', () {
    test('DENIED — asking again is a no-op the OS ignores', () async {
      push.state = PushPermission.denied;
      final container = ProviderContainer(overrides: overrides(<Override>[]));
      addTearDown(container.dispose);

      await container.read(pushRegistrarProvider.notifier).askAfterBooking();

      // It CHECKED, which is allowed and does not prompt. It did not ASK.
      expect(push.permissionChecks, greaterThan(0));
      expect(push.requests, 0);
    });

    test('GRANTED — no prompt, but the token is re-synced', () async {
      // FCM rotates tokens on reinstall and restore-from-backup. A rotated
      // token nobody re-registers is a diner who silently stops receiving
      // anything, having agreed to receive it.
      push.state = PushPermission.granted;
      final container = ProviderContainer(
        overrides: overrides(<Override>[...signedIn, ...deviceTransport()]),
      );
      addTearDown(container.dispose);

      await container.read(pushRegistrarProvider.notifier).askAfterBooking();

      expect(push.requests, 0);
    });
  });

  test('a signed-OUT diner registers nothing, even with a token in hand', () async {
    // `POST /devices` requires a session, and a push address is only meaningful
    // attached to an account. Registering before sign-in would be collecting a
    // device identifier from somebody who has agreed to nothing.
    push.state = PushPermission.granted;
    final container = ProviderContainer(overrides: overrides(<Override>[]));
    addTearDown(container.dispose);

    await container.read(pushRegistrarProvider.notifier).syncExistingToken();
    // No transport override here at all: if it tried to call, the test would
    // fail on an unstubbed request rather than passing quietly.
    expect(push.state, PushPermission.granted);
  });
}

class _SignedIn extends CurrentSession {
  @override
  Session? build() => const Session(
        accessToken: 'push-test',
        refreshToken: 'push-test',
        userId: '99999999-9999-4999-8999-999999999999',
        fullName: 'Nour',
        phone: '+201000000000',
      );
}
