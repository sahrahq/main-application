import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/config/env/env.dart';
import 'package:sahra_customer_app/features/auth/domain/auth_repository.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_notifier.dart';
import 'package:sahra_customer_app/features/auth/presentation/sign_in_screen.dart';
import 'package:sahra_customer_app/shared/providers/app_providers.dart';

import '../support/fakes.dart';
import '../support/screen_harness.dart';

/// THE DEV HINT CANNOT REACH A DINER.
///
/// The sign-in screen tells the reviewer where the OTP went, because delivery
/// is stubbed (OPS-1) and otherwise the screen asks for a code that, as far as
/// the person holding the phone can tell, was never sent.
///
/// That note must be impossible in a release build. `Env.otpDeliveryIsStubbed`
/// alone cannot promise it — it defaults to true and is a `--dart-define`,
/// so one release built without flipping it would put "look in the API
/// console" in front of a real customer.
///
/// The predicate is a free function precisely so this file can assert its
/// whole truth table. A `kReleaseMode` branch buried in a `build` method is
/// unreachable from a test suite that only ever runs in debug — the guard
/// would be believed rather than known, which is the failure mode the
/// four-instance table in ENGINEERING-STANDARDS exists to name.
void main() {
  group('showsOtpDevHint — the whole truth table', () {
    test('release build NEVER shows it, whatever the define says', () {
      expect(showsOtpDevHint(releaseMode: true, stubbed: true), isFalse);
      expect(showsOtpDevHint(releaseMode: true, stubbed: false), isFalse);
    });

    test('debug build shows it only while delivery is stubbed', () {
      expect(showsOtpDevHint(releaseMode: false, stubbed: true), isTrue);
      expect(showsOtpDevHint(releaseMode: false, stubbed: false), isFalse);
    });

    test('release is the dominant term — this is the guard, stated as one', () {
      // Written separately from the rows above so the property is asserted
      // rather than implied by four literals that could all be edited.
      for (final stubbed in <bool>[true, false]) {
        expect(
          showsOtpDevHint(releaseMode: true, stubbed: stubbed),
          isFalse,
          reason: 'stubbed=$stubbed leaked the dev hint into a release build',
        );
      }
    });
  });

  testWidgets('the screen renders the note in this (debug) build', (tester) async {
    // THE GUARD ON THE GUARD. Everything above would pass identically if the
    // widget never rendered the note under any conditions — at which point the
    // reviewer is back to a code that seems not to have been sent, and the
    // truth table is protecting nothing.
    expect(kReleaseMode, isFalse, reason: 'this suite must run in debug');

    await tester.pumpWidget(
      screenHarness(
        Cell.enLight,
        SignInScreen(onClose: () {}),
        overrides: <Override>[
          transportProvider.overrideWithValue(FakeTransport((_, __, ___) => throw offline)),
          signInProvider.overrideWith(_AtCodeStep.new),
        ],
      ),
    );
    await stabilise(tester);

    expect(find.textContaining('API console'), findsOneWidget);
  });
}

class _AtCodeStep extends SignIn {
  @override
  SignInState build() => const SignInCode(
        challenge: OtpChallenge(
          challengeId: 'test-challenge-handle',
          phone: '+20 100 000 0000',
        ),
      );
}
