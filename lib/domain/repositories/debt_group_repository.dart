import '../entities/debt_group.dart';

abstract interface class DebtGroupRepository {
  Stream<List<DebtGroup>> watchAll({bool includeArchived = false});

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
}
