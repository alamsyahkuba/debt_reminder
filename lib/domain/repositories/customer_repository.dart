import '../entities/customer.dart';

abstract interface class CustomerRepository {
  Stream<List<Customer>> watchAll({bool includeArchived = false});

  Future<Customer?> findById(String id);

  Future<Customer> create({required String name, String? phone, String? notes});

  Future<Customer> update({
    required String id,
    required int expectedVersion,
    required String name,
    String? phone,
    String? notes,
  });

  Future<Customer> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  });
}
