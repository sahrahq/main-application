import 'dart:io';

import 'package:sahra_lints/sahra_lints.dart';
import 'package:test/test.dart';

/// THE RULE IS PROVED AGAINST THE TEXT THAT PRODUCED IT.
///
/// Not a paraphrase, not a minimal example — the exact docblock
/// `PushRegistrar.syncExistingToken` carried until 2026-08-11, recovered from
/// `git show dd6e7ea~1`. It described two callers it did not have, and it read
/// as documentation of a working mechanism for as long as it survived.
///
/// A guard justified by an incident and never run against that incident's own
/// input is a guard nobody has seen work.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('sahra_caller_claims'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, String source) =>
      File('${tmp.path}${Platform.pathSeparator}$name')..writeAsStringSync(source);

  group('stage 1 — the unverifiable claim is refused on shape', () {
    test('THE ORIGINAL TEXT, VERBATIM, IS A VIOLATION', () {
      // ── Exactly as it shipped. Do not tidy this. ─────────────────────────
      write('push_registration.dart', '''
class PushRegistrar {
  /// Register a token the diner has already agreed to, without asking anything.
  ///
  /// Called on sign-in and at launch for a signed-in diner. FCM rotates tokens
  /// — on reinstall, on restore-from-backup, occasionally on its own — and a
  /// rotated token that nobody re-registers is a diner who silently stops
  /// receiving anything. The server upsert makes this cheap to repeat.
  Future<void> syncExistingToken() async {}
}
''');

      final v = docblockCallerClaims(tmp);
      expect(v, hasLength(1));
      expect(v.single.rule, 'caller-claim-unnamed');
      expect(v.single.snippet, contains('syncExistingToken'));
      expect(v.single.snippet, contains('Called on sign-in and at launch'));
    });

    test('naming a symbol that really calls it makes the same block legal', () {
      // The actual fix, in the actual shape it was written.
      write('push_registration.dart', '''
class PushRegistrar {
  /// Register a token the diner has already agreed to.
  ///
  /// Called from `PushTapListener`, the one widget that runs once per launch
  /// above every screen.
  Future<void> syncExistingToken() async {}
}
''');
      write('push_tap_listener.dart', '''
class PushTapListener {
  void listen(Ref ref) {
    ref.read(pushRegistrarProvider.notifier).syncExistingToken();
  }
}
''');

      expect(docblockCallerClaims(tmp), isEmpty);
    });

    test('"at launch" alone is refused; every preposition is', () {
      for (final claim in <String>[
        'Called by the router when a deep link arrives.',
        'Called from the notification handler.',
        'Called on sign-out.',
        'Called at launch.',
        'Invoked by the scheduler.',
      ]) {
        write('a.dart', '''
class A {
  /// $claim
  void go() {}
}
''');
        expect(
          docblockCallerClaims(tmp),
          hasLength(1),
          reason: 'not refused: "\$claim"',
        );
      }
    });
  });

  group('stage 2 — a named symbol that does not call it', () {
    test('the name resolves and the call is absent', () {
      write('a.dart', '''
class A {
  /// Called from `Router` on every cold start.
  void go() {}
}
''');
      write('router.dart', '''
class Router {
  void start() {
    somethingElse();
  }
}
''');

      final v = docblockCallerClaims(tmp);
      expect(v, hasLength(1));
      expect(v.single.rule, 'caller-does-not-call');
    });

    test('A MENTION IN A COMMENT DOES NOT SATISFY IT', () {
      // The signing-config test was once satisfied by a comment quoting the
      // code it was supposed to be checking for. A guard satisfiable by a
      // comment about itself is not a guard.
      write('a.dart', '''
class A {
  /// Called from `Router` on every cold start.
  void go() {}
}
''');
      write('router.dart', '''
class Router {
  // TODO: this should call go() at some point.
  void start() {}
}
''');

      expect(docblockCallerClaims(tmp).single.rule, 'caller-does-not-call');
    });

    test('a symbol OUTSIDE the tree is accepted — it cannot be read', () {
      // "Called by `FirebaseMessaging` when a message arrives" is a true and
      // useful sentence about a platform callback. Refusing it would push
      // people to delete the sentence rather than name the thing.
      write('a.dart', '''
class A {
  /// Called by `FirebaseMessaging` when a background message arrives.
  void onMessage() {}
}
''');
      expect(docblockCallerClaims(tmp), isEmpty);
    });
  });

  group('what must NOT trip it', () {
    test('prose about the concept of being called', () {
      // This sentence lives in `push_registration.dart`, in the docblock of the
      // very class the rule was written for. An earlier draft matched it,
      // because it allowed arbitrary words between "called" and a preposition:
      // "called IS INDISTINGUISHABLE FROM one that does not exist".
      write('a.dart', '''
class A {
  /// A capability that is never called is indistinguishable from one that
  /// does not exist.
  void go() {}
}
''');
      expect(docblockCallerClaims(tmp), isEmpty);
    });

    test('a caller described as a person, not a symbol', () {
      // "Its caller is a diner who has just booked a table" is about a human
      // and a moment. It makes no claim a call graph could contradict.
      write('a.dart', '''
class A {
  /// Never throws and never blocks anything. Its caller is a diner who has
  /// just booked a table.
  void go() {}
}
''');
      expect(docblockCallerClaims(tmp), isEmpty);
    });

    test('an exemption is honoured, and it has to say why', () {
      write('a.dart', '''
class A {
  /// Called at launch, before any provider is read.
  ///
  /// callers-exempt: the caller is Android, in Java, in a generated Activity.
  void go() {}
}
''');
      expect(docblockCallerClaims(tmp), isEmpty);
    });
  });

  group('the scanner is looking at something — census', () {
    test('an empty tree is not mistaken for a clean one', () {
      // Every assertion above expects a specific count. This one asserts the
      // machinery that produces those counts reads files at all: a path bug
      // returns [] from every call, which reads as a clean bill of health.
      write('a.dart', '''
class A {
  /// Called on sign-in.
  void go() {}
}
''');
      expect(docblockCallerClaims(tmp), hasLength(1));
      expect(docblockCallerClaims(Directory('${tmp.path}/nonexistent')), isEmpty);
    });
  });
}
