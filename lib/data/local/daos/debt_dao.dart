import 'package:drift/drift.dart';

import '../app_database.dart';

class DebtDao {
  DebtDao(this._db);

  final AppDatabase _db;

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

  Future<DebtRow?> findById(String id) {
    return (_db.select(
      _db.debts,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(DebtRow row) async {
    await _db
        .into(_db.debts)
        .insertOnConflictUpdate(
          DebtsCompanion(
            id: Value(row.id),
            customerId: Value(row.customerId),
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
}
