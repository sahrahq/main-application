import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/core/error/failure.dart';
import 'package:sahra_customer_app/localization/generated/app_localizations.dart';
import 'package:sahra_customer_app/shared/widgets/failure_copy.dart';
import 'package:sahra_localization/sahra_localization.dart';

/// Proves the mapping is REACHABLE, not merely present.
///
/// `arb_test.dart` already proves every backend code has an ARB key. That is
/// not the same claim: `failureMessage` reaches the copy through a hand-written
/// key→getter table, and a code missing from THAT table falls through to the
/// generic "something went wrong" — silently, in both languages, forever.
void main() {
  for (final locale in <String>['ar', 'en']) {
    group('$locale copy is reachable for every backend code', () {
      late AppLocalizations l10n;

      setUp(() async {
        l10n = await AppLocalizations.delegate.load(Locale(locale));
      });

      test('the code list is not empty — census', () {
        // Every assertion below loops over this map. An empty one would make
        // the whole group pass while proving nothing.
        expect(errorCodeToArbKey.length, greaterThan(40));
      });

      test('no code falls through to the generic message', () {
        final generic = l10n.errUnknown;
        final unreachable = <String>[];

        for (final code in errorCodeToArbKey.keys) {
          // `unknown` maps to the generic message BY DESIGN — it is the
          // fallback itself.
          if (code == 'unknown') continue;
          final message = failureMessage(ServerFailure(code: code), l10n);
          if (message == generic) unreachable.add(code);
        }

        expect(
          unreachable,
          isEmpty,
          reason: 'These codes have ARB copy but no branch in failure_copy.dart, '
              'so a diner sees "something went wrong" instead: $unreachable',
        );
      });

      test('an UNRECOGNISED code falls back rather than crashing', () {
        // A server deployed ahead of the app is normal in mobile.
        expect(
          failureMessage(const ServerFailure(code: 'kitchen_on_fire'), l10n),
          l10n.errUnknown,
        );
      });

      test('offline has its own copy, not the generic one', () {
        expect(failureMessage(const OfflineFailure(), l10n), l10n.errOffline);
        expect(failureMessage(const OfflineFailure(), l10n), isNot(l10n.errUnknown));
      });

      test('every sealed Failure has a distinct title', () {
        // The compiler already forces a branch per member; this checks that
        // seven branches produce seven sentences rather than the same one
        // seven times, which is what a copy-paste switch would give.
        final titles = <Failure>[
          const OfflineFailure(),
          const NetworkFailure(),
          const AuthFailure(),
          const ConflictFailure(),
          const ValidationFailure(),
          const ServerFailure(),
          const UnknownFailure(),
        ].map((f) => failureTitle(f, l10n)).toSet();

        expect(titles, hasLength(7));
      });

      test('slot_taken reads as an apology with a way forward', () {
        // The one message a diner is most likely to meet on the booking path.
        // A machine cannot judge tone — this only pins that it is not the
        // generic string and not empty. The tone is the product owner's call.
        final message = failureMessage(const ConflictFailure(code: 'slot_taken'), l10n);
        expect(message, isNot(l10n.errUnknown));
        expect(message.trim(), isNotEmpty);
      });
    });
  }
}
