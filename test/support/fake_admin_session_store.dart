import 'package:debt_reminder/core/errors/admin_auth_exception.dart';
import 'package:debt_reminder/domain/entities/admin_session.dart';
import 'package:debt_reminder/domain/repositories/admin_auth_repository.dart';
import 'package:debt_reminder/domain/repositories/admin_session_store.dart';

class FakeAdminSessionStore implements AdminSessionStore {
  FakeAdminSessionStore({this.session, this.deviceId = 'test-device'});

  factory FakeAdminSessionStore.unlocked() {
    return FakeAdminSessionStore(
      session: AdminSession(
        token: 'test-admin-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
    );
  }

  AdminSession? session;
  String deviceId;

  @override
  Future<AdminSession?> read() async => session;

  @override
  Future<void> write(AdminSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<String> readOrCreateDeviceId() async => deviceId;
}

class FakeAdminAuthRepository implements AdminAuthRepository {
  FakeAdminAuthRepository({this.validPin = '123456'});

  String validPin;
  String? lastChangedPin;
  bool logoutCalled = false;
  int verifyCalls = 0;

  @override
  Future<AdminSession> verifyPin({
    required String pin,
    required String deviceId,
  }) async {
    verifyCalls++;
    if (pin != validPin) {
      throw const AdminAuthException(
        code: 'invalid_pin',
        message: 'PIN tidak valid.',
      );
    }

    return AdminSession(
      token: 'issued-admin-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> changePin({
    required String token,
    required String currentPin,
    required String newPin,
  }) async {
    if (token != 'issued-admin-token' || currentPin != validPin) {
      throw const AdminAuthException(
        code: 'invalid_pin',
        message: 'PIN tidak valid.',
      );
    }

    validPin = newPin;
    lastChangedPin = newPin;
  }

  @override
  Future<void> logout({required String token}) async {
    logoutCalled = true;
  }
}
