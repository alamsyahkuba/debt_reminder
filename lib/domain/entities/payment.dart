import 'sync_state.dart';

final class Payment {
  const Payment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
    required this.notes,
    required this.operationId,
    required this.createdAt,
    required this.syncState,
  });

  final String id;
  final String debtId;
  final int amount;
  final DateTime paidAt;
  final String? notes;
  final String operationId;
  final DateTime createdAt;
  final SyncState syncState;
}
