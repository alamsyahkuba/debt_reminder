import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Local business data mirroring the Supabase schema.
///
/// Every mutable business row carries a local `syncState`, a server version,
/// and a server update timestamp. Writes are combined with an outbox entry in
/// the same SQLite transaction by the repository layer.
@DataClassName('CustomerRow')
@TableIndex(name: 'customers_name_idx', columns: {#name})
@TableIndex(name: 'customers_archived_idx', columns: {#isArchived})
@TableIndex(name: 'customers_sync_idx', columns: {#updatedAt})
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DebtGroupRow')
@TableIndex(name: 'debt_groups_sort_idx', columns: {#sortOrder, #name})
@TableIndex(name: 'debt_groups_archived_idx', columns: {#isArchived})
@TableIndex(name: 'debt_groups_sync_idx', columns: {#updatedAt})
class DebtGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DebtRow')
@TableIndex(name: 'debts_customer_idx', columns: {#customerId})
@TableIndex(name: 'debts_group_idx', columns: {#groupId})
@TableIndex(name: 'debts_due_date_idx', columns: {#dueDate})
@TableIndex(name: 'debts_archived_idx', columns: {#isArchived})
@TableIndex(name: 'debts_sync_idx', columns: {#updatedAt})
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get groupId => text().nullable().references(
    DebtGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get principalAmount => integer()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PaymentRow')
@TableIndex(name: 'payments_debt_idx', columns: {#debtId})
@TableIndex(name: 'payments_created_idx', columns: {#createdAt})
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount => integer()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get operationId => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncQueueRow')
@TableIndex(name: 'sync_queue_status_idx', columns: {#status, #nextRetryAt})
@TableIndex(name: 'sync_queue_entity_idx', columns: {#entityType, #entityId})
class SyncQueue extends Table {
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: <Type>[
    Customers,
    DebtGroups,
    Debts,
    Payments,
    SyncQueue,
    SyncMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'debt_reminder'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('''
        CREATE TRIGGER payments_no_update
        BEFORE UPDATE ON payments
        BEGIN
          SELECT RAISE(ABORT, 'payments are append-only');
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER payments_no_delete
        BEFORE DELETE ON payments
        BEGIN
          SELECT RAISE(ABORT, 'payments are append-only');
        END;
      ''');
    },
    onUpgrade: (migrator, from, to) async {
      // Version 1 is the initial schema. Every future schema change must add an
      // explicit migration step and a migration test.
      throw UnsupportedError(
        'Migrasi database dari versi $from ke $to belum tersedia.',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Forces the database to open and validates the connection.
  Future<void> ensureOpen() async {
    await customSelect('SELECT 1').getSingle();
  }
}
