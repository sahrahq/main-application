import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._localeCode);

  final SahraApi _api;
  final String Function() _localeCode;

  /// ONE CALL. The two-call dance is gone.
  ///
  /// This used to try `request-otp`, catch the 401 that meant "no such
  /// number", and fall through to `register` — checking the error CODE rather
  /// than just the class, so a suspended account did not accidentally get a
  /// second one. All of that has been deleted, because the 401 it branched on
  /// was AUTH-3: an enumeration oracle on Egyptian mobile numbers, on the path
  /// a returning diner takes every time they sign in.
  ///
  /// The server now looks nothing up at request time. There is no branch here
  /// because there is no longer a question to answer.
  @override
  Future<OtpChallenge> requestCode(String phone) async {
    final issued = await guarded(
      () => _api.requestOtp(body: RequestOtpDto(phone: phone)),
    );
    return OtpChallenge(challengeId: issued.challengeId, phone: phone);
  }

  @override
  Future<VerifyResult> verify({
    required OtpChallenge challenge,
    required String code,
  }) async {
    final outcome = await guarded(
      () => _api.verifyOtp(
        body: VerifyOtpDto(challengeId: challenge.challengeId, code: code),
        // `purpose` is gone. It used to be sent from here, which meant the
        // client chose which challenge its code answered; the purpose lives on
        // the stored challenge now and cannot be misdeclared.
      ),
    );

    // `status` is required and non-nullable in the generated model, so a
    // missing field is a parse error rather than a silent "not signed in".
    if (outcome.status == 'signed_in') {
      final pair = outcome.tokens;
      if (pair == null) {
        // The server said signed in and sent no tokens. Not recoverable, and
        // not something to paper over with a null check that pretends the
        // diner is anonymous — that would show a sign-in screen to somebody
        // the server considers authenticated.
        throw StateError('verify-otp answered signed_in with no token block');
      }
      return VerifiedSignedIn(
        SignedIn(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
          userId: pair.user.id,
          fullName: pair.user.fullName,
          phone: pair.user.phone,
        ),
      );
    }

    return VerifiedNeedsProfile(challenge);
  }

  @override
  Future<SignedIn> completeRegistration({
    required OtpChallenge challenge,
    required String fullName,
  }) async {
    final pair = await guarded(
      () => _api.completeRegistration(
        body: CompleteRegistrationDto(
          challengeId: challenge.challengeId,
          fullName: fullName,
          locale: _localeCode(),
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

  /// One call for both cases now.
  ///
  /// This used to branch: `resend-otp` for a registration challenge, and
  /// `request-otp` for a sign-in one, because `resend-otp` only re-sent the
  /// `phone_verify` code. That branch is what made the LEAKY endpoint the one a
  /// returning diner's resend button hit. `resend-otp` takes the challenge
  /// handle now and re-sends to whatever number and purpose it holds.
  @override
  Future<OtpChallenge> resend(OtpChallenge challenge) async {
    final issued = await guarded(
      () => _api.resendOtp(body: ResendOtpDto(challengeId: challenge.challengeId)),
    );
    // A NEW handle. The previous code is dead the moment this succeeds, so
    // holding the old handle would mean answering a challenge that no longer
    // exists.
    return OtpChallenge(challengeId: issued.challengeId, phone: challenge.phone);
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
