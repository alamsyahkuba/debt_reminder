import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_group.dart';
import '../../domain/entities/payment.dart';
import 'repository_support.dart';

Map<String, Object?> debtGroupCreatePayload(DebtGroup group) {
  return <String, Object?>{
    'id': group.id,
    'name': group.name,
    'description': group.description,
    'color': group.color,
    'icon': group.icon,
    'sort_order': group.sortOrder,
    'is_archived': group.isArchived,
    'created_at': timestampString(group.createdAt),
    'updated_at': timestampString(group.updatedAt),
    'version': group.version,
  };
}

Map<String, Object?> debtGroupUpdatePayload(
  DebtGroup group,
  int expectedVersion,
) {
  return <String, Object?>{
    'id': group.id,
    'expected_version': expectedVersion,
    'name': group.name,
    'description': group.description,
    'color': group.color,
    'icon': group.icon,
    'sort_order': group.sortOrder,
    'is_archived': group.isArchived,
    'updated_at': timestampString(group.updatedAt),
  };
}

Map<String, Object?> debtGroupArchivePayload(
  DebtGroup group,
  int expectedVersion,
) {
  return <String, Object?>{
    'id': group.id,
    'expected_version': expectedVersion,
    'is_archived': group.isArchived,
  };
}

Map<String, Object?> debtGroupDeletePayload(
  DebtGroup group,
  int expectedVersion,
) {
  return <String, Object?>{
    'id': group.id,
    'expected_version': expectedVersion,
    'move_debts_to_unassigned': true,
  };
}

Map<String, Object?> debtCreatePayload(Debt debt) {
  return <String, Object?>{
    'id': debt.id,
    'group_id': debt.groupId,
    'title': debt.title,
    'principal_amount': debt.principalAmount,
    'due_date': debt.dueDate == null ? null : dateOnlyString(debt.dueDate!),
    'notes': debt.notes,
    'is_archived': debt.isArchived,
    'created_at': timestampString(debt.createdAt),
    'updated_at': timestampString(debt.updatedAt),
    'version': debt.version,
  };
}

Map<String, Object?> debtUpdatePayload(Debt debt, int expectedVersion) {
  return <String, Object?>{
    'id': debt.id,
    'expected_version': expectedVersion,
    'group_id': debt.groupId,
    'title': debt.title,
    'principal_amount': debt.principalAmount,
    'due_date': debt.dueDate == null ? null : dateOnlyString(debt.dueDate!),
    'notes': debt.notes,
    'is_archived': debt.isArchived,
    'updated_at': timestampString(debt.updatedAt),
  };
}

Map<String, Object?> debtArchivePayload(Debt debt, int expectedVersion) {
  return <String, Object?>{
    'id': debt.id,
    'expected_version': expectedVersion,
    'is_archived': debt.isArchived,
  };
}

Map<String, Object?> debtDeletePayload(Debt debt, int expectedVersion) {
  return <String, Object?>{'id': debt.id, 'expected_version': expectedVersion};
}

Map<String, Object?> paymentCreatePayload(Payment payment) {
  return <String, Object?>{
    'id': payment.id,
    'debt_id': payment.debtId,
    'amount': payment.amount,
    'paid_at': timestampString(payment.paidAt),
    'notes': payment.notes,
    'operation_id': payment.operationId,
    'created_at': timestampString(payment.createdAt),
  };
}
