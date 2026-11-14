import 'dart:convert';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 14, 9);

void main() {
  late AppDatabase database;
  late SyncQueueDao queue;
  late DebtGroupRepositoryImpl groups;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = SyncQueueDao(database);
    groups = DebtGroupRepositoryImpl(database, now: _fixedNow);
    debts = DebtRepositoryImpl(database, now: _fixedNow);
    payments = PaymentRepositoryImpl(database, now: _fixedNow);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'hard delete tanpa pembayaran menghapus baris dan enqueue delete',
    () async {
      final group = await groups.create(name: 'Keluarga');
      final debt = await debts.create(
        groupId: group.id,
        title: 'Hutang tanpa pembayaran',
        principalAmount: 500000,
      );

      await debts.delete(id: debt.id, expectedVersion: debt.version);

      expect(await debts.findById(debt.id), isNull);
      expect(await groups.findById(group.id), isNotNull);

      final pending = (await queue.listAll())
          .where((row) => row.entityType == 'debt' && row.operation == 'delete')
          .toList(growable: false);
      expect(pending, hasLength(1));
      expect(pending.single.operation, 'delete');
      expect(pending.single.entityId, debt.id);

      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['id'], debt.id);
      expect(payload['expected_version'], debt.version);
    },
  );

  test('hard delete ditolak jika hutang memiliki pembayaran', () async {
    final debt = await debts.create(
      title: 'Hutang dengan pembayaran',
      principalAmount: 500000,
    );
    final payment = await payments.create(debtId: debt.id, amount: 100000);

    await expectLater(
      debts.delete(id: debt.id, expectedVersion: debt.version),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.validation,
        ),
      ),
    );

    expect(await debts.findById(debt.id), isNotNull);
    expect(
      await (database.select(
        database.payments,
      )..where((row) => row.id.equals(payment.id))).getSingleOrNull(),
      isNotNull,
    );
    expect(
      (await queue.listAll()).where((row) => row.operation == 'delete'),
      isEmpty,
    );
  });

  test('hard delete dengan versi lama tidak mengubah data', () async {
    final debt = await debts.create(
      title: 'Hutang versi lama',
      principalAmount: 500000,
    );

    await expectLater(
      debts.delete(id: debt.id, expectedVersion: 99),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.conflict,
        ),
      ),
    );

    expect(await debts.findById(debt.id), isNotNull);
    expect(
      (await queue.listAll()).where((row) => row.operation == 'delete'),
      isEmpty,
    );
  });
}
