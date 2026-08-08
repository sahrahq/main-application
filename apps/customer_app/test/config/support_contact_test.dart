import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/config/support_contact.dart';

/// The support contact, and the property that keeps it cheap to change.
///
/// This file used to fail on purpose — it was the build-failing placeholder
/// that made "add a support contact before launch" impossible to ship past. A
/// real address is set now, so it guards two things instead:
///
///   1. that a contact is still configured, and
///   2. that the literal lives in exactly ONE file.
///
/// (2) is the one that matters over time. The address is interim — a Gmail
/// account, moving to a domain address once the sending domain exists — and an
/// address that has leaked into ARB copy, a widget, or a test fixture is an
/// address whose replacement is a search-and-replace with something missed.
void main() {
  test('a real support contact is configured', () {
    expect(
      SupportContact.isConfigured,
      isTrue,
      reason: 'SupportContact.value is not a writable address. The verify lock '
          'and stubbed OTP delivery both dead-end a diner whose only exit is a '
          'human — see lib/config/support_contact.dart.',
    );
  });

  test('the mailto URI is built from the same constant', () {
    // Not a second copy of the address in a different shape.
    expect(SupportContact.mailto.scheme, 'mailto');
    expect(SupportContact.mailto.path, SupportContact.value);
  });

  test('the address literal appears in ONE file only', () {
    // The property that makes moving to a domain address a one-line change.
    // Scans lib/ and the ARB sources — a copy hiding in a translated string is
    // exactly the case the `{contact}` placeholder exists to prevent.
    final offenders = <String>[];

    for (final dir in <String>['lib', 'test']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart') && !path.endsWith('.arb')) continue;
        // This file names the address in a comment about not naming it.
        if (path.endsWith('lib/config/support_contact.dart')) continue;
        if (path.endsWith('test/config/support_contact_test.dart')) continue;
        if (entity.readAsStringSync().contains(SupportContact.value)) {
          offenders.add(path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The support address is hard-coded outside its one home. Use '
          'SupportContact.value and the {contact} placeholder:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
