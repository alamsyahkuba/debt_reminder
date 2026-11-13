import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/admin_session.dart';
import '../../domain/repositories/admin_session_store.dart';

class SecureAdminSessionStore implements AdminSessionStore {
  SecureAdminSessionStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage = storage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const String _tokenKey = 'admin_session_token';
  static const String _expiresAtKey = 'admin_session_expires_at';
  static const String _deviceIdKey = 'admin_device_id';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  @override
  Future<AdminSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final expiresAtText = await _storage.read(key: _expiresAtKey);

    if (token == null || token.isEmpty || expiresAtText == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      await clear();
      return null;
    }

    return AdminSession(token: token, expiresAt: expiresAt.toUtc());
  }

  @override
  Future<void> write(AdminSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresAtKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }

  @override
  Future<String> readOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final deviceId = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }
}
