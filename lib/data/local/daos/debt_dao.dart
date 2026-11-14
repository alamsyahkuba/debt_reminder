import 'package:drift/drift.dart';

import '../app_database.dart';

class DebtWithPaidRow {
  const DebtWithPaidRow({required this.debt, required this.paidAmount});

  final DebtRow debt;
  final int paidAmount;
}

class DebtDao {
  DebtDao(this._db);

  final AppDatabase _db;

  Stream<List<DebtWithPaidRow>> watchOverviews({bool includeArchived = false}) {
    final archivedFilter = includeArchived ? '' : 'WHERE d.is_archived = 0';
    final query = _db.customSelect(
      '''
      SELECT d.*, COALESCE(paid.paid_total, 0) AS paid_total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) AS paid_total
        FROM payments
        GROUP BY debt_id
      ) paid ON paid.debt_id = d.id
      $archivedFilter
      ORDER BY d.due_date IS NULL, d.due_date, d.created_at DESC
      ''',
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watch().map(
      (rows) => rows.map(_mapOverview).toList(growable: false),
    );
  }

  Stream<DebtWithPaidRow?> watchOverviewById(String id) {
    final query = _db.customSelect(
      '''
      SELECT d.*, COALESCE(paid.paid_total, 0) AS paid_total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) AS paid_total
        FROM payments
        GROUP BY debt_id
      ) paid ON paid.debt_id = d.id
      WHERE d.id = ?
      ''',
      variables: [Variable.withString(id)],
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _mapOverview(row),
    );
  }

  DebtWithPaidRow _mapOverview(QueryRow row) {
    return DebtWithPaidRow(
      debt: DebtRow(
        id: row.read<String>('id'),
        groupId: row.read<String?>('group_id'),
        title: row.read<String>('title'),
        principalAmount: row.read<int>('principal_amount'),
        dueDate: row.read<DateTime?>('due_date'),
        notes: row.read<String?>('notes'),
        isArchived: row.read<int>('is_archived') == 1,
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
        version: row.read<int>('version'),
        syncState: row.read<String>('sync_state'),
        serverUpdatedAt: row.read<DateTime?>('server_updated_at'),
      ),
      paidAmount: row.read<int>('paid_total'),
    );
  }

  Stream<List<DebtRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.debts);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm.asc(table.dueDate),
      (table) => OrderingTerm.asc(table.createdAt),
    ]);
    return query.watch();
  }

  Stream<List<DebtRow>> watchByGroup(
    String? groupId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.debts);
    query.where((table) {
      var predicate = includeArchived
          ? const Constant(true)
          : table.isArchived.equals(false);

      predicate = groupId == null
          ? predicate & table.groupId.isNull()
          : predicate & table.groupId.equals(groupId);

      return predicate;
    });
    query.orderBy([
      (table) => OrderingTerm.asc(table.dueDate),
      (table) => OrderingTerm.asc(table.createdAt),
    ]);
    return query.watch();
  }

  Future<List<DebtRow>> listByGroup(
    String groupId, {
    bool includeArchived = true,
  }) {
    final query = _db.select(_db.debts);
    query.where((table) {
      var predicate = table.groupId.equals(groupId);
      if (!includeArchived) {
        predicate = predicate & table.isArchived.equals(false);
      }
      return predicate;
    });

    return query.get();
  }

  Future<DebtRow?> findById(String id) {
    return (_db.select(
      _db.debts,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<void> markSynced({
    required String id,
    required int version,
    required DateTime serverUpdatedAt,
  }) async {
    await (_db.update(_db.debts)..where((table) => table.id.equals(id))).write(
      DebtsCompanion(
        version: Value(version),
        syncState: const Value('synced'),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  Future<void> markConflict(String id) async {
    await (_db.update(_db.debts)..where((table) => table.id.equals(id))).write(
      const DebtsCompanion(syncState: Value('conflict')),
    );
  }

  Future<void> prepareConflictRetry({
    required String id,
    required int serverVersion,
    required DateTime serverUpdatedAt,
  }) async {
    await (_db.update(_db.debts)..where((table) => table.id.equals(id))).write(
      DebtsCompanion(
        version: Value(serverVersion),
        syncState: const Value('pending'),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  Future<void> upsert(DebtRow row) async {
    await _db
        .into(_db.debts)
        .insertOnConflictUpdate(
          DebtsCompanion(
            id: Value(row.id),
            groupId: Value(row.groupId),
            title: Value(row.title),
            principalAmount: Value(row.principalAmount),
            dueDate: Value(row.dueDate),
            notes: Value(row.notes),
            isArchived: Value(row.isArchived),
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            version: Value(row.version),
            syncState: Value(row.syncState),
            serverUpdatedAt: Value(row.serverUpdatedAt),
          ),
        );
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.debts)..where((table) => table.id.equals(id))).go();
  }

  Future<List<DebtRow>> listAll() {
    return (_db.select(
      _db.debts,
    )..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();
  }
}
