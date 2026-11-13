import 'package:drift/drift.dart';

import '../../../domain/entities/group_summary.dart';
import '../app_database.dart';

class DebtGroupDao {
  DebtGroupDao(this._db);

  final AppDatabase _db;

  Stream<List<DebtGroupRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.debtGroups);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm.asc(table.sortOrder),
      (table) => OrderingTerm.asc(table.name),
    ]);
    return query.watch();
  }

  Stream<DebtGroupRow?> watchById(String id) {
    return (_db.select(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Stream<Map<String, GroupSummary>> watchSummaries() {
    final query = _db.customSelect(
      '''
      SELECT
        d.group_id AS group_id,
        COUNT(d.id) AS debt_count,
        COALESCE(SUM(d.principal_amount), 0) AS principal_total,
        COALESCE(SUM(p.paid_total), 0) AS paid_total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) AS paid_total
        FROM payments
        GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.is_archived = 0 AND d.group_id IS NOT NULL
      GROUP BY d.group_id
      ''',
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watch().map((rows) {
      final summaries = <String, GroupSummary>{};

      for (final row in rows) {
        final groupId = row.read<String>('group_id');
        summaries[groupId] = GroupSummary.fromTotals(
          debtCount: row.read<int>('debt_count'),
          principalTotal: row.read<int>('principal_total'),
          paidTotal: row.read<int>('paid_total'),
        );
      }

      return summaries;
    });
  }

  Stream<GroupSummary> watchSummary(String groupId) {
    final query = _db.customSelect(
      '''
      SELECT
        COUNT(d.id) AS debt_count,
        COALESCE(SUM(d.principal_amount), 0) AS principal_total,
        COALESCE(SUM(p.paid_total), 0) AS paid_total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) AS paid_total
        FROM payments
        GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.group_id = ? AND d.is_archived = 0
      ''',
      variables: [Variable.withString(groupId)],
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watchSingle().map(
      (row) => GroupSummary.fromTotals(
        debtCount: row.read<int>('debt_count'),
        principalTotal: row.read<int>('principal_total'),
        paidTotal: row.read<int>('paid_total'),
      ),
    );
  }

  Future<DebtGroupRow?> findById(String id) {
    return (_db.select(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> markSynced({
    required String id,
    required int version,
    required DateTime serverUpdatedAt,
  }) async {
    await (_db.update(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).write(
      DebtGroupsCompanion(
        version: Value(version),
        syncState: const Value('synced'),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  Future<void> markConflict(String id) async {
    await (_db.update(_db.debtGroups)..where((table) => table.id.equals(id)))
        .write(const DebtGroupsCompanion(syncState: Value('conflict')));
  }

  Future<void> prepareConflictRetry({
    required String id,
    required int serverVersion,
    required DateTime serverUpdatedAt,
  }) async {
    await (_db.update(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).write(
      DebtGroupsCompanion(
        version: Value(serverVersion),
        syncState: const Value('pending'),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  Future<List<DebtGroupRow>> listAll() {
    return _db.select(_db.debtGroups).get();
  }

  Future<void> upsert(DebtGroupRow row) async {
    await _db
        .into(_db.debtGroups)
        .insertOnConflictUpdate(
          DebtGroupsCompanion(
            id: Value(row.id),
            name: Value(row.name),
            description: Value(row.description),
            color: Value(row.color),
            icon: Value(row.icon),
            sortOrder: Value(row.sortOrder),
            isArchived: Value(row.isArchived),
            createdAt: Value(row.createdAt),
            updatedAt: Value(row.updatedAt),
            version: Value(row.version),
            syncState: Value(row.syncState),
            serverUpdatedAt: Value(row.serverUpdatedAt),
          ),
        );
  }
}
