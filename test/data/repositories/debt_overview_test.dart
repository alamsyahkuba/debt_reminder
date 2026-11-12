import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/domain/entities/debt_status.dart';
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

  test('overview menghitung paid, outstanding, dan status turunan', () async {
    final group = await groups.create(name: 'Keluarga');

    final unpaid = await debts.create(
      groupId: group.id,
      title: 'Unpaid',
      principalAmount: 100000,
      dueDate: DateTime.utc(2026, 12, 1),
    );
    final partial = await debts.create(
      groupId: group.id,
      title: 'Partial',
      principalAmount: 1000000,
      dueDate: DateTime.utc(2026, 12, 1),
    );
    final paid = await debts.create(
      groupId: group.id,
      title: 'Paid',
      principalAmount: 200000,
      dueDate: DateTime.utc(2026, 12, 1),
    );
    final overdue = await debts.create(
      groupId: group.id,
      title: 'Overdue',
      principalAmount: 300000,
      dueDate: DateTime.utc(2026, 11, 1),
    );

    await payments.create(debtId: partial.id, amount: 250000);
    await payments.create(debtId: paid.id, amount: 200000);

    final overviews = await debts.watchOverviews().first;
    final byId = {for (final item in overviews) item.debt.id: item};

    expect(byId[unpaid.id]?.status, DebtStatus.unpaid);
    expect(byId[unpaid.id]?.paidAmount, 0);
    expect(byId[unpaid.id]?.outstandingAmount, 100000);

    expect(byId[partial.id]?.status, DebtStatus.partial);
    expect(byId[partial.id]?.paidAmount, 250000);
    expect(byId[partial.id]?.outstandingAmount, 750000);

    expect(byId[paid.id]?.status, DebtStatus.paid);
    expect(byId[paid.id]?.outstandingAmount, 0);

    expect(byId[overdue.id]?.status, DebtStatus.overdue);

    final single = await debts.watchOverviewById(partial.id).first;
    expect(single?.status, DebtStatus.partial);
    expect(single?.paidAmount, 250000);

    await debts.setArchived(
      id: unpaid.id,
      expectedVersion: unpaid.version,
      isArchived: true,
    );
    final active = await debts.watchOverviews().first;
    expect(active, hasLength(3));
    expect(active.any((item) => item.debt.id == unpaid.id), isFalse);
  });
}
