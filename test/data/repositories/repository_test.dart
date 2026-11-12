import 'dart:convert';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_metadata_dao.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/local/dev_seed.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/domain/entities/debt_group.dart';
import 'package:debt_reminder/domain/entities/sync_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 12, 10);

class _ThrowingSyncQueueDao extends SyncQueueDao {
  _ThrowingSyncQueueDao(super.db);

  @override
  Future<void> enqueue({
    required String operationId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) async {
    throw StateError('outbox gagal');
  }
}

void main() {
  late AppDatabase database;
  late SyncQueueDao queueDao;
  late DebtGroupRepositoryImpl groups;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queueDao = SyncQueueDao(database);
    groups = DebtGroupRepositoryImpl(
      database,
      syncQueueDao: queueDao,
      now: _fixedNow,
    );
    debts = DebtRepositoryImpl(
      database,
      syncQueueDao: queueDao,
      now: _fixedNow,
    );
    payments = PaymentRepositoryImpl(
      database,
      syncQueueDao: queueDao,
      now: _fixedNow,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('debt group repository', () {
    test('create menyimpan entity dan outbox dalam satu transaksi', () async {
      final group = await groups.create(
        name: '  Keluarga  ',
        description: ' Group keluarga ',
        color: '#00695C',
        icon: 'family',
        sortOrder: 1,
      );

      expect(group.name, 'Keluarga');
      expect(group.description, 'Group keluarga');
      expect(group.version, 1);
      expect(group.syncState, SyncState.pending);
      expect(await groups.watchAll().first, hasLength(1));

      final queue = await queueDao.listAll();
      expect(queue, hasLength(1));
      expect(queue.single.entityType, 'debt_group');
      expect(queue.single.operation, 'create');

      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['id'], group.id);
      expect(payload['name'], 'Keluarga');
      expect(payload['icon'], 'family');
    });

    test('update menaikkan versi dan stream reaktif', () async {
      final group = await groups.create(name: 'Keluarga');

      final expectation = expectLater(
        groups.watchAll(),
        emitsThrough(
          predicate<List<DebtGroup>>(
            (items) =>
                items.length == 1 && items.single.name == 'Keluarga Besar',
          ),
        ),
      );

      final updated = await groups.update(
        id: group.id,
        expectedVersion: group.version,
        name: 'Keluarga Besar',
        description: null,
        color: null,
        icon: null,
        sortOrder: 2,
      );

      expect(updated.version, 2);
      expect(updated.description, isNull);
      await expectation;

      final queue = await queueDao.listAll();
      expect(queue, hasLength(2));
      final updatePayload =
          jsonDecode(queue.last.payload) as Map<String, dynamic>;
      expect(updatePayload['expected_version'], 1);
      expect(updatePayload['name'], 'Keluarga Besar');
    });

    test('versi lama menjadi konflik', () async {
      final group = await groups.create(name: 'Keluarga');

      await expectLater(
        groups.update(
          id: group.id,
          expectedVersion: 99,
          name: 'Keluarga Besar',
          sortOrder: 1,
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.conflict,
          ),
        ),
      );

      expect((await groups.findById(group.id))?.name, 'Keluarga');
    });

    test('archive idempoten tidak menambah outbox berulang', () async {
      final group = await groups.create(name: 'Keluarga');

      final archived = await groups.setArchived(
        id: group.id,
        expectedVersion: group.version,
        isArchived: true,
      );
      expect(archived.isArchived, isTrue);
      expect(await groups.watchAll().first, isEmpty);

      final queueLength = (await queueDao.listAll()).length;
      final again = await groups.setArchived(
        id: group.id,
        expectedVersion: archived.version,
        isArchived: true,
      );

      expect(again.version, archived.version);
      expect((await queueDao.listAll()).length, queueLength);
    });

    test('validasi warna/icon dan kegagalan outbox', () async {
      await expectLater(
        groups.create(name: 'Warna salah', color: 'teal'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        groups.create(name: 'Ikon salah', icon: 'arbitrary_widget'),
        throwsA(isA<AppException>()),
      );

      final failing = DebtGroupRepositoryImpl(
        database,
        syncQueueDao: _ThrowingSyncQueueDao(database),
        now: _fixedNow,
      );
      await expectLater(
        failing.create(name: 'Gagal'),
        throwsA(isA<StateError>()),
      );

      expect(await database.select(database.debtGroups).get(), isEmpty);
      expect(await queueDao.listAll(), isEmpty);
    });
  });

  group('debt repository', () {
    test('create tanpa customer, pindah group, archive, validasi', () async {
      final group = await groups.create(name: 'Keluarga');
      final debt = await debts.create(
        groupId: group.id,
        title: 'Hutang sembako',
        principalAmount: 1000000,
        dueDate: DateTime.utc(2026, 11, 20, 15, 30),
        notes: 'Catatan',
      );

      expect(debt.groupId, group.id);
      expect(debt.dueDate, DateTime.utc(2026, 11, 20));
      expect(await debts.watchByGroup(group.id).first, hasLength(1));

      final moved = await debts.moveToGroup(
        id: debt.id,
        expectedVersion: debt.version,
        groupId: null,
      );
      expect(moved.groupId, isNull);
      expect(moved.version, 2);
      expect(await debts.watchByGroup(null).first, hasLength(1));

      final archived = await debts.setArchived(
        id: debt.id,
        expectedVersion: moved.version,
        isArchived: true,
      );
      expect(archived.isArchived, isTrue);
      expect(await debts.watchAll().first, isEmpty);

      await expectLater(
        debts.create(title: 'Pokok nol', principalAmount: 0),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        debts.create(
          groupId: '99999999-9999-4999-8999-999999999999',
          title: 'Group hilang',
          principalAmount: 1000,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('payment repository', () {
    test('pembayaran append-only menyimpan total dan outbox', () async {
      final debt = await debts.create(title: 'Hutang', principalAmount: 500000);

      final first = await payments.create(
        debtId: debt.id,
        amount: 150000,
        notes: 'Cicilan pertama',
      );
      final second = await payments.create(debtId: debt.id, amount: 100000);

      expect(second.amount, 100000);
      expect(await payments.totalPaidForDebt(debt.id), 250000);
      expect(await payments.listByDebt(debt.id), hasLength(2));
      expect(await payments.watchByDebt(debt.id).first, hasLength(2));

      final queue = await queueDao.listAll();
      final paymentEntries = queue
          .where((entry) => entry.entityType == 'payment')
          .toList();
      expect(paymentEntries, hasLength(2));
      expect(paymentEntries.first.operation, 'payment_create');
      expect(paymentEntries.first.operationId, first.operationId);

      final payload =
          jsonDecode(paymentEntries.first.payload) as Map<String, dynamic>;
      expect(payload['operation_id'], first.operationId);
      expect(payload['amount'], 150000);

      await expectLater(
        database
            .into(database.payments)
            .insert(
              PaymentRow(
                id: '40000000-0000-4000-8000-000000000099',
                debtId: debt.id,
                amount: 1000,
                paidAt: _fixedNow(),
                notes: null,
                operationId: first.operationId,
                createdAt: _fixedNow(),
                syncState: 'pending',
                serverUpdatedAt: null,
              ),
            ),
        throwsA(isA<Exception>()),
      );

      await expectLater(
        database.customStatement(
          "UPDATE payments SET amount = 1 WHERE id = '${first.id}'",
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database.customStatement(
          "DELETE FROM payments WHERE id = '${first.id}'",
        ),
        throwsA(isA<Exception>()),
      );
      expect(await payments.listByDebt(debt.id), hasLength(2));

      await debts.setArchived(
        id: debt.id,
        expectedVersion: debt.version,
        isArchived: true,
      );
      await expectLater(
        payments.create(debtId: debt.id, amount: 1000),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('sync metadata and seed', () {
    test('menyimpan cursor sinkronisasi', () async {
      final metadata = SyncMetadataDao(database);

      expect(await metadata.getValue('debts'), isNull);
      await metadata.setValue(
        key: 'debts',
        value: '2026-11-12T10:00:00.000Z',
        updatedAt: _fixedNow(),
      );
      expect(await metadata.getValue('debts'), '2026-11-12T10:00:00.000Z');
    });

    test('seed demo lokal tanpa customer dan tanpa outbox', () async {
      expect(await seedDevelopmentData(database, now: _fixedNow()), isTrue);

      expect(await database.select(database.debtGroups).get(), hasLength(2));
      expect(await database.select(database.debts).get(), hasLength(2));
      expect(await database.select(database.payments).get(), hasLength(1));
      expect(await queueDao.listAll(), isEmpty);

      expect(await seedDevelopmentData(database, now: _fixedNow()), isFalse);
    });
  });
}
