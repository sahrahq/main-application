/// How a diner reaches a human when the app cannot help them.
///
/// ─────────────────────────────────────────────────────────────────────────
/// ONE PLACE. A future change touches this file and nothing else.
/// ─────────────────────────────────────────────────────────────────────────
///
/// [value] is INTERIM — a Gmail address, moving to a domain address once the
/// sending domain exists (see the optional-email decision doc). That is exactly
/// why it is a constant here and a `{contact}` placeholder in the ARB rather
/// than being written into copy: changing it must be one edit, not a search.
///
/// `support_contact_test.dart` asserts both halves — that a real contact is
/// set, and that the literal appears in this file alone.
///
/// WHY THIS EXISTS AT ALL. Two designs in this product assume a human can be
/// reached, and both are only humane because of it:
///
///   - **The 15-minute verify lock** (doc 11 flow 1). A diner whose number was
///     guessed at by a stranger is locked out through no fault of their own,
///     and asking for a new code cannot help them. Recorded as a load-bearing
///     assumption in `docs/decisions/2026-08-02-optional-email-at-signup.md`.
///   - **Stubbed OTP delivery** (OPS-1). No SMS is sent at all yet. A diner who
///     never receives a code has no way forward from inside the app.
///
/// A support line is not a cosmetic gap in either case. It is the only exit
/// from a dead end we built deliberately.
library;

class SupportContact {
  const SupportContact._();

  /// The address a diner writes to. Latin text, shown inside Arabic copy, so
  /// every caller wraps it in a bidi isolate — without one the `@` and the dot
  /// reorder against the surrounding Arabic and the address reads wrong.
  ///
  /// NOT translated and NOT reformatted anywhere. An address is a literal.
  static const String value = 'hellosahra.app@gmail.com';

  /// A `mailto:` URI for platforms that can open a composer.
  ///
  /// Built here rather than at the call site so the address stays in one
  /// place. Nothing launches it yet — see the note in `sign_in_screen.dart`.
  static Uri get mailto => Uri(scheme: 'mailto', path: value);

  /// Whether a real contact has been supplied, as opposed to a placeholder.
  ///
  /// The check is deliberately about SHAPE rather than a sentinel string. The
  /// previous version compared against `SUPPORT_CONTACT_NOT_SET`, which stops
  /// meaning anything the moment somebody types a half-finished value; an
  /// address that cannot be written to is not a contact, whatever it is called.
  static bool get isConfigured => value.contains('@') && value.split('@').last.contains('.');
}
