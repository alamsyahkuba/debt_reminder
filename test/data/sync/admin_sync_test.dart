import 'dart:io';

import 'package:debt_reminder/core/errors/admin_sync_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/data/sync/admin_sync_service.dart';
import 'package:debt_reminder/domain/entities/admin_mutation_result.dart';
import 'package:debt_reminder/domain/repositories/admin_sync_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 13, 10);

class _Call {
  const _Call({
    required this.entityType,
    required this.operation,
    required this.payload,
  });

  final String entityType;
  final String operation;
  final Map<String, Object?> payload;
}

class _FakeAdminSyncRepository implements AdminSyncRepository {
  final List<_Call> calls = [];
  Object? error;
  Future<AdminMutationResult> Function(_Call call)? onApply;

  @override
  Future<AdminMutationResult> applyMutation({
    required String token,
    required String operationId,
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final call = _Call(
      entityType: entityType,
      operation: operation,
      payload: payload,
    );
    calls.add(call);

    if (error != null) {
      throw error!;
    }

    if (onApply != null) {
      return onApply!(call);
    }

    return _appliedFor(call);
  }
}

AdminMutationResult _appliedFor(_Call call) {
  if (call.entityType == 'payment') {
    return AdminMutationResult.applied(
      serverUpdatedAt: DateTime.utc(2026, 11, 13, 10, 1),
    );
  }

  final expected = call.payload['expected_version'];
  return AdminMutationResult.applied(
    version: expected is int ? expected + 1 : 1,
    serverUpdatedAt: DateTime.utc(2026, 11, 13, 10, 1),
  );
}

class _Harness {
  _Harness(this.database)
    : queue = SyncQueueDao(database),
      groups = DebtGroupRepositoryImpl(database, now: _fixedNow),
      debts = DebtRepositoryImpl(database, now: _fixedNow),
      payments = PaymentRepositoryImpl(database, now: _fixedNow);

  final AppDatabase database;
  final SyncQueueDao queue;
  final DebtGroupRepositoryImpl groups;
  final DebtRepositoryImpl debts;
  final PaymentRepositoryImpl payments;

