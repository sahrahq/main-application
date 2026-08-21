import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/notifications/domain/app_notification.dart';

/// THE NOTIFICATION KINDS ARE DEFINED TWICE. This is what stops them drifting.
///
/// `NOTIFICATION_TYPES` is a TypeScript const array; `NotificationKind` is a
/// Dart enum; neither can see the other. Same shape as
/// `dietary_vocabulary_test.dart` and `report_reason_test.dart`: read the
/// server's list off disk rather than keeping a third copy beside the test.
///
/// ── THE TWO DIRECTIONS FAIL DIFFERENTLY, AND ONLY ONE IS LOUD ────────────
///
/// A type the SERVER can send and the client has no case for is **survivable
/// by design**: it parses to `NotificationKind.unknown` and the row is skipped,
/// because a diner on last month's build must not get an empty list when we add
/// a type. That tolerance is exactly why this test is needed — the failure is
/// silent, so nothing else would ever report it, and a notification kind
/// nobody's app can draw is a notification nobody receives.
///
/// A type the CLIENT knows and the server cannot send is the other way round:
/// harmless at runtime, but it means copy in two languages and a case in the
/// renderer for something that does not exist. Also worth failing on.
void main() {
  final File ports = File(
    '../../apps/api/src/modules/notifications/notification.ports.ts',
  );

  test('the server\'s type list is where we think it is', () {
    expect(
      ports.existsSync(),
      isTrue,
      reason: 'notification.ports.ts not found at ${ports.path} — this file '
          'is now vacuous. It was moved, or the relative path is wrong.',
    );
  });

  /// The values inside `export const NOTIFICATION_TYPES = [ … ] as const;`.
  List<String> typesFromServer() {
    final RegExp block = RegExp(
      r'NOTIFICATION_TYPES\s*=\s*\[(.*?)\]\s*as const',
      dotAll: true,
    );
    final RegExpMatch? m = block.firstMatch(ports.readAsStringSync());
    if (m == null) return <String>[];
    return RegExp("'([a-z0-9_]+)'").allMatches(m.group(1)!).map((x) => x.group(1)!).toList();
  }

  test('the list was found and is not empty', () {
    final List<String> found = typesFromServer();
    expect(
      found,
      isNotEmpty,
      reason: 'NOTIFICATION_TYPES did not match — it was renamed or its shape '
          'changed, and until this scan is fixed nothing is comparing the '
          'two lists.',
    );
    expect(found.length, greaterThanOrEqualTo(5));
  });

  test('every type the server can send has a Dart case', () {
    final Set<String> server = typesFromServer().toSet();
    final Set<String> client = NotificationKind.values
        .where((k) => k != NotificationKind.unknown)
        .map((k) => k.wire)
        .toSet();

    expect(
      server.difference(client),
      isEmpty,
      reason: 'The server can send these and the client renders NOTHING for '
          'them — they parse to `unknown` and the row is silently skipped, so '
          'no other test and no golden would ever notice.',
    );
    expect(
      client.difference(server),
      isEmpty,
      reason: 'These have a Dart case, copy in two languages and an icon, and '
          'the server cannot produce one. Dead code that looks like a feature.',
    );
  });

  test('`wire` is snake_case, not Dart `name`', () {
    expect(NotificationKind.waitlistOffer.wire, 'waitlist_offer');
    expect(NotificationKind.reservationReminder24h.wire, 'reservation_reminder_24h');
    expect(
      NotificationKind.waitlistOffer.name,
      isNot(NotificationKind.waitlistOffer.wire),
    );
  });

  group('parsing tolerates a server that is ahead of this build', () {
    test('an unknown wire value becomes `unknown` rather than throwing', () {
      // The app on a diner's phone is whatever they last updated to. A type
      // added next month arrives at a client built today, and it must cost them
      // one invisible row — not the whole screen.
      expect(
        NotificationKind.parse('something_invented_in_2027'),
        NotificationKind.unknown,
      );
      expect(NotificationKind.parse(''), NotificationKind.unknown);
    });

    test('and `unknown` is not itself reachable from the wire', () {
      // Its `wire` is the empty string, so a malformed empty `type` must not
      // match it by accident and then be treated as a real kind. Covered by the
      // case above; asserted here as the property rather than the example.
      expect(NotificationKind.unknown.wire, isEmpty);
      expect(
        NotificationKind.values.where((k) => k.wire.isEmpty).length,
        1,
      );
    });
  });
}
