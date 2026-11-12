import 'dart:convert';

import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 12, 10);

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

  test('summary group menghitung pokok, bayar, dan sisa', () async {
    final group = await groups.create(name: 'Keluarga');
    final debt = await debts.create(
      groupId: group.id,
      title: 'Hutang',
      principalAmount: 1000000,
    );
    await payments.create(debtId: debt.id, amount: 250000);

    final summary = await groups.watchSummary(group.id).first;
    expect(summary.debtCount, 1);
    expect(summary.principalTotal, 1000000);
    expect(summary.paidTotal, 250000);
    expect(summary.outstandingTotal, 750000);

    final summaries = await groups.watchSummaries().first;
    expect(summaries[group.id]?.outstandingTotal, 750000);
  });

  test('group dapat diarsipkan dan dipulihkan', () async {
    final group = await groups.create(name: 'Keluarga');

    final archived = await groups.setArchived(
      id: group.id,
      expectedVersion: group.version,
      isArchived: true,
    );
    expect(await groups.watchAll().first, isEmpty);
    expect(await groups.watchAll(includeArchived: true).first, hasLength(1));

    final restored = await groups.setArchived(
      id: group.id,
      expectedVersion: archived.version,
      isArchived: false,
    );
    expect(restored.isArchived, isFalse);
    expect(await groups.watchAll().first, hasLength(1));
  });

  test('delete group memindahkan hutang ke Unassigned', () async {
    final group = await groups.create(name: 'Keluarga');
    final debt = await debts.create(
      groupId: group.id,
      title: 'Hutang keluarga',
      principalAmount: 500000,
    );
    await payments.create(debtId: debt.id, amount: 100000);

    final movedCount = await groups.delete(
      id: group.id,
      expectedVersion: group.version,
    );

    expect(movedCount, 1);
    expect(await groups.findById(group.id), isNull);

    final storedDebt = await debts.findById(debt.id);
    expect(storedDebt, isNotNull);
    expect(storedDebt?.groupId, isNull);
    expect(storedDebt?.version, 2);
    expect(await payments.totalPaidForDebt(debt.id), 100000);
    expect(await debts.watchByGroup(null).first, hasLength(1));

    final queue = await queueDao.listAll();
    final groupDelete = queue.last;
    expect(groupDelete.entityType, 'debt_group');
    expect(groupDelete.operation, 'delete');
    final payload = jsonDecode(groupDelete.payload) as Map<String, dynamic>;
    expect(payload['move_debts_to_unassigned'], isTrue);

    final debtUpdate = queue.firstWhere(
      (entry) => entry.entityType == 'debt' && entry.operation == 'update',
    );
    final debtPayload = jsonDecode(debtUpdate.payload) as Map<String, dynamic>;
    expect(debtPayload['group_id'], isNull);
    expect(debtPayload['expected_version'], 1);
    expect(debtPayload.containsKey('customer_id'), isFalse);
  });

  test('watchById membaca perubahan group secara reaktif', () async {
    final group = await groups.create(name: 'Keluarga');

    final updated = await groups.update(
      id: group.id,
      expectedVersion: group.version,
      name: 'Keluarga Baru',
      sortOrder: 1,
    );

    expect(updated.version, 2);
    expect((await groups.watchById(group.id).first)?.name, 'Keluarga Baru');
  });
}
