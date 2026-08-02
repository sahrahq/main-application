import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The signed-in diner, as the app holds them.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.phone,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String phone;

  Map<String, Object?> toJson() => <String, Object?>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
      };

  static Session? fromJson(Map<String, Object?> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final id = json['userId'];
    if (access is! String || refresh is! String || id is! String) return null;
    return Session(
      accessToken: access,
      refreshToken: refresh,
      userId: id,
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }
}

/// Where tokens live between launches.
///
/// `flutter_secure_storage` (doc 07 §3, Security), not shared preferences: a
/// refresh token is a 30-day credential, and the whole point of the rotation
/// and reuse-detection work on the server is that stealing one is expensive.
/// Storing it in plaintext next to the app's settings would give that back.
///
/// The ACCESS token is stored too, so a relaunch does not spend a refresh —
/// but it is the short-lived one, and the transport re-authenticates on a 401
/// regardless of what was on disk.
abstract class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'sahra.session.v1';

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // A corrupt or undecryptable blob is a signed-out user, not a crash on
      // launch. The failure mode of being wrong here is one extra sign-in.
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// For tests and for the golden harness, which must not touch a keystore.
class InMemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
