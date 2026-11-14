import 'dart:convert';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/domain/entities/debt_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 14, 10);

void main() {
  late AppDatabase database;
  late SyncQueueDao queue;
  late DebtGroupRepositoryImpl groups;
  late DebtRepositoryImpl debts;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = SyncQueueDao(database);
    groups = DebtGroupRepositoryImpl(database, now: _fixedNow);
    debts = DebtRepositoryImpl(database, now: _fixedNow);
  });

  tearDown(() async {
    await database.close();
  });

  test('createMany menyimpan semua hutang dan satu outbox batch', () async {
    final group = await groups.create(name: 'Keluarga');
    final drafts = <DebtDraft>[
      const DebtDraft(
        title: 'Hutang satu',
        principalAmount: 100000,
        dueDate: null,
        notes: 'Catatan satu',
      ),
      const DebtDraft(
        title: 'Hutang dua',
        principalAmount: 200000,
        dueDate: null,
      ),
      DebtDraft(
        title: 'Hutang tiga',
        principalAmount: 300000,
        dueDate: DateTime.utc(2027, 1, 10, 15, 30),
      ),
    ];

    final created = await debts.createMany(groupId: group.id, drafts: drafts);

    expect(created, hasLength(3));
    expect(created.every((debt) => debt.groupId == group.id), isTrue);
    expect(created.every((debt) => debt.version == 1), isTrue);
    expect(created.map((debt) => debt.createdAt).toSet(), <DateTime>{
      _fixedNow(),
    });
    expect(created[2].dueDate, DateTime.utc(2027, 1, 10));

    final stored = await database.select(database.debts).get();
    expect(stored, hasLength(3));
    expect(stored.every((row) => row.syncState == 'pending'), isTrue);

    final queued = (await queue.listAll())
        .where((row) => row.entityType == 'debt_batch')
        .toList();
    expect(queued, hasLength(1));
    final operation = queued.single;
    expect(operation.entityType, 'debt_batch');
    expect(operation.operation, 'create');

    final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
    expect(payload['id'], operation.entityId);
    final payloadDebts = payload['debts'] as List<dynamic>;
    expect(payloadDebts, hasLength(3));
    expect(
      payloadDebts.map((item) => (item as Map<String, dynamic>)['id']).toSet(),
      created.map((debt) => debt.id).toSet(),
    );
    expect(
      payloadDebts
          .map((item) => (item as Map<String, dynamic>)['title'])
          .toList(),
      <String>['Hutang satu', 'Hutang dua', 'Hutang tiga'],
    );
  });

  test('satu baris invalid membatalkan seluruh batch', () async {
    final drafts = <DebtDraft>[
      const DebtDraft(title: 'Valid', principalAmount: 100000),
      const DebtDraft(title: '', principalAmount: 200000),
      const DebtDraft(title: 'Valid dua', principalAmount: 300000),
    ];

    await expectLater(
      debts.createMany(drafts: drafts),
      throwsA(isA<AppException>()),
    );

    expect(await database.select(database.debts).get(), isEmpty);
    expect(await queue.listAll(), isEmpty);
  });

  test('group yang hilang membatalkan seluruh batch', () async {
    await expectLater(
      debts.createMany(
        groupId: '99999999-9999-4999-8999-999999999999',
        drafts: <DebtDraft>[
          const DebtDraft(title: 'Satu', principalAmount: 1000),
          const DebtDraft(title: 'Dua', principalAmount: 2000),
        ],
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'Group tidak ditemukan.',
        ),
      ),
    );

    expect(await database.select(database.debts).get(), isEmpty);
    expect(await queue.listAll(), isEmpty);
  });

  test('batch kosong dan lebih dari 50 ditolak', () async {
    await expectLater(
      debts.createMany(drafts: const <DebtDraft>[]),
      throwsA(isA<AppException>()),
    );

    final tooMany = List<DebtDraft>.generate(
      maxDebtBatchSize + 1,
      (index) => DebtDraft(
        title: 'Hutang ${index + 1}',
        principalAmount: 1000 + index,
      ),
    );
    await expectLater(
      debts.createMany(drafts: tooMany),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'Maksimal $maxDebtBatchSize hutang per batch.',
        ),
      ),
    );

    expect(await database.select(database.debts).get(), isEmpty);
    expect(await queue.listAll(), isEmpty);
  });

  test('batch dengan group null tetap tersimpan sebagai Unassigned', () async {
    final created = await debts.createMany(
      groupId: null,
      drafts: <DebtDraft>[
        const DebtDraft(title: 'Tanpa group', principalAmount: 1000),
      ],
    );

    expect(created.single.groupId, isNull);
    expect(await debts.watchByGroup(null).first, hasLength(1));
    expect((await queue.listAll()).single.entityType, 'debt_batch');
  });
}
