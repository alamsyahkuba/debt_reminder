import 'dart:io';

import 'package:debt_reminder/data/local/app_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _memoryDatabase() => AppDatabase(NativeDatabase.memory());

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() {
    database = _memoryDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'schema versi 1 membuka database dan mengaktifkan foreign keys',
    () async {
      await database.ensureOpen();

      expect(database.schemaVersion, 1);

      final pragma = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(pragma.data['foreign_keys'], 1);
    },
  );

  test('membuat seluruh tabel lokal', () async {
    await database.ensureOpen();

    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll(<String>[
        'customers',
        'debt_groups',
        'debts',
        'payments',
        'sync_queue',
        'sync_metadata',
      ]),
    );
  });

  test('foreign key menolak hutang tanpa pelanggan', () async {
    await database.ensureOpen();

    await expectLater(
      database
          .into(database.debts)
          .insert(
            DebtRow(
              id: '30000000-0000-4000-8000-000000000099',
              customerId: '99999999-9999-4999-8999-999999999999',
              groupId: null,
              title: 'Hutang tanpa pelanggan',
              principalAmount: 1000,
              dueDate: null,
              notes: null,
              isArchived: false,
              createdAt: DateTime.utc(2026, 11, 12),
              updatedAt: DateTime.utc(2026, 11, 12),
              version: 1,
              syncState: 'pending',
              serverUpdatedAt: null,
            ),
          ),
      throwsA(isA<Exception>()),
    );

    final debts = await database.select(database.debts).get();
    expect(debts, isEmpty);
  });

  test('database file dapat ditutup dan dibuka kembali', () async {
    final directory = await Directory.systemTemp.createTemp(
      'debt_reminder_database_test',
    );
    final file = File('${directory.path}/app.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.ensureOpen();
    await first
        .into(first.customers)
        .insert(
          CustomerRow(
            id: '10000000-0000-4000-8000-000000000099',
            name: 'Pelanggan Persisten',
            phone: null,
            notes: null,
            isArchived: false,
            createdAt: DateTime.utc(2026, 11, 12),
            updatedAt: DateTime.utc(2026, 11, 12),
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: null,
          ),
        );
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    await second.ensureOpen();
    final customers = await second.select(second.customers).get();
    expect(customers, hasLength(1));
    expect(customers.single.name, 'Pelanggan Persisten');
    await second.close();

    await directory.delete(recursive: true);
  });
}
