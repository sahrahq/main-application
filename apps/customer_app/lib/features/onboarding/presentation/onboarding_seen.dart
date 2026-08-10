import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_seen.g.dart';

/// Whether the diner has been through onboarding.
///
/// Same store choice as the language override, and the same reason:
/// `shared_preferences` is not in the doc 08 §5 stack table and
/// `flutter_secure_storage` is already approved. Overkill for a boolean, and
/// cheaper than a dependency ask.
abstract class OnboardingSeenStore {
  Future<bool> read();
  Future<void> markSeen();
}

class SecureOnboardingSeenStore implements OnboardingSeenStore {
  SecureOnboardingSeenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _key = 'sahra.onboarding.seen.v1';

  @override
  Future<bool> read() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      // AN UNREADABLE VALUE MEANS "NOT SEEN", which shows onboarding again.
      // The failure modes are not symmetric: showing three slides twice is an
      // annoyance, and skipping them for somebody who has never seen the app
      // is the one thing this screen exists to prevent.
      return false;
    }
  }

  @override
  Future<void> markSeen() => _storage.write(key: _key, value: 'true');
}

class InMemoryOnboardingSeenStore implements OnboardingSeenStore {
  InMemoryOnboardingSeenStore([this._seen = false]);

  bool _seen;

  @override
  Future<bool> read() async => _seen;

  @override
  Future<void> markSeen() async => _seen = true;
}

@Riverpod(keepAlive: true)
OnboardingSeenStore onboardingSeenStore(Ref ref) => SecureOnboardingSeenStore();

/// Null while the answer is still being read from storage.
///
/// THE THREE-STATE IS THE POINT. A bare `false` default would flash onboarding
/// at every returning diner for the frame or two before storage answered —
/// which is worse than showing it, because it looks like a bug rather than a
/// welcome. The router waits for a real answer.
@Riverpod(keepAlive: true)
class OnboardingSeen extends _$OnboardingSeen {
  @override
  bool? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    state = await ref.read(onboardingSeenStoreProvider).read();
  }

  Future<void> markSeen() async {
    state = true;
    await ref.read(onboardingSeenStoreProvider).markSeen();
  }
}
