import '../entities/admin_session.dart';

/// Server-authorized admin authentication.
///
/// The token returned by the server is short-lived and is only persisted in
/// secure storage. No PIN or PIN hash is ever stored in the app database.
abstract interface class AdminAuthRepository {
  Future<AdminSession> verifyPin({
    required String pin,
    required String deviceId,
  });

  Future<void> changePin({
    required String token,
    required String currentPin,
    required String newPin,
  });

  Future<void> logout({required String token});
}
