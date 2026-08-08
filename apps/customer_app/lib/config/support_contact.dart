/// How a diner reaches a human when the app cannot help them.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THIS PLACEHOLDER FAILS THE BUILD. That is its job.
/// ─────────────────────────────────────────────────────────────────────────
///
/// `support_contact_test.dart` fails while this is still [unset]. It is not a
/// TODO, a warning, or a comment somebody can agree with and move past — the
/// suite is red until a real contact is supplied.
///
/// WHY IT IS WORTH A FAILING TEST. Two designs in this product assume a human
/// can be reached, and both are only humane because of it:
///
///   - **The 15-minute verify lock** (doc 11 flow 1). A diner whose number was
///     guessed at by a stranger is locked out through no fault of their own,
///     and asking for a new code cannot help them. Recorded as a load-bearing
///     assumption in `docs/decisions/2026-08-02-optional-email-at-signup.md`.
///   - **Stubbed OTP delivery** (OPS-1). No SMS is sent at all yet. A diner
///     who never receives a code has no way forward from inside the app.
///
/// A support line that is missing is not a cosmetic gap in either case. It is
/// the only exit from a dead end we built deliberately.
///
/// Replace [unset] with the real contact — a WhatsApp number is the right shape
/// for this market — and the test goes green. Do not "fix" it by deleting the
/// test.
library;

class SupportContact {
  const SupportContact._();

  /// The sentinel. Asserted against by `support_contact_test.dart`.
  static const String unset = 'SUPPORT_CONTACT_NOT_SET';

  /// Shown to diners wherever they can get stuck.
  ///
  /// Rendered inside a bidi isolate by callers: a phone number is Latin-digit
  /// content inside Arabic prose, and without an isolate the leading `+` lands
  /// on the wrong end.
  static const String value = unset;

  /// Whether a real contact has been supplied.
  static bool get isConfigured => value != unset;
}
