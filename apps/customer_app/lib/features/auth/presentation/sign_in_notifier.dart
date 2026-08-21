import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session.dart';
import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../domain/auth_repository.dart';

part 'sign_in_notifier.g.dart';

/// Where the sign-in screen is. Sealed, so the screen's `switch` is complete.
///
/// THREE STEPS, NOT TWO. Phone → code → (name, only when the number turns out
/// to belong to nobody). The name step is a state of this machine rather than a
/// route of its own, for the same reason the code step is: it is one flow, and
/// a diner who backs out of it should land where they started rather than in a
/// half-finished registration.
sealed class SignInState {
  const SignInState();
}

/// Asking for a phone number.
class SignInPhone extends SignInState {
  const SignInPhone({this.failure});

  /// The last attempt's failure, shown under the field.
  final Failure? failure;
}

class SignInSending extends SignInState {
  const SignInSending();
}

/// A code is in flight to the phone.
class SignInCode extends SignInState {
  const SignInCode({required this.challenge, this.failure, this.resending = false});

  final OtpChallenge challenge;
  final Failure? failure;
  final bool resending;
}

class SignInVerifying extends SignInState {
  const SignInVerifying(this.challenge);
  final OtpChallenge challenge;
}

/// The number is PROVED and belongs to nobody. Asking for a name.
///
/// Reached only after a correct code, so the challenge behind this state is
/// evidence the diner can read messages sent to that number. Nothing about an
/// account exists yet — there is no row until [SignIn.completeProfile].
class SignInNeedsName extends SignInState {
  const SignInNeedsName({required this.challenge, this.failure, this.submitting = false});

  final OtpChallenge challenge;
  final Failure? failure;
  final bool submitting;
}

class SignInDone extends SignInState {
  const SignInDone();
}

/// One notifier for the whole screen (doc 07 §5), side effects only here.
@riverpod
class SignIn extends _$SignIn {
  @override
  SignInState build() => const SignInPhone();

  /// Ask for a code. ONE CALL — see `AuthRepositoryImpl.requestCode`.
  ///
  /// No name is collected here any more. It used to be, because the client had
  /// to guess whether the number was new and `register` required a name up
  /// front; the name moved after verification, which is what let the request
  /// path stop looking anything up.
  Future<void> requestCode(String phone) async {
    state = const SignInSending();
    try {
      final challenge = await ref.read(authRepositoryProvider).requestCode(phone);
      state = SignInCode(challenge: challenge);
    } on Failure catch (f) {
      state = SignInPhone(failure: f);
    }
  }

  Future<void> verify(String code) async {
    final current = state;
    if (current is! SignInCode) return;

    state = SignInVerifying(current.challenge);
    try {
      final result =
          await ref.read(authRepositoryProvider).verify(challenge: current.challenge, code: code);

      switch (result) {
        case VerifiedSignedIn(:final session):
          await _store(session);
        case VerifiedNeedsProfile(:final challenge):
          state = SignInNeedsName(challenge: challenge);
      }
    } on Failure catch (f) {
      // Back to the CODE step, not to the phone step. A wrong digit must not
      // cost the diner their place — and the 15-minute lock (doc 11 flow 1)
      // arrives here too, where its copy explains that a new code will not
      // help.
      state = SignInCode(challenge: current.challenge, failure: f);
    }
  }

  /// Supply the name for a proved number.
  Future<void> completeProfile(String fullName) async {
    final current = state;
    if (current is! SignInNeedsName) return;

    state = SignInNeedsName(challenge: current.challenge, submitting: true);
    try {
      final session = await ref.read(authRepositoryProvider).completeRegistration(
            challenge: current.challenge,
            fullName: fullName,
          );
      await _store(session);
    } on Failure catch (f) {
      // Stays on the name step with the challenge intact. The verified window
      // is ten minutes, so a diner whose first attempt failed on a bad
      // connection can simply try again without re-doing the SMS.
      state = SignInNeedsName(challenge: current.challenge, failure: f);
    }
  }

  Future<void> resend() async {
    final current = state;
    if (current is! SignInCode) return;

    state = SignInCode(challenge: current.challenge, resending: true);
    try {
      // A NEW challenge comes back — the old code is dead the moment this
      // succeeds, so the state has to carry the new handle or the screen would
      // be answering a challenge that no longer exists.
      final refreshed = await ref.read(authRepositoryProvider).resend(current.challenge);
      state = SignInCode(challenge: refreshed);
    } on Failure catch (f) {
      // The 3-per-10-minutes phone limit lands here. Shown, not swallowed:
      // a resend button that silently does nothing is worse than one that
      // says why.
      state = SignInCode(challenge: current.challenge, failure: f);
    }
  }

  /// Back to the number, e.g. after typing it wrong.
  void changePhone() => state = const SignInPhone();

  Future<void> _store(SignedIn signedIn) async {
    await ref.read(currentSessionProvider.notifier).signIn(
          Session(
            accessToken: signedIn.accessToken,
            refreshToken: signedIn.refreshToken,
            userId: signedIn.userId,
            fullName: signedIn.fullName,
            phone: signedIn.phone,
          ),
        );
    state = const SignInDone();
  }
}
