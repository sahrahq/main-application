import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/auth/session.dart';

part 'session_providers.g.dart';

/// Where the session is persisted. Overridden in tests with the in-memory
/// store, so no test ever reaches a keystore.
@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => SecureSessionStore();

/// The signed-in diner, or null.
///
/// `keepAlive`, because it is read by the transport on every request and by
/// three screens; an auto-disposing session would sign the diner out whenever
/// the last watcher was rebuilt.
///
/// The initial read from storage is DELIBERATELY not awaited into the state
/// type. `build()` returns null and then fills in: the alternative is an
/// `AsyncValue<Session?>` that every caller has to unwrap, including the
/// transport, which has no widget tree to show a spinner in. A request made in
/// the first frames goes out unauthenticated and gets a 401, which is the same
/// path a genuinely expired token takes and is therefore already handled.
@Riverpod(keepAlive: true)
class CurrentSession extends _$CurrentSession {
  Completer<void> _ready = Completer<void>();

  /// Completes once storage has been consulted, whatever the answer.
  ///
  /// ANYONE MAKING A SIGNED-IN-OR-NOT DECISION MUST AWAIT THIS. A Riverpod
  /// notifier is created on first read, so before this existed the restore had
  /// not merely *not finished* when the bottom navigation asked — it had not
  /// STARTED. `AppShell` was the first reader, it read synchronously, and a
  /// returning diner tapping Bookings was told they were signed out and sent
  /// to sign in. Found by a probe print in the tab test, which reported
  /// `session after restore: null` and then made its own assertions pass by
  /// having triggered the restore.
  ///
  /// The state stays `Session?` rather than becoming `AsyncValue<Session?>`
  /// for the reason in the class note: the transport has no widget tree to
  /// show a spinner in. A caller that needs certainty awaits this; a caller
  /// that only needs a token takes the 401 path, which is already handled.
  Future<void> get ready => _ready.future;

  @override
  Session? build() {
    if (_ready.isCompleted) _ready = Completer<void>();
    _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(sessionStoreProvider).read();
      if (stored != null && state == null) state = stored;
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> signIn(Session session) async {
    state = session;
    await ref.read(sessionStoreProvider).write(session);
  }

  Future<void> signOut() async {
    state = null;
    await ref.read(sessionStoreProvider).clear();
  }
}

/// Convenience for widgets that only care whether anyone is signed in.
@riverpod
bool isSignedIn(Ref ref) => ref.watch(currentSessionProvider) != null;
