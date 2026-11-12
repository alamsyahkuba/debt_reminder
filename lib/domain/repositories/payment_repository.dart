import '../entities/payment.dart';

/// Payments are append-only. This interface intentionally exposes no update or
/// delete operation.
abstract interface class PaymentRepository {
  Stream<List<Payment>> watchByDebt(String debtId);

  Future<List<Payment>> listByDebt(String debtId);

  Future<int> totalPaidForDebt(String debtId);

  Future<Payment> create({
    required String debtId,
    required int amount,
    DateTime? paidAt,
    String? notes,
  });
}
