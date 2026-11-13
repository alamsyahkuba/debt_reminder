import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/providers.dart';
import '../../../core/errors/admin_auth_exception.dart';
import '../../../data/local/secure_admin_session_store.dart';
import '../../../data/remote/admin_auth_repository.dart';
import '../../../domain/entities/admin_session.dart';
import '../../../domain/repositories/admin_auth_repository.dart';
import '../../../domain/repositories/admin_session_store.dart';

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = http.Client();
  ref.onDispose(client.close);

  return HttpAdminAuthRepository(
    baseUrl: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    client: client,
  );
});

final adminSessionStoreProvider = Provider<AdminSessionStore>((ref) {
  return SecureAdminSessionStore();
});

final adminSessionControllerProvider =
    AsyncNotifierProvider<AdminSessionController, AdminSession?>(
      AdminSessionController.new,
    );

/// True only while a non-expired server-issued admin session is available.
final adminUnlockedProvider = Provider<bool>((ref) {
  final session = ref.watch(adminSessionControllerProvider).value;
  return session?.isValid ?? false;
});

class AdminSessionController extends AsyncNotifier<AdminSession?> {
  Timer? _expiryTimer;

  @override
  Future<AdminSession?> build() async {
    ref.onDispose(_cancelExpiryTimer);

    final store = ref.read(adminSessionStoreProvider);
    final session = await store.read();
    if (session == null) {
      return null;
    }

    if (!session.isValid) {
      await store.clear();
      return null;
    }

    _scheduleExpiry(session.expiresAt);
    return session;
  }

  Future<void> unlock(String pin) async {
    final store = ref.read(adminSessionStoreProvider);
    final deviceId = await store.readOrCreateDeviceId();
    final session = await ref
        .read(adminAuthRepositoryProvider)
        .verifyPin(pin: pin, deviceId: deviceId);

    await store.write(session);
    _scheduleExpiry(session.expiresAt);
    state = AsyncData(session);
  }

  /// Locks the local UI immediately.
  ///
  /// When [revokeServerSession] is true, the server session is revoked on a
  /// best-effort basis. Local material is cleared even when the network is
  /// unavailable; a stale token is never reused.
  Future<void> lock({bool revokeServerSession = true}) async {
    final session = state.value;
    _cancelExpiryTimer();

    if (revokeServerSession && session != null) {
      try {
        await ref
            .read(adminAuthRepositoryProvider)
            .logout(token: session.token);
      } catch (_) {
        // Local lock must still succeed when offline or the token expired.
      }
    }

    await ref.read(adminSessionStoreProvider).clear();
    if (ref.mounted) {
      state = const AsyncData<AdminSession?>(null);
    }
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final session = state.value;
    if (session == null || !session.isValid) {
      throw const AdminAuthException(
        code: 'session_expired',
        message: 'Sesi admin sudah berakhir. Buka admin kembali.',
      );
    }

    await ref
        .read(adminAuthRepositoryProvider)
        .changePin(
          token: session.token,
          currentPin: currentPin,
          newPin: newPin,
        );
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _cancelExpiryTimer();
    final remaining = expiresAt.toUtc().difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      _expiryTimer = Timer(Duration.zero, _expire);
      return;
    }

    _expiryTimer = Timer(remaining, _expire);
  }

  void _expire() {
    _expiryTimer = null;
    unawaited(ref.read(adminSessionStoreProvider).clear());
    if (ref.mounted) {
      state = const AsyncData<AdminSession?>(null);
    }
  }

  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }
}
