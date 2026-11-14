import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/remote/public_read_repository.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/sync/public_pull_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 13, 10);

class _FakePublicSource implements PublicPullSource {
  _FakePublicSource({
    this.groups = const <PublicDebtGroup>[],
    this.debts = const <PublicDebt>[],
    this.payments = const <PublicPayment>[],
  });

  final List<PublicDebtGroup> groups;
  final List<PublicDebt> debts;
  final List<PublicPayment> payments;
  int groupCalls = 0;
  int debtCalls = 0;
  int paymentCalls = 0;

  @override
  int get pageSize => 2;

  @override
  Future<PublicPage<PublicDebtGroup>> fetchGroups({
    PublicCursor? cursor,
  }) async {
    groupCalls++;
    final start = _startIndex(groups.map((item) => item.id).toList(), cursor);
    final items = groups.skip(start).take(pageSize).toList(growable: false);
    return PublicPage(
      items: items,
      cursor: items.isEmpty
          ? null
          : PublicCursor(timestamp: items.last.updatedAt, id: items.last.id),
    );
  }

  @override
  Future<PublicPage<PublicDebt>> fetchDebts({PublicCursor? cursor}) async {
    debtCalls++;
    final start = _startIndex(debts.map((item) => item.id).toList(), cursor);
    final items = debts.skip(start).take(pageSize).toList(growable: false);
    return PublicPage(
      items: items,
      cursor: items.isEmpty
          ? null
          : PublicCursor(timestamp: items.last.updatedAt, id: items.last.id),
    );
  }

  @override
  Future<PublicPage<PublicPayment>> fetchPayments({
    PublicCursor? cursor,
  }) async {
    paymentCalls++;
    final start = _startIndex(payments.map((item) => item.id).toList(), cursor);
    final items = payments.skip(start).take(pageSize).toList(growable: false);
    return PublicPage(
      items: items,
      cursor: items.isEmpty
          ? null
          : PublicCursor(timestamp: items.last.createdAt, id: items.last.id),
    );
  }

  int _startIndex(List<String> ids, PublicCursor? cursor) {
    if (cursor == null) {
      return 0;
    }
    final index = ids.indexOf(cursor.id);
    return index < 0 ? ids.length : index + 1;
  }
}

