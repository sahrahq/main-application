import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/shared/push/push_token_source.dart';

/// THE RETRY, AND THE THING IT IS FOR.
///
/// Measured on a real Xiaomi handset, 2026-08-11:
///
///     Push token read failed: [firebase_messaging/unknown]
///     java.io.IOException: SERVICE_NOT_AVAILABLE
///
/// Google documents that as TRANSIENT. We tried once and gave up, which turned
/// a temporary condition into a permanent one for that install — a diner whose
/// first token fetch lands on a bad moment never registers, ever, and nothing
/// tells anyone.
///
/// The classification is what these tests pin. The backoff durations are a
/// judgement call and are not asserted — testing that 8 seconds is 8 seconds
/// proves nothing and makes the schedule impossible to tune. What must not
/// drift is WHICH failures are retried, because retrying a permanent one burns
/// battery restating a fact and NOT retrying a transient one is the defect
/// that produced this file.
void main() {
  group('isRetryableFcmError — the classification is the load-bearing part', () {
    test('the measured failure is retryable', () {
      // Verbatim from the handset. If this ever stops matching, the defect
      // returns silently and the retry becomes decoration.
      expect(
        isRetryableFcmError(
          Exception('[firebase_messaging/unknown] java.io.IOException: '
              'java.util.concurrent.ExecutionException: java.io.IOException: '
              'SERVICE_NOT_AVAILABLE'),
        ),
        isTrue,
      );
    });

    test('transient server and network conditions are retryable', () {
      for (final String m in <String>[
        'INTERNAL_SERVER_ERROR',
        'TOO_MANY_REGISTRATIONS',
        'Unable to resolve host "fcmtoken.googleapis.com"',
        'Connection timed out',
      ]) {
        expect(isRetryableFcmError(Exception(m)), isTrue, reason: '$m should be retried');
      }
    });

    test('a PERMANENT failure is not retried', () {
      // Retrying these spends a diner's battery describing a fact that cannot
      // change without a different device or a different build.
      for (final String m in <String>[
        'MISSING_INSTANCEID_SERVICE',
        'No Firebase App [DEFAULT] has been created',
        'FIS_AUTH_ERROR: invalid API key',
      ]) {
        expect(isRetryableFcmError(Exception(m)), isFalse, reason: '$m must NOT be retried');
      }
    });

    test('matching is case-insensitive, because the plugin does not normalise', () {
      expect(isRetryableFcmError(Exception('service_not_available')), isTrue);
    });
  });

  group('FakePushTokenSource mirrors the contract the registrar depends on', () {
    test('a granted permission with NO token is the state that must persist', () {
      // The exact shape of the Xiaomi failure: permission granted, token null.
      // Before the fix this ended the run silently and nothing ever asked
      // again — `syncExistingToken` returned early and no caller existed to
      // call it on the next launch either.
      final FakePushTokenSource s =
          FakePushTokenSource(state: PushPermission.granted, tokenValue: null);
      expect(s.currentToken(), completion(isNull));
    });

    test('a token appears once the transient condition clears', () {
      final FakePushTokenSource s =
          FakePushTokenSource(state: PushPermission.granted, tokenValue: null);
      expect(s.currentToken(), completion(isNull));
      s.tokenValue = 'fcm-token-after-retry';
      expect(s.currentToken(), completion('fcm-token-after-retry'));
    });

    test('no token is offered without permission, whatever the value holds', () {
      final FakePushTokenSource s =
          FakePushTokenSource(state: PushPermission.denied, tokenValue: 'leaked');
      expect(s.currentToken(), completion(isNull));
    });
  });
}
