import '../entities/admin_session.dart';

abstract interface class AdminSessionStore {
  Future<AdminSession?> read();

  Future<void> write(AdminSession session);

  Future<void> clear();

  /// Stable opaque device id used for server-side session binding.
  Future<String> readOrCreateDeviceId();
}
