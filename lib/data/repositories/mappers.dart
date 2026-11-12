import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_group.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sync_state.dart';
import '../local/app_database.dart';

extension DebtGroupRowMapper on DebtGroupRow {
  DebtGroup toDomain() {
    return DebtGroup(
      id: id,
      name: name,
      description: description,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
      isArchived: isArchived,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      version: version,
      syncState: SyncState.fromDatabase(syncState),
    );
  }
}

extension DebtRowMapper on DebtRow {
  Debt toDomain() {
    return Debt(
      id: id,
      groupId: groupId,
      title: title,
      principalAmount: principalAmount,
      dueDate: dueDate?.toUtc(),
      notes: notes,
      isArchived: isArchived,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      version: version,
      syncState: SyncState.fromDatabase(syncState),
    );
  }
}

extension PaymentRowMapper on PaymentRow {
  Payment toDomain() {
    return Payment(
      id: id,
      debtId: debtId,
      amount: amount,
      paidAt: paidAt.toUtc(),
      notes: notes,
      operationId: operationId,
      createdAt: createdAt.toUtc(),
      syncState: SyncState.fromDatabase(syncState),
    );
  }
}
