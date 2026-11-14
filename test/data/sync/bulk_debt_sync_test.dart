import 'package:debt_reminder/core/errors/admin_sync_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/data/sync/admin_sync_service.dart';
import 'package:debt_reminder/domain/entities/admin_mutation_result.dart';
import 'package:debt_reminder/domain/entities/debt_draft.dart';
import 'package:debt_reminder/domain/repositories/admin_sync_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 14, 10);
DateTime _serverNow() => DateTime.utc(2026, 11, 14, 10, 1);

class _Call {
  const _Call({
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.payload,
  });

  final String entityType;
  final String operation;
  final String entityId;
  final Map<String, Object?> payload;
}

class _FakeAdminSyncRepository implements AdminSyncRepository {
  final List<_Call> calls = <_Call>[];
  AdminMutationResult Function(_Call call)? onApply;
  Object? errorForBatch;

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
      entityId: entityId,
      payload: payload,
    );
    calls.add(call);

    if (entityType == 'debt_batch' && errorForBatch != null) {
      throw errorForBatch!;
    }

    final custom = onApply;
    if (custom != null) {
      return custom(call);
    }

    if (entityType == 'debt_batch') {
      return _appliedBatch(call);
    }

    return AdminMutationResult.applied(
      version: 1,
      serverUpdatedAt: _serverNow(),
    );
  }

  AdminMutationResult _appliedBatch(_Call call) {
    final debts = call.payload['debts'];
    final items = <AdminMutationItemResult>[];
    if (debts is List) {
      for (final raw in debts) {
        if (raw is! Map) {
          continue;
        }
        final id = raw['id'];
        if (id is String) {
          items.add(
            AdminMutationItemResult(
              id: id,
              version: 1,
              serverUpdatedAt: _serverNow(),
            ),
          );
        }
      }
    }
    return AdminMutationResult.applied(
      serverUpdatedAt: _serverNow(),
      items: items,
    );
  }
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
  late _Harness harness;

  setUp(() {
    harness = _Harness(AppDatabase(NativeDatabase.memory()));
  });

  tearDown(() async {
    await harness.database.close();
  });

  test('sync mengirim group lalu satu batch hutang', () async {
    final group = await harness.groups.create(name: 'Keluarga');
    final debts = await harness.debts.createMany(
      groupId: group.id,
      drafts: const <DebtDraft>[
        DebtDraft(title: 'Hutang satu', principalAmount: 100000),
        DebtDraft(title: 'Hutang dua', principalAmount: 200000),
      ],
    );
    final repository = _FakeAdminSyncRepository();

    final outcome = await harness
        .service(repository)
        .sync(token: 'token', maxOperations: 50);

    expect(outcome.applied, 2);
    expect(repository.calls.map((call) => call.entityType), <String>[
      'debt_group',
      'debt_batch',
    ]);
    expect(repository.calls.last.entityId, isNotEmpty);
    expect(await harness.queue.listAll(), isEmpty);

    final storedGroup = await harness.groups.findById(group.id);
    expect(storedGroup?.syncState.name, 'synced');
    for (final debt in debts) {
      final stored = await harness.debts.findById(debt.id);
      expect(stored?.syncState.name, 'synced');
      expect(stored?.version, 1);
    }
  });

  test('batch sync sebelum payment yang mereferensikan hutang baru', () async {
    final group = await harness.groups.create(name: 'Keluarga');
    final debts = await harness.debts.createMany(
      groupId: group.id,
      drafts: const <DebtDraft>[
        DebtDraft(title: 'Hutang dengan cicilan', principalAmount: 500000),
      ],
    );
    await harness.payments.create(debtId: debts.single.id, amount: 100000);
    final repository = _FakeAdminSyncRepository();

    final outcome = await harness.service(repository).sync(token: 'token');

    expect(outcome.applied, 3);
    expect(repository.calls.map((call) => call.entityType), <String>[
      'debt_group',
      'debt_batch',
      'payment',
    ]);
    final storedDebt = await harness.debts.findById(debts.single.id);
    expect(storedDebt?.syncState.name, 'synced');
    expect(await harness.queue.listAll(), isEmpty);
  });

  test('kegagalan batch tidak menghapus hutang lokal atau outbox', () async {
    final group = await harness.groups.create(name: 'Keluarga');
    final debts = await harness.debts.createMany(
      groupId: group.id,
      drafts: const <DebtDraft>[
        DebtDraft(title: 'Hutang satu', principalAmount: 100000),
        DebtDraft(title: 'Hutang dua', principalAmount: 200000),
      ],
    );
    final repository = _FakeAdminSyncRepository()
      ..errorForBatch = const AdminSyncException(
        code: 'validation_error',
        message: 'Batch ditolak.',
      );

    final outcome = await harness.service(repository).sync(token: 'token');

    expect(outcome.failed, 1);
    expect(outcome.applied, 1);
    final queued = await harness.queue.listAll();
    expect(queued, hasLength(1));
    expect(queued.single.entityType, 'debt_batch');
    expect(queued.single.status, 'failed');
    for (final debt in debts) {
      expect(await harness.debts.findById(debt.id), isNotNull);
    }
  });
}
