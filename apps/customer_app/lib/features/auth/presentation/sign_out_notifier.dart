import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/push/push_registration.dart';

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
      // THE PUSH TOKEN GOES FIRST, and it goes even if the sign-out below
      // fails. A token left attached to a signed-out account sends that
      // person's next reservation notification to whoever is holding the
      // handset — on a shared or resold phone that is a privacy incident, not
      // an annoyance. It was `deviceToken: null` with a note saying "nothing
      // has one to send" until Stage 2 gave the client a token.
      await ref.read(pushRegistrarProvider.notifier).revokeOnSignOut();

      await ref.read(authRepositoryProvider).signOut(
            refreshToken: session.refreshToken,
            // Revoked separately above, through `DELETE /devices`, so it is
            // gone whether or not this call succeeds. Threading it here as
            // well would revoke it twice on success and not at all on the
            // failure path that matters.
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
