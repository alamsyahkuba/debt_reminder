import '../entities/debt.dart';

abstract interface class DebtRepository {
  Stream<List<Debt>> watchAll({bool includeArchived = false});

  Stream<List<Debt>> watchByGroup(
    String? groupId, {
    bool includeArchived = false,
  });

  Future<Debt?> findById(String id);

  Future<Debt> create({
    required String customerId,
    String? groupId,
    required String title,
    required int principalAmount,
    DateTime? dueDate,
    String? notes,
  });

  Future<Debt> update({
    required String id,
    required int expectedVersion,
    required String customerId,
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
}
