import 'package:drift/drift.dart';

import '../app_database.dart';

class CustomerDao {
  CustomerDao(this._db);

  final AppDatabase _db;

  Stream<List<CustomerRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.customers);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<CustomerRow?> findById(String id) {
    return (_db.select(
      _db.customers,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<CustomerRow?> findByName(String name) {
    return (_db.select(_db.customers)
          ..where((table) => table.name.equals(name))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsert(CustomerRow row) async {
    // A companion is used instead of the row so nullable columns are written
    // explicitly, including when they are cleared to null.
    await _db
        .into(_db.customers)
        .insertOnConflictUpdate(
          CustomersCompanion(
            id: Value(row.id),
            name: Value(row.name),
            phone: Value(row.phone),
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
