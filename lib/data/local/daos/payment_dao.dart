import 'package:drift/drift.dart';

import '../app_database.dart';

class PaymentDao {
  PaymentDao(this._db);

  final AppDatabase _db;

  Stream<List<PaymentRow>> watchByDebt(String debtId) {
    final query = _db.select(_db.payments)
      ..where((table) => table.debtId.equals(debtId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.paidAt),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);

    return query.watch();
  }

  Future<List<PaymentRow>> listByDebt(String debtId) {
    final query = _db.select(_db.payments)
      ..where((table) => table.debtId.equals(debtId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.paidAt),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);

    return query.get();
  }

  Future<void> insert(PaymentRow row) async {
    await _db.into(_db.payments).insert(row);
  }

  Future<int> totalPaidForDebt(String debtId) async {
    final sum = _db.payments.amount.sum();
    final query = _db.selectOnly(_db.payments)
      ..addColumns([sum])
      ..where(_db.payments.debtId.equals(debtId));

    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }
}
