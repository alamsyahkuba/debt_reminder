import 'dart:convert';

import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/customer_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 12, 10);

void main() {
  late AppDatabase database;
  late SyncQueueDao queueDao;
  late CustomerRepositoryImpl customers;
  late DebtGroupRepositoryImpl groups;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queueDao = SyncQueueDao(database);
    customers = CustomerRepositoryImpl(
      database,
      syncQueueDao: queueDao,
      now: _fixedNow,
    );
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

  test('summary group dan pelanggan menghitung pokok, bayar, sisa', () async {
    final customer = await customers.create(name: 'Budi');
    final group = await groups.create(name: 'Keluarga');
    final debt = await debts.create(
      customerId: customer.id,
      groupId: group.id,
      title: 'Hutang',
      principalAmount: 1000000,
    );
    await payments.create(debtId: debt.id, amount: 250000);

    final groupSummary = await groups.watchSummary(group.id).first;
    expect(groupSummary.debtCount, 1);
    expect(groupSummary.principalTotal, 1000000);
    expect(groupSummary.paidTotal, 250000);
    expect(groupSummary.outstandingTotal, 750000);

    final customerSummary = await customers.watchSummary(customer.id).first;
    expect(customerSummary.debtCount, 1);
    expect(customerSummary.outstandingTotal, 750000);

    final allGroups = await groups.watchSummaries().first;
    expect(allGroups[group.id]?.outstandingTotal, 750000);

    final allCustomers = await customers.watchSummaries().first;
    expect(allCustomers[customer.id]?.outstandingTotal, 750000);
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

  test(
    'delete group memindahkan hutang ke Unassigned tanpa menghapus',
    () async {
      final customer = await customers.create(name: 'Budi');
      final group = await groups.create(name: 'Keluarga');
      final debt = await debts.create(
        customerId: customer.id,
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
      final debtPayload =
          jsonDecode(debtUpdate.payload) as Map<String, dynamic>;
      expect(debtPayload['group_id'], isNull);
      expect(debtPayload['expected_version'], 1);
    },
  );

  test('archive pelanggan tidak menghapus histori hutang', () async {
    final customer = await customers.create(name: 'Budi');
    final debt = await debts.create(
      customerId: customer.id,
      title: 'Hutang',
      principalAmount: 100000,
    );

    final archived = await customers.setArchived(
      id: customer.id,
      expectedVersion: customer.version,
      isArchived: true,
    );

    expect(archived.isArchived, isTrue);
    expect(await debts.findById(debt.id), isNotNull);
    expect(await customers.watchAll().first, isEmpty);
    expect(await customers.watchAll(includeArchived: true).first, hasLength(1));
  });

  test('watchById dan watchByCustomer membaca perubahan reaktif', () async {
    final customer = await customers.create(name: 'Budi');
    await debts.create(
      customerId: customer.id,
      title: 'Hutang',
      principalAmount: 100000,
    );

    expect((await customers.watchById(customer.id).first)?.name, 'Budi');
    expect(await debts.watchByCustomer(customer.id).first, hasLength(1));
  });
}
