import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_override.g.dart';

/// Where the chosen language is kept between launches.
///
/// A SEAM, mirroring `SessionStore`, so no test ever reaches a keystore — on
/// the test host `flutter_secure_storage` has no platform channel at all.
abstract class LocalePreferenceStore {
  Future<String?> read();
  Future<void> write(String? code);
}

/// ── WHY SECURE STORAGE FOR SOMETHING THAT IS NOT A SECRET ────────────────
///
/// A language choice is not a credential and does not need encrypting. The
/// obvious home is `shared_preferences` — which is **not in the doc 08 §5
/// stack table**, and CLAUDE.md says stop and ask before adding one.
///
/// `flutter_secure_storage` is already approved, already a dependency, and
/// already used one file away. Spending an approval round-trip on a key-value
/// store, to hold two possible strings, was the worse trade. Flagged rather
/// than hidden: if `shared_preferences` is ever approved for other reasons,
/// this is a five-line change behind the seam above.
class SecureLocalePreferenceStore implements LocalePreferenceStore {
  SecureLocalePreferenceStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _key = 'sahra.locale.override.v1';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // An unreadable value is "follow the device", not a crash on launch.
      return null;
    }
  }

  @override
  Future<void> write(String? code) async {
    if (code == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: code);
    }
  }
}

class InMemoryLocalePreferenceStore implements LocalePreferenceStore {
  InMemoryLocalePreferenceStore([this._code]);

  String? _code;

  @override
  Future<String?> read() async => _code;

  @override
  Future<void> write(String? code) async => _code = code;
}

@Riverpod(keepAlive: true)
LocalePreferenceStore localePreferenceStore(Ref ref) => SecureLocalePreferenceStore();

/// The language the diner CHOSE, or null to follow the device.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS AT ALL — AMENDED 2026-08-09
/// ─────────────────────────────────────────────────────────────────────────
///
/// The app followed the device and nothing else, on the argument that an
/// in-app switch would be "a second source of truth for something the phone
/// already knows". That was overruled, and correctly: a large share of people
/// in Egypt run their phone in English and want to read Arabic, or the
/// reverse. The handset language is a fact about the handset.
///
/// **NULL IS THE ORDINARY STATE.** Nothing is written until a diner opens the
/// language sheet and picks something, so first launch — and every launch for
/// anybody who never visits that screen — behaves exactly as it did before.
/// This is an override, not a setting with a default.
///
/// ── NOT `users.locale`, AND NOT IN THE SESSION ───────────────────────────
///
/// `PATCH /auth/me` can set a locale, but that is the language SAHRA writes TO
/// you in: push, WhatsApp, the eventual confirmation email. This is the
/// language you READ THE APP in, on this handset. They are different
/// questions, and keeping this one local means it also works signed out —
/// which is exactly when a diner discovers the app is in the wrong language
/// for them.
@Riverpod(keepAlive: true)
class LocaleOverride extends _$LocaleOverride {
  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final stored = await ref.read(localePreferenceStoreProvider).read();
    // Only the two this binary ships strings for. A value written by a future
    // build that added a third language must not leave the app in a locale it
    // cannot render.
    if (stored == 'ar' || stored == 'en') state = stored;
  }

  /// [code] is `ar`, `en`, or null to go back to following the device.
  Future<void> set(String? code) async {
    state = code;
    await ref.read(localePreferenceStoreProvider).write(code);
  }
}
