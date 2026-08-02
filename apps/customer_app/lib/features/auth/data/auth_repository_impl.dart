import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/guarded.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._localeCode);

  final SahraApi _api;
  final String Function() _localeCode;

  /// ONE ACTION FOR THE DINER, TWO CALLS FOR THE SERVER.
  ///
  /// `POST /auth/request-otp` signs in a number that already has an account;
  /// `POST /auth/register` creates one. The screen must not ask "do you
  /// already have an account?" — nobody remembers, and asking a returning
  /// customer is a small insult.
  ///
  /// So: try sign-in, and fall through to registration on the 401 that means
  /// "no such number". That 401 is EXPECTED here and is not surfaced.
  ///
  /// Note what this does NOT do: it does not decide anything from the presence
  /// or absence of an account before acting. Both endpoints already answer
  /// identically-shaped responses, and the server's own enumeration behaviour
  /// (AUTH-3) is a known gap being closed at both doors together — this client
  /// must not become a third door.
  @override
  Future<OtpChallenge> requestCode({
    required String phone,
    required String fullName,
  }) async {
    try {
      final signIn = await guarded(
        () => _api.requestOtp(body: RequestOtpDto(phone: phone)),
      );
      return OtpChallenge(userId: signIn.userId, phone: phone, isNewAccount: false);
    } on AuthFailure catch (f) {
      // `invalid_credentials` here means "no account for this number", which
      // is not a failure — it is the other half of the same action.
      //
      // THE CODE IS CHECKED, NOT JUST THE CLASS. `account_unavailable` is also
      // a 401, and falling through on it would try to create a SECOND account
      // for a suspended person — silently undoing a suspension through the
      // sign-in screen.
      if (f.code != 'invalid_credentials') rethrow;

      final created = await guarded(
        () => _api.register(
          body: RegisterDto(
            phone: phone,
            fullName: fullName,
            locale: _localeCode(),
          ),
        ),
      );
      return OtpChallenge(userId: created.userId, phone: phone, isNewAccount: true);
    }
  }

  @override
  Future<SignedIn> verify({
    required OtpChallenge challenge,
    required String code,
  }) async {
    final pair = await guarded(
      () => _api.verifyOtp(
        body: VerifyOtpDto(
          userId: challenge.userId,
          code: code,
          // The purpose the challenge was ISSUED for. Challenges are keyed
          // `otp:{purpose}:{userId}`, so answering with the wrong one fails —
          // which is the separation that stops a registration code signing
          // somebody in.
          purpose: challenge.isNewAccount ? 'phone_verify' : 'login',
        ),
      ),
    );

    return SignedIn(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      userId: pair.user.id,
      fullName: pair.user.fullName,
      phone: pair.user.phone,
    );
  }

  @override
  Future<void> resend(OtpChallenge challenge) async {
    if (challenge.isNewAccount) {
      await guarded(() => _api.resendOtp(body: ResendOtpDto(userId: challenge.userId)));
      return;
    }
    // A sign-in challenge is re-issued by asking for one again: `resend-otp`
    // only re-sends the phone_verify code, and sending the wrong purpose would
    // hand the diner a code that cannot answer the challenge on screen.
    await guarded(() => _api.requestOtp(body: RequestOtpDto(phone: challenge.phone)));
  }

  @override
  Future<void> signOut({required String refreshToken, String? deviceToken}) async {
    await guarded(
      () => _api.logout(
        body: LogoutDto(
          refreshToken: refreshToken,
          // The push half of signing out. A token left live sends this
          // person's reservations to whoever holds the handset next.
          deviceToken: deviceToken,
        ),
      ),
    );
  }
}
