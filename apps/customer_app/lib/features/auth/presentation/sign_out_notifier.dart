import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';

part 'sign_out_notifier.g.dart';

/// Signing out. The state is "is it in flight", because that is all a screen
/// needs to know.
///
/// THE LOCAL SESSION IS CLEARED EVEN IF THE SERVER CALL FAILS, and that order
/// is deliberate. A diner who taps sign out on a phone with no signal, or
/// hands the handset to someone, must not still be signed in because a POST
/// timed out. The refresh token is revoked server-side when the call succeeds;
/// when it does not, the token remains valid until it expires — which is the
/// same exposure as a phone that is simply switched off, and strictly less bad
/// than a screen that refuses to log out.
@riverpod
class SignOut extends _$SignOut {
  @override
  bool build() => false;

  Future<void> signOut() async {
    if (state) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    state = true;
    try {
      await ref.read(authRepositoryProvider).signOut(
            refreshToken: session.refreshToken,
            // No device token yet — push registration is NOTIFY-1 Stage 2 and
            // nothing has one to send. Passing null is honest; the endpoint
            // treats it as "revoke the session, no handset to unregister".
            deviceToken: null,
          );
    } on Failure {
      // Swallowed on purpose. See the class note: the local clear below is
      // what the diner asked for and it happens either way.
    } finally {
      await ref.read(currentSessionProvider.notifier).signOut();
      state = false;
    }
  }
}
