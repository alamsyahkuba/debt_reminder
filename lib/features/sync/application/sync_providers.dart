import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/providers.dart';
import '../../../core/errors/admin_sync_exception.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/sync_metadata_dao.dart';
import '../../../data/local/daos/sync_queue_dao.dart';
import '../../../data/remote/admin_sync_repository.dart';
import '../../../data/remote/public_read_repository.dart';
import '../../../data/sync/admin_sync_service.dart';
import '../../../data/sync/public_pull_service.dart';
import '../../../domain/repositories/admin_sync_repository.dart';
import '../../admin/application/admin_providers.dart';

class SyncRunState {
  const SyncRunState({
    this.isSyncing = false,
    this.lastError,
    this.lastOutcome,
    this.lastRunAt,
  });

  final bool isSyncing;
  final String? lastError;
  final AdminSyncOutcome? lastOutcome;
  final DateTime? lastRunAt;

  SyncRunState copyWith({
    bool? isSyncing,
    String? lastError,
    bool clearError = false,
    AdminSyncOutcome? lastOutcome,
    DateTime? lastRunAt,
  }) {
    return SyncRunState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastOutcome: lastOutcome ?? this.lastOutcome,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

class SyncStatus {
  const SyncStatus({
    required this.isSyncing,
    required this.pending,
    required this.conflicts,
    required this.failed,
    required this.lastPublicPullAt,
    required this.lastAdminSyncAt,
    required this.lastError,
  });

  final bool isSyncing;
  final int pending;
  final int conflicts;
  final int failed;
  final DateTime? lastPublicPullAt;
  final DateTime? lastAdminSyncAt;
  final String? lastError;

  int get totalPending => pending + conflicts + failed;

  bool get hasIssues => conflicts > 0 || failed > 0;
}

final publicReadRepositoryProvider = Provider<PublicReadRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return PublicReadRepository(
    baseUrl: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    client: client,
  );
});

final adminSyncRepositoryProvider = Provider<AdminSyncRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpAdminSyncRepository(
    baseUrl: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    client: client,
  );
});

final publicPullServiceProvider = Provider<PublicPullService>((ref) {
  return PublicPullService(
    database: ref.watch(appDatabaseProvider),
    repository: ref.watch(publicReadRepositoryProvider),
  );
});

final adminSyncServiceProvider = Provider<AdminSyncService>((ref) {
  return AdminSyncService(
    database: ref.watch(appDatabaseProvider),
    repository: ref.watch(adminSyncRepositoryProvider),
  );
});

final syncQueueSummaryProvider = StreamProvider<SyncQueueSummary>((ref) {
  return SyncQueueDao(ref.watch(appDatabaseProvider)).watchSummary();
});

final syncConflictsProvider = StreamProvider<List<SyncQueueRow>>((ref) {
  return SyncQueueDao(ref.watch(appDatabaseProvider)).watchConflicts();
});

final lastPublicPullProvider = StreamProvider<DateTime?>((ref) {
  final dao = SyncMetadataDao(ref.watch(appDatabaseProvider));
  return dao.watchValue('last_public_pull_at').map(_parseTimestamp);
});

final lastAdminSyncProvider = StreamProvider<DateTime?>((ref) {
  final dao = SyncMetadataDao(ref.watch(appDatabaseProvider));
  return dao.watchValue('last_admin_sync_at').map(_parseTimestamp);
});

final syncRunControllerProvider =
    NotifierProvider<SyncRunController, SyncRunState>(SyncRunController.new);

final syncStatusProvider = Provider<SyncStatus>((ref) {
  final queue =
      ref.watch(syncQueueSummaryProvider).value ?? SyncQueueSummary.empty;
  final run = ref.watch(syncRunControllerProvider);
  final lastPublicPull = ref.watch(lastPublicPullProvider).value;
  final lastAdminSync = ref.watch(lastAdminSyncProvider).value;

  return SyncStatus(
    isSyncing: run.isSyncing,
    pending: queue.pending + queue.processing,
    conflicts: queue.conflict,
    failed: queue.failed,
    lastPublicPullAt: lastPublicPull,
    lastAdminSyncAt: lastAdminSync,
    lastError: run.lastError,
  );
});

class SyncRunController extends Notifier<SyncRunState> {
  @override
  SyncRunState build() => const SyncRunState();

  Future<void> syncNow({bool fullPull = false}) async {
    if (state.isSyncing) {
      return;
    }

    final config = ref.read(appConfigProvider);
    if (!config.hasSupabaseConfig) {
      state = state.copyWith(lastError: 'Supabase belum dikonfigurasi.');
      return;
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    try {
      String? syncError;
      try {
        await ref.read(publicPullServiceProvider).pull(full: fullPull);
      } on AppException catch (error) {
        // Public read and admin push are separate paths. A public RPC failure
        // should not block an otherwise-authorized admin outbox push.
        syncError = error.message;
      } catch (_) {
        syncError = 'Data publik tidak dapat diperbarui.';
      }

      final session = ref.read(adminSessionControllerProvider).value;
      AdminSyncOutcome? outcome;
      if (session != null && session.isValid) {
        outcome = await ref
            .read(adminSyncServiceProvider)
            .sync(token: session.token);
        if (outcome.authRequired) {
          await ref
              .read(adminSessionControllerProvider.notifier)
              .lock(revokeServerSession: false);
          syncError =
              'Sesi admin berakhir. Buka admin kembali untuk sinkronisasi.';
        } else {
          final now = DateTime.now().toUtc();
          await SyncMetadataDao(ref.read(appDatabaseProvider)).setValue(
            key: 'last_admin_sync_at',
            value: now.toIso8601String(),
            updatedAt: now,
          );
        }
      }

      state = state.copyWith(
        isSyncing: false,
        lastOutcome: outcome,
        lastRunAt: DateTime.now().toUtc(),
        lastError: syncError,
        clearError: syncError == null,
      );
    } on AppException catch (error) {
      state = state.copyWith(isSyncing: false, lastError: error.message);
    } on AdminSyncException catch (error) {
      state = state.copyWith(isSyncing: false, lastError: error.message);
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        lastError: 'Sinkronisasi gagal. Data lokal tetap aman.',
      );
    }
  }

  Future<void> resolveConflictKeepLocal(String operationId) async {
    try {
      await ref
          .read(adminSyncServiceProvider)
          .resolveConflictKeepLocal(operationId);
      await syncNow();
    } on AdminSyncException catch (error) {
      state = state.copyWith(lastError: error.message);
    } catch (_) {
      state = state.copyWith(lastError: 'Konflik tidak dapat diselesaikan.');
    }
  }

  Future<void> resolveConflictReload(String operationId) async {
    try {
      await ref
          .read(adminSyncServiceProvider)
          .resolveConflictReload(operationId);
      await syncNow();
    } on AdminSyncException catch (error) {
      state = state.copyWith(lastError: error.message);
    } catch (_) {
      state = state.copyWith(lastError: 'Snapshot server tidak dapat dimuat.');
    }
  }
}

DateTime? _parseTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}
