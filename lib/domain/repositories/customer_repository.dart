import '../entities/customer.dart';
import '../entities/customer_summary.dart';

abstract interface class CustomerRepository {
  Stream<List<Customer>> watchAll({bool includeArchived = false});

  Stream<Customer?> watchById(String id);

  Stream<CustomerSummary> watchSummary(String id);

  Stream<Map<String, CustomerSummary>> watchSummaries();

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