  AdminSyncService service(AdminSyncRepository repository) {
    return AdminSyncService(
      database: database,
      repository: repository,
      now: _fixedNow,
      retryPolicy: const SyncRetryPolicy(
        baseDelay: Duration.zero,
        maxDelay: Duration.zero,
        jitterSeconds: 0,
      ),
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _Harness harness;

  setUp(() {
    harness = _Harness(AppDatabase(NativeDatabase.memory()));
  });

  tearDown(() async {
    await harness.database.close();
  });

  test('sync mengirim group, debt, payment secara berurutan', () async {
    final group = await harness.groups.create(name: 'Keluarga');
    final debt = await harness.debts.create(
      groupId: group.id,
      title: 'Hutang Motor',
      principalAmount: 1000000,
    );
    await harness.payments.create(debtId: debt.id, amount: 250000);

    final repository = _FakeAdminSyncRepository();
    final outcome = await harness.service(repository).sync(token: 'token');

    expect(outcome.applied, 3);
    expect(outcome.conflicts, 0);
    expect(repository.calls.map((call) => call.entityType), <String>[
      'debt_group',
      'debt',
      'payment',
    ]);
    expect(await harness.queue.listAll(), isEmpty);

    final storedGroup = await harness.groups.findById(group.id);
    final storedDebt = await harness.debts.findById(debt.id);
    final storedPayment = (await harness.payments.listByDebt(debt.id)).single;
    expect(storedGroup?.syncState.name, 'synced');
    expect(storedDebt?.syncState.name, 'synced');
    expect(storedPayment.syncState.name, 'synced');
  });

  test(
    'retry network mempertahankan queue dan pulih setelah restart',
    () async {
      await harness.groups.create(name: 'Keluarga');
      final repository = _FakeAdminSyncRepository()
        ..error = const AdminSyncException(
          code: 'network',
          message: 'Offline',
          isRetryable: true,
        );
      final first = await harness.service(repository).sync(token: 'token');

      expect(first.retryScheduled, 1);
      var queued = await harness.queue.listAll();
      expect(queued, hasLength(1));
      expect(queued.single.status, 'pending');
      expect(queued.single.retryCount, 1);
      expect(queued.single.nextRetryAt, isNotNull);

      await harness.queue.markProcessing(queued.single.operationId);

      final recoveryRepository = _FakeAdminSyncRepository();
      final second = await harness
          .service(recoveryRepository)
          .sync(token: 'token');

      expect(second.applied, 1);
      expect(await harness.queue.listAll(), isEmpty);
    },
  );

  test(
    'outbox pending bertahan setelah database ditutup dan dibuka kembali',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'debt_reminder_sync_restart',
      );
      final file = File('${directory.path}/sync.sqlite');
      final firstDatabase = AppDatabase(NativeDatabase(file));

      try {
        final firstGroups = DebtGroupRepositoryImpl(
          firstDatabase,
          now: _fixedNow,
        );
        final created = await firstGroups.create(name: 'Persisten');
        final firstQueue = SyncQueueDao(firstDatabase);
        final queued = (await firstQueue.listAll()).single;
        await firstQueue.markProcessing(queued.operationId);
        await firstDatabase.close();

        final reopened = AppDatabase(NativeDatabase(file));
        try {
          final queueAfterRestart = SyncQueueDao(reopened);
          final stored = await DebtGroupRepositoryImpl(
            reopened,
            now: _fixedNow,
          ).findById(created.id);
          expect(stored?.name, 'Persisten');
          expect(
            (await queueAfterRestart.listAll()).single.status,
            'processing',
          );

          final service = AdminSyncService(
            database: reopened,
            repository: _FakeAdminSyncRepository(),
            now: _fixedNow,
          );
          final outcome = await service.sync(token: 'token');

          expect(outcome.applied, 1);
          expect(await queueAfterRestart.listAll(), isEmpty);
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('auth error menahan queue tanpa retry otomatis', () async {
    await harness.groups.create(name: 'Keluarga');
    final repository = _FakeAdminSyncRepository()
      ..error = const AdminSyncException(
        code: 'unauthorized',
        message: 'Sesi berakhir',
        isAuthError: true,
        statusCode: 401,
      );

    final outcome = await harness.service(repository).sync(token: 'token');

    expect(outcome.authRequired, true);
    final queued = await harness.queue.listAll();
    expect(queued, hasLength(1));
    expect(queued.single.status, 'pending');
    expect(queued.single.lastErrorCode, 'unauthorized');
    expect(queued.single.nextRetryAt, isNull);
  });

  test(
    'payload outbox rusak ditandai gagal tanpa menghentikan worker',
    () async {
      await harness.queue.enqueue(
        operationId: 'malformed-op',
        entityType: 'debt_group',
        entityId: 'missing-group',
        operation: 'create',
        payload: <String, Object?>{'id': 'missing-group'},
        createdAt: _fixedNow(),
      );
      await harness.database.customStatement(
        "UPDATE sync_queue SET payload = 'not-json' WHERE operation_id = 'malformed-op'",
      );
      await harness.groups.create(name: 'Valid');

      final repository = _FakeAdminSyncRepository();
      final outcome = await harness.service(repository).sync(token: 'token');

      expect(outcome.failed, 1);
      expect(outcome.applied, 1);
      final queue = await harness.queue.listAll();
      expect(queue, hasLength(1));
      expect(queue.single.status, 'failed');
      expect(queue.single.lastErrorCode, 'invalid_payload');
      expect(repository.calls, hasLength(1));
    },
  );

  test('conflict disimpan dan reload memakai snapshot server', () async {
    final group = await harness.groups.create(name: 'Lokal');
    await harness.groups.update(
      id: group.id,
      expectedVersion: group.version,
      name: 'Lokal Edit',
      sortOrder: 0,
    );

    final repository = _FakeAdminSyncRepository()
      ..onApply = (call) async {
        if (call.operation == 'update') {
          return AdminMutationResult.conflict(
            serverVersion: 4,
            serverUpdatedAt: DateTime.utc(2026, 11, 13, 10, 3),
            serverRow: <String, Object?>{
              'id': group.id,
              'name': 'Server',
              'description': null,
              'color': null,
              'icon': null,
              'sort_order': 0,
              'is_archived': false,
              'created_at': '2026-11-13T10:00:00Z',
              'updated_at': '2026-11-13T10:03:00Z',
              'version': 4,
            },
          );
        }
        return _appliedFor(call);
      };

    await harness.service(repository).sync(token: 'token');

    final conflicts = await harness.service(repository).listConflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.status, 'conflict');
    final local = await harness.groups.findById(group.id);
    expect(local?.syncState.name, 'conflict');

    await harness
        .service(repository)
        .resolveConflictReload(conflicts.single.operationId);

    final reloaded = await harness.groups.findById(group.id);
    expect(reloaded?.name, 'Server');
    expect(reloaded?.version, 4);
    expect(reloaded?.syncState.name, 'synced');
    expect(await harness.queue.listAll(), isEmpty);
  });

  test('keep local memakai server version lalu sync ulang', () async {
    final group = await harness.groups.create(name: 'Lokal');
    await harness.groups.update(
      id: group.id,
      expectedVersion: group.version,
      name: 'Lokal Edit',
      sortOrder: 0,
    );

    var conflictReturned = false;
    final repository = _FakeAdminSyncRepository()
      ..onApply = (call) async {
        if (call.operation == 'update' && !conflictReturned) {
          conflictReturned = true;
          return AdminMutationResult.conflict(
            serverVersion: 4,
            serverUpdatedAt: DateTime.utc(2026, 11, 13, 10, 3),
            serverRow: <String, Object?>{
              'id': group.id,
              'name': 'Server',
              'description': null,
              'color': null,
              'icon': null,
              'sort_order': 0,
              'is_archived': false,
              'created_at': '2026-11-13T10:00:00Z',
              'updated_at': '2026-11-13T10:03:00Z',
              'version': 4,
            },
          );
        }
        return _appliedFor(call);
      };

    final service = harness.service(repository);
    await service.sync(token: 'token');
    final conflict = (await service.listConflicts()).single;
    await service.resolveConflictKeepLocal(conflict.operationId);

    final pending = await harness.groups.findById(group.id);
    expect(pending?.version, 4);
    expect(pending?.syncState.name, 'pending');

    final outcome = await service.sync(token: 'token');
    expect(outcome.applied, 1);
    final synced = await harness.groups.findById(group.id);
    expect(synced?.name, 'Lokal Edit');
    expect(synced?.version, 5);
    expect(synced?.syncState.name, 'synced');
  });
}
