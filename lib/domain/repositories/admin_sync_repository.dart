import '../entities/admin_mutation_result.dart';

abstract interface class AdminSyncRepository {
  Future<AdminMutationResult> applyMutation({
    required String token,
    required String operationId,
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  });
}
