import '../entities/debt.dart';
import '../entities/debt_draft.dart';
import '../entities/debt_overview.dart';

abstract interface class DebtRepository {
  Stream<List<Debt>> watchAll({bool includeArchived = false});

  Stream<List<DebtOverview>> watchOverviews({bool includeArchived = false});

  Stream<DebtOverview?> watchOverviewById(String id);

  Stream<List<Debt>> watchByGroup(
    String? groupId, {
    bool includeArchived = false,
  });

  Future<Debt?> findById(String id);

  Future<Debt> create({
    String? groupId,
    required String title,
    required int principalAmount,
    DateTime? dueDate,
    String? notes,
  });

  /// Creates up to [maxDebtBatchSize] debts atomically.
  ///
  /// All rows and the single bulk outbox operation are written in one local
  /// transaction. Server sync uses one atomic bulk RPC for the whole batch.
  Future<List<Debt>> createMany({
    String? groupId,
    required List<DebtDraft> drafts,
  });

  Future<Debt> update({
    required String id,
    required int expectedVersion,
    String? groupId,
    required String title,
    required int principalAmount,
    DateTime? dueDate,
    String? notes,
  });

  Future<Debt> moveToGroup({
    required String id,
    required int expectedVersion,
    String? groupId,
  });

  Future<Debt> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  });

  /// Deletes a debt locally and queues the server deletion.
  ///
  /// Only allowed when the debt has no payments. Payments are append-only, so
  /// a debt with payment history must be archived instead.
  Future<void> delete({required String id, required int expectedVersion});
}
