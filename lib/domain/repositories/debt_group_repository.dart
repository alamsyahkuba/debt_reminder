import '../entities/debt_group.dart';
import '../entities/group_summary.dart';

abstract interface class DebtGroupRepository {
  Stream<List<DebtGroup>> watchAll({bool includeArchived = false});

  Stream<DebtGroup?> watchById(String id);

  Stream<GroupSummary> watchSummary(String id);

  Stream<Map<String, GroupSummary>> watchSummaries();

  Future<DebtGroup?> findById(String id);

  Future<DebtGroup> create({
    required String name,
    String? description,
    String? color,
    String? icon,
    int sortOrder = 0,
  });

  Future<DebtGroup> update({
    required String id,
    required int expectedVersion,
    required String name,
    String? description,
    String? color,
    String? icon,
    required int sortOrder,
  });

  Future<DebtGroup> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  });

  /// Deletes the group and moves every debt in it to Unassigned.
  ///
  /// Returns the number of debts moved. Debts are never deleted.
  Future<int> delete({required String id, required int expectedVersion});
}