PublicDebtGroup _group(String id, String name, DateTime updatedAt) {
  return PublicDebtGroup(
    id: id,
    name: name,
    description: null,
    color: null,
    icon: null,
    sortOrder: 0,
    isArchived: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

PublicDebt _debt(String id, String groupId, DateTime updatedAt) {
  return PublicDebt(
    id: id,
    groupId: groupId,
    title: 'Hutang $id',
    principalAmount: 1000000,
    dueDate: DateTime.utc(2027, 1, 10),
    notes: null,
    isArchived: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

PublicPayment _payment(String id, String debtId, DateTime createdAt) {
  return PublicPayment(
    id: id,
    debtId: debtId,
    amount: 250000,
    paidAt: createdAt,
    notes: null,
    createdAt: createdAt,
  );
}

void main() {
  late AppDatabase database;
  late SyncQueueDao queue;
  late DebtGroupRepositoryImpl localGroups;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = SyncQueueDao(database);
    localGroups = DebtGroupRepositoryImpl(database, now: _fixedNow);
  });

  tearDown(() async {
    await database.close();
  });

  test('public pull memakai pagination dan tidak membuat outbox', () async {
    final source = _FakePublicSource(
      groups: <PublicDebtGroup>[
        _group('g1', 'Satu', DateTime.utc(2026, 11, 13, 9)),
        _group('g2', 'Dua', DateTime.utc(2026, 11, 13, 10)),
        _group('g3', 'Tiga', DateTime.utc(2026, 11, 13, 11)),
      ],
      debts: <PublicDebt>[_debt('d1', 'g1', DateTime.utc(2026, 11, 13, 9))],
      payments: <PublicPayment>[
        _payment('p1', 'd1', DateTime.utc(2026, 11, 13, 9)),
      ],
    );
    final service = PublicPullService(
      database: database,
      repository: source,
      now: _fixedNow,
    );

    final result = await service.pull(full: true);

    expect(result.groups, 3);
    expect(result.debts, 1);
    expect(result.payments, 1);
    expect(source.groupCalls, 2);
    expect(source.debtCalls, 1);
    expect(source.paymentCalls, 1);
    expect(await database.select(database.debtGroups).get(), hasLength(3));
    expect(await database.select(database.debts).get(), hasLength(1));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(await queue.listAll(), isEmpty);

    final second = await service.pull();
    expect(second.groups, 0);
    expect(second.debts, 0);
    expect(second.payments, 0);
  });

  test('public pull tidak menimpa perubahan lokal yang belum synced', () async {
    final local = await localGroups.create(name: 'Lokal');
    final source = _FakePublicSource(
      groups: <PublicDebtGroup>[
        _group(local.id, 'Server', DateTime.utc(2026, 11, 13, 12)),
      ],
    );
    final service = PublicPullService(
      database: database,
      repository: source,
      now: _fixedNow,
    );

    await service.pull();

    final stored = await database.select(database.debtGroups).getSingle();
    expect(stored.name, 'Lokal');
    expect(stored.syncState, 'pending');
    expect(await queue.listAll(), hasLength(1));
  });

  test(
    'full pull menghapus group synced yang sudah tidak ada di server',
    () async {
      await database
          .into(database.debtGroups)
          .insert(
            DebtGroupRow(
              id: 'sync-group',
              name: 'Lama',
              description: null,
              color: null,
              icon: null,
              sortOrder: 0,
              isArchived: false,
              createdAt: _fixedNow(),
              updatedAt: _fixedNow(),
              version: 1,
              syncState: 'synced',
              serverUpdatedAt: _fixedNow(),
            ),
          );
      final service = PublicPullService(
        database: database,
        repository: _FakePublicSource(),
        now: _fixedNow,
      );

      await service.pull(full: true);

      expect(await database.select(database.debtGroups).get(), isEmpty);
    },
  );

  test(
    'full pull mempertahankan group yang direferensikan debt pending',
    () async {
      final group = await localGroups.create(name: 'Lokal');
      await database.customStatement(
        "UPDATE debt_groups SET sync_state = 'synced' WHERE id = '${group.id}'",
      );
      final debts = DebtRepositoryImpl(database, now: _fixedNow);
      final debt = await debts.create(
        groupId: group.id,
        title: 'Hutang belum sync',
        principalAmount: 100000,
      );
      final service = PublicPullService(
        database: database,
        repository: _FakePublicSource(),
        now: _fixedNow,
      );

      await service.pull(full: true);

      final storedGroup = await localGroups.findById(group.id);
      final storedDebt = await debts.findById(debt.id);
      expect(storedGroup, isNotNull);
      expect(storedDebt?.groupId, group.id);
      expect(await queue.listAll(), hasLength(2));
    },
  );

  test('full pull menghapus debt synced yang tidak ada di server', () async {
    await database
        .into(database.debts)
        .insert(
          DebtRow(
            id: 'sync-debt',
            groupId: null,
            title: 'Hutang lama',
            principalAmount: 100000,
            dueDate: null,
            notes: null,
            isArchived: false,
            createdAt: _fixedNow(),
            updatedAt: _fixedNow(),
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: _fixedNow(),
          ),
        );
    final service = PublicPullService(
      database: database,
      repository: _FakePublicSource(),
      now: _fixedNow,
    );

    await service.pull(full: true);

    expect(await database.select(database.debts).get(), isEmpty);
  });

  test(
    'full pull mempertahankan debt pending yang tidak ada di server',
    () async {
      final debts = DebtRepositoryImpl(database, now: _fixedNow);
      final pending = await debts.create(
        title: 'Hutang lokal',
        principalAmount: 100000,
      );
      final service = PublicPullService(
        database: database,
        repository: _FakePublicSource(),
        now: _fixedNow,
      );

      await service.pull(full: true);

      expect(await debts.findById(pending.id), isNotNull);
      expect(await queue.listAll(), hasLength(1));
    },
  );

  test(
    'full pull mempertahankan debt conflict yang tidak ada di server',
    () async {
      await database
          .into(database.debts)
          .insert(
            DebtRow(
              id: 'conflict-debt',
              groupId: null,
              title: 'Hutang konflik',
              principalAmount: 100000,
              dueDate: null,
              notes: null,
              isArchived: false,
              createdAt: _fixedNow(),
              updatedAt: _fixedNow(),
              version: 2,
              syncState: 'conflict',
              serverUpdatedAt: _fixedNow(),
            ),
          );
      final service = PublicPullService(
        database: database,
        repository: _FakePublicSource(),
        now: _fixedNow,
      );

      await service.pull(full: true);

      expect(await database.select(database.debts).get(), hasLength(1));
    },
  );

  test(
    'full pull tidak menghapus debt yang masih memiliki pembayaran lokal',
    () async {
      await database
          .into(database.debts)
          .insert(
            DebtRow(
              id: 'sync-debt-paid',
              groupId: null,
              title: 'Hutang dengan pembayaran',
              principalAmount: 100000,
              dueDate: null,
              notes: null,
              isArchived: false,
              createdAt: _fixedNow(),
              updatedAt: _fixedNow(),
              version: 1,
              syncState: 'synced',
              serverUpdatedAt: _fixedNow(),
            ),
          );
      await database
          .into(database.payments)
          .insert(
            PaymentRow(
              id: 'sync-payment',
              debtId: 'sync-debt-paid',
              amount: 50000,
              paidAt: _fixedNow(),
              notes: null,
              operationId: 'sync-payment-operation',
              createdAt: _fixedNow(),
              syncState: 'synced',
              serverUpdatedAt: _fixedNow(),
            ),
          );
      final service = PublicPullService(
        database: database,
        repository: _FakePublicSource(),
        now: _fixedNow,
      );

      await service.pull(full: true);

      expect(await database.select(database.debts).get(), hasLength(1));
      expect(await database.select(database.payments).get(), hasLength(1));
    },
  );

  test('pull inkremental tidak menghapus debt synced yang absen', () async {
    await database
        .into(database.debts)
        .insert(
          DebtRow(
            id: 'sync-debt',
            groupId: null,
            title: 'Hutang lama',
            principalAmount: 100000,
            dueDate: null,
            notes: null,
            isArchived: false,
            createdAt: _fixedNow(),
            updatedAt: _fixedNow(),
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: _fixedNow(),
          ),
        );
    final service = PublicPullService(
      database: database,
      repository: _FakePublicSource(),
      now: _fixedNow,
    );

    await service.pull();

    expect(await database.select(database.debts).get(), hasLength(1));
  });
}
