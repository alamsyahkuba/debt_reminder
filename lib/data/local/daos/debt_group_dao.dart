import 'package:drift/drift.dart';

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

  Future<DebtGroupRow?> findById(String id) {
    return (_db.select(
      _db.debtGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
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
