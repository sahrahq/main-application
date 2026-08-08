/// What the presentation layer may know about signing in. Pure Dart.
library;

/// A challenge waiting to be answered with a code.
///
/// ─────────────────────────────────────────────────────────────────────────
/// ONE DOOR, AND NO WAY TO TELL WHO IS AT IT
/// ─────────────────────────────────────────────────────────────────────────
///
/// This used to carry a `userId` and an `isNewAccount` flag, because the client
/// decided which of two endpoints to call: `request-otp` for a number it
/// believed was registered, `register` for one it believed was not. It learned
/// which from a 401 — and that 401 was AUTH-3, an enumeration oracle on a
/// trivially guessable input space, sitting on the path a returning diner takes
/// every time they sign in.
///
/// There is one call now. `request-otp` looks NOTHING up, always sends a code,
/// and returns an opaque handle. Whether an account exists is decided after the
/// code is right — which is why `isNewAccount` is gone rather than renamed:
/// the concept does not exist at request time and cannot be reconstructed.
class OtpChallenge {
  const OtpChallenge({required this.challengeId, required this.phone});

  /// Opaque. 32 random bytes from the server, carrying no information — not
  /// derived from the phone, the purpose or the clock.
  final String challengeId;

  /// Kept only to show the diner which number the code went to. It is not an
  /// identifier and nothing is looked up with it.
  final String phone;
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

/// What answering a challenge produced.
///
/// Sealed, so the screen's `switch` is exhaustive and a third outcome added
/// server-side becomes a compile error rather than a silently ignored branch.
sealed class VerifyResult {
  const VerifyResult();
}

/// The number belonged to an account. Done.
class VerifiedSignedIn extends VerifyResult {
  const VerifiedSignedIn(this.session);
  final SignedIn session;
}

/// The number is proved but belongs to nobody yet. A name is needed.
///
/// The challenge stays verified-and-unspent server-side for ten minutes, so
/// the name is supplied against a number that has ALREADY been proved. Nothing
/// about the account exists until [AuthRepository.completeRegistration].
class VerifiedNeedsProfile extends VerifyResult {
  const VerifiedNeedsProfile(this.challenge);
  final OtpChallenge challenge;
}

abstract class AuthRepository {
  /// Send a code to [phone].
  ///
  /// ONE CALL, ONE PATH. No fall-through, no branch, no knowledge of whether
  /// the number is registered — see [OtpChallenge].
  Future<OtpChallenge> requestCode(String phone);

  /// Answer the challenge.
  ///
  /// Throws `ConflictFailure(code: 'too_many_attempts')` when locked,
  /// `ValidationFailure(code: 'invalid_otp')` on a wrong code, and
  /// `AuthFailure(code: 'account_unavailable')` for a suspended account —
  /// which is now only discoverable by someone who could read the code.
  Future<VerifyResult> verify({required OtpChallenge challenge, required String code});

  /// Name the account behind a challenge that has already been verified.
  ///
  /// There is no phone parameter. The number comes from the challenge, so this
  /// cannot be aimed at somebody else's number.
  Future<SignedIn> completeRegistration({
    required OtpChallenge challenge,
    required String fullName,
  });

  /// Ask for another code for the same challenge.
  ///
  /// Returns a NEW challenge: the previous code is dead the moment this
  /// succeeds, so the handle moves with it. Subject to the 3-per-10-minutes
  /// phone limit.
  Future<OtpChallenge> resend(OtpChallenge challenge);

  /// Revoke this session, and this handset's push token.
  Future<void> signOut({required String refreshToken, String? deviceToken});
}
