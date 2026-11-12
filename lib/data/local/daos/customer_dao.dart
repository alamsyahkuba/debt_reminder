import 'package:drift/drift.dart';

import '../../../domain/entities/customer_summary.dart';
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

  Stream<CustomerRow?> watchById(String id) {
    return (_db.select(
      _db.customers,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Stream<Map<String, CustomerSummary>> watchSummaries() {
    final query = _db.customSelect(
      '''
      SELECT
        d.customer_id AS customer_id,
        COUNT(d.id) AS debt_count,
        COALESCE(SUM(d.principal_amount), 0) AS principal_total,
        COALESCE(SUM(p.paid_total), 0) AS paid_total
      FROM debts d
      LEFT JOIN (
        SELECT debt_id, SUM(amount) AS paid_total
        FROM payments
        GROUP BY debt_id
      ) p ON p.debt_id = d.id
      WHERE d.is_archived = 0
      GROUP BY d.customer_id
      ''',
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watch().map((rows) {
      final summaries = <String, CustomerSummary>{};

      for (final row in rows) {
        final customerId = row.read<String>('customer_id');
        summaries[customerId] = CustomerSummary.fromTotals(
          debtCount: row.read<int>('debt_count'),
          principalTotal: row.read<int>('principal_total'),
          paidTotal: row.read<int>('paid_total'),
        );
      }

      return summaries;
    });
  }

  Stream<CustomerSummary> watchSummary(String customerId) {
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
      WHERE d.customer_id = ? AND d.is_archived = 0
      ''',
      variables: [Variable.withString(customerId)],
      readsFrom: {_db.debts, _db.payments},
    );

    return query.watchSingle().map(
      (row) => CustomerSummary.fromTotals(
        debtCount: row.read<int>('debt_count'),
        principalTotal: row.read<int>('principal_total'),
        paidTotal: row.read<int>('paid_total'),
      ),
    );
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
