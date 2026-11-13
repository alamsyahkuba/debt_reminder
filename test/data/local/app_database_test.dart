import 'dart:io';

import 'package:debt_reminder/data/local/app_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
    'schema versi 4 membuka database dan mengaktifkan foreign keys',
    () async {
      await database.ensureOpen();

      expect(database.schemaVersion, 4);

      final pragma = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(pragma.data['foreign_keys'], 1);
    },
  );

  test('membuat seluruh tabel lokal tanpa customers', () async {
    await database.ensureOpen();

    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll(<String>[
        'debt_groups',
        'debts',
        'payments',
        'sync_queue',
        'sync_metadata',
        'local_settings',
      ]),
    );
    expect(tableNames, isNot(contains('customers')));
  });

  test('debts tidak memiliki customer_id', () async {
    await database.ensureOpen();

    final columns = await database
        .customSelect('PRAGMA table_info(debts)')
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();

    expect(columnNames, isNot(contains('customer_id')));
  });

  test('sync_queue memiliki conflict_data untuk resolusi konflik', () async {
    await database.ensureOpen();

    final columns = await database
        .customSelect('PRAGMA table_info(sync_queue)')
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();

    expect(columnNames, contains('conflict_data'));
  });

  test('foreign key menolak pembayaran tanpa hutang', () async {
    await database.ensureOpen();

    await expectLater(
      database
          .into(database.payments)
          .insert(
            PaymentRow(
              id: '40000000-0000-4000-8000-000000000099',
              debtId: '99999999-9999-4999-8999-999999999999',
              amount: 1000,
              paidAt: DateTime.utc(2026, 11, 12),
              notes: null,
              operationId: '90000000-0000-4000-8000-000000000099',
              createdAt: DateTime.utc(2026, 11, 12),
              syncState: 'pending',
              serverUpdatedAt: null,
            ),
          ),
      throwsA(isA<Exception>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);
  });

  test('database v1 lama di-reset ke schema v4 tanpa customer', () async {
    final directory = await Directory.systemTemp.createTemp(
      'debt_reminder_migration_test',
    );
    final file = File('${directory.path}/old.sqlite');

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT)');
    raw.execute('CREATE TABLE debt_groups (id TEXT PRIMARY KEY)');
    raw.execute(
      'CREATE TABLE debts (id TEXT PRIMARY KEY, customer_id TEXT, group_id TEXT)',
    );
    raw.execute('CREATE TABLE payments (id TEXT PRIMARY KEY)');
    raw.execute('CREATE TABLE sync_queue (operation_id TEXT PRIMARY KEY)');
    raw.execute('CREATE TABLE sync_metadata (key TEXT PRIMARY KEY)');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    await upgraded.ensureOpen();

    expect(upgraded.schemaVersion, 4);

    final tables = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = tables.map((row) => row.read<String>('name')).toSet();
    expect(tableNames, isNot(contains('customers')));

    final columns = await upgraded
        .customSelect('PRAGMA table_info(debts)')
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();
    expect(columnNames, isNot(contains('customer_id')));

    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test('database file dapat ditutup dan dibuka kembali', () async {
    final directory = await Directory.systemTemp.createTemp(
      'debt_reminder_database_test',
    );
    final file = File('${directory.path}/app.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.ensureOpen();
    await first
        .into(first.debtGroups)
        .insert(
          DebtGroupRow(
            id: '20000000-0000-4000-8000-000000000099',
            name: 'Group Persisten',
            description: null,
            color: null,
            icon: null,
            sortOrder: 0,
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
    final groups = await second.select(second.debtGroups).get();
    expect(groups, hasLength(1));
    expect(groups.single.name, 'Group Persisten');
    await second.close();

    await directory.delete(recursive: true);
  });
}
