import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/config/support_contact.dart';

/// THIS TEST IS SUPPOSED TO BE FAILING RIGHT NOW.
///
/// It is the build-failing placeholder the product owner asked for, and it goes
/// green the moment `SupportContact.value` is a real contact.
///
/// It exists because two deliberate dead ends in this product are only humane
/// if a human can be reached from them:
///
///   - the 15-minute verify lock, which a diner can hit through no fault of
///     their own and which asking for a new code cannot clear;
///   - stubbed OTP delivery (OPS-1), where no SMS is sent at all, so a diner
///     who never receives a code has no way forward inside the app.
///
/// A comment saying "add a support contact before launch" is a comment somebody
/// reads, agrees with, and ships past. A red suite is not.
///
/// **Do not make this pass by deleting it or by loosening the assertion.** The
/// only correct fix is a real contact in `support_contact.dart`.
void main() {
  test('a real support contact has been supplied', () {
    expect(
      SupportContact.isConfigured,
      isTrue,
      reason: 'SupportContact.value is still the placeholder. The verify lock '
          'and stubbed OTP delivery both dead-end a diner whose only exit is a '
          'human — see lib/config/support_contact.dart. Supply a real contact '
          '(a WhatsApp number suits this market) rather than deleting this '
          'test.',
    );
  });

  test('the placeholder is a sentinel nobody could type by accident', () {
    // If the sentinel were something like an empty string, a half-finished edit
    // would silently satisfy `isConfigured` and the guard would be gone.
    expect(SupportContact.unset, 'SUPPORT_CONTACT_NOT_SET');
    expect(SupportContact.unset.contains(' '), isFalse);
  });
}
