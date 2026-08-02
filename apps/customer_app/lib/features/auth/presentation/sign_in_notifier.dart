import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session.dart';
import '../../../core/error/failure.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/session_providers.dart';
import '../domain/auth_repository.dart';

part 'sign_in_notifier.g.dart';

/// Where the sign-in screen is. Sealed, so the screen's `switch` is complete.
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

class SignInDone extends SignInState {
  const SignInDone();
}

/// One notifier for the whole screen (doc 07 §5), side effects only here.
@riverpod
class SignIn extends _$SignIn {
  @override
  SignInState build() => const SignInPhone();

  /// Ask for a code. One action; the repository decides sign-in vs register.
  Future<void> requestCode({required String phone, required String fullName}) async {
    state = const SignInSending();
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestCode(phone: phone, fullName: fullName);
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
      final signedIn =
          await ref.read(authRepositoryProvider).verify(challenge: current.challenge, code: code);

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
    } on Failure catch (f) {
      // Back to the CODE step, not to the phone step. A wrong digit must not
      // cost the diner their place — and the 15-minute lock (doc 11 flow 1)
      // arrives here too, where its copy explains that a new code will not
      // help.
      state = SignInCode(challenge: current.challenge, failure: f);
    }
  }

  Future<void> resend() async {
    final current = state;
    if (current is! SignInCode) return;

    state = SignInCode(challenge: current.challenge, resending: true);
    try {
      await ref.read(authRepositoryProvider).resend(current.challenge);
      state = SignInCode(challenge: current.challenge);
    } on Failure catch (f) {
      // The 3-per-10-minutes phone limit lands here. Shown, not swallowed:
      // a resend button that silently does nothing is worse than one that
      // says why.
      state = SignInCode(challenge: current.challenge, failure: f);
    }
  }

  /// Back to the number, e.g. after typing it wrong.
  void changePhone() => state = const SignInPhone();
}
