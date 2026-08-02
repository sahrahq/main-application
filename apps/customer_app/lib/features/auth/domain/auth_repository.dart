/// What the presentation layer may know about signing in. Pure Dart.
library;

/// A challenge waiting to be answered with a code.
class OtpChallenge {
  const OtpChallenge({required this.userId, required this.phone, required this.isNewAccount});

  final String userId;
  final String phone;

  /// True when this came from `register` rather than `request-otp`.
  ///
  /// The two flows are one screen to a diner — "enter your number, then the
  /// code" — but they are different calls, and the copy differs: a returning
  /// diner should not be congratulated on joining.
  final bool isNewAccount;
}

/// The signed-in diner, in domain terms.
class SignedIn {
  const SignedIn({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.phone,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String phone;
}

abstract class AuthRepository {
  /// Send a code to [phone].
  ///
  /// ONE CALL FOR THE DINER, TWO FOR THE SERVER. A returning number goes to
  /// `request-otp`; an unknown one goes to `register`. The screen does not ask
  /// "do you have an account?" — nobody knows, and being asked is a small
  /// insult to a returning customer.
  ///
  /// Throws `ConflictFailure` only in the genuinely ambiguous case; an
  /// unknown-number 401 from `request-otp` is expected and handled internally.
  Future<OtpChallenge> requestCode({required String phone, required String fullName});

  /// Answer the challenge.
  ///
  /// Throws `ConflictFailure(code: 'too_many_attempts')` when locked, and
  /// `ValidationFailure(code: 'invalid_otp')` on a wrong code.
  Future<SignedIn> verify({required OtpChallenge challenge, required String code});

  /// Ask for another code. Subject to the 3-per-10-minutes phone limit.
  Future<void> resend(OtpChallenge challenge);

  /// Revoke this session, and this handset's push token.
  Future<void> signOut({required String refreshToken, String? deviceToken});
}
