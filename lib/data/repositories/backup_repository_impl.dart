import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/backup_document.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_group.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sync_state.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
import '../local/daos/payment_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import 'outbox_payloads.dart';

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl(
    AppDatabase database, {
    DebtGroupDao? groupDao,
    DebtDao? debtDao,
    PaymentDao? paymentDao,
    SyncQueueDao? syncQueueDao,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _db = database,
       _groups = groupDao ?? DebtGroupDao(database),
       _debts = debtDao ?? DebtDao(database),
       _payments = paymentDao ?? PaymentDao(database),
       _queue = syncQueueDao ?? SyncQueueDao(database),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final DebtGroupDao _groups;
  final DebtDao _debts;
  final PaymentDao _payments;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<BackupDocument> exportBackup() async {
    final groupRows = await _groups.listAll();
    final debtRows = await _debts.listAll();
    final paymentRows = await _payments.listAll();

    groupRows.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.name.compareTo(b.name);
    });

    return BackupDocument(
      exportedAt: _now().toUtc(),
      groups: groupRows
          .map(
            (row) => BackupDebtGroup(
              id: row.id,
              name: row.name,
              description: row.description,
              color: row.color,
              icon: row.icon,
              sortOrder: row.sortOrder,
              isArchived: row.isArchived,
              createdAt: row.createdAt.toUtc(),
              updatedAt: row.updatedAt.toUtc(),
            ),
          )
          .toList(growable: false),
      debts: debtRows
          .map(
            (row) => BackupDebt(
              id: row.id,
              groupId: row.groupId,
              title: row.title,
              principalAmount: row.principalAmount,
              dueDate: row.dueDate?.toUtc(),
              notes: row.notes,
              isArchived: row.isArchived,
              createdAt: row.createdAt.toUtc(),
              updatedAt: row.updatedAt.toUtc(),
            ),
          )
          .toList(growable: false),
      payments: paymentRows
          .map(
            (row) => BackupPayment(
              id: row.id,
              debtId: row.debtId,
              amount: row.amount,
              paidAt: row.paidAt.toUtc(),
              notes: row.notes,
              createdAt: row.createdAt.toUtc(),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<BackupRestorePreview> previewRestore(BackupDocument document) async {
    final groups = await _groups.listAll();
    final debts = await _debts.listAll();
    final payments = await _payments.listAll();

    return _buildPreview(
      document,
      existingGroupIds: groups.map((row) => row.id).toSet(),
      existingDebtIds: debts.map((row) => row.id).toSet(),
      existingPaymentIds: payments.map((row) => row.id).toSet(),
    );
  }

  @override
  Future<BackupRestoreResult> restore(BackupDocument document) {
    return _db.transaction(() async {
      final groups = await _groups.listAll();
      final debts = await _debts.listAll();
      final payments = await _payments.listAll();

      final existingGroupIds = groups.map((row) => row.id).toSet();
      final existingDebtIds = debts.map((row) => row.id).toSet();
      final existingPaymentIds = payments.map((row) => row.id).toSet();

      final preview = _buildPreview(
        document,
        existingGroupIds: existingGroupIds,
        existingDebtIds: existingDebtIds,
        existingPaymentIds: existingPaymentIds,
      );

      final now = _now().toUtc();

      for (final group in document.groups) {
        if (existingGroupIds.contains(group.id)) {
          continue;
        }

        await _groups.upsert(
          DebtGroupRow(
            id: group.id,
            name: group.name,
            description: group.description,
            color: group.color,
            icon: group.icon,
            sortOrder: group.sortOrder,
            isArchived: group.isArchived,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt,
            version: 1,
            syncState: SyncState.pending.name,
            serverUpdatedAt: null,
          ),
        );
        await _queue.enqueue(
          operationId: _uuid.v4(),
          entityType: 'debt_group',
          entityId: group.id,
          operation: 'create',
          payload: debtGroupCreatePayload(_groupDomain(group)),
          createdAt: now,
        );
      }

      for (final debt in document.debts) {
        if (existingDebtIds.contains(debt.id)) {
          continue;
        }

        await _debts.upsert(
          DebtRow(
            id: debt.id,
            groupId: debt.groupId,
            title: debt.title,
            principalAmount: debt.principalAmount,
            dueDate: debt.dueDate,
            notes: debt.notes,
            isArchived: debt.isArchived,
            createdAt: debt.createdAt,
            updatedAt: debt.updatedAt,
            version: 1,
            syncState: SyncState.pending.name,
            serverUpdatedAt: null,
          ),
        );
        await _queue.enqueue(
          operationId: _uuid.v4(),
          entityType: 'debt',
          entityId: debt.id,
          operation: 'create',
          payload: debtCreatePayload(_debtDomain(debt)),
          createdAt: now,
        );
      }

      for (final payment in document.payments) {
        if (existingPaymentIds.contains(payment.id)) {
          continue;
        }

        await _payments.insert(
          PaymentRow(
            id: payment.id,
            debtId: payment.debtId,
            amount: payment.amount,
            paidAt: payment.paidAt,
            notes: payment.notes,
            operationId: payment.id,
            createdAt: payment.createdAt,
            syncState: SyncState.pending.name,
            serverUpdatedAt: null,
          ),
        );
        await _queue.enqueue(
          operationId: _uuid.v4(),
          entityType: 'payment',
          entityId: payment.id,
          operation: 'payment_create',
          payload: paymentCreatePayload(_paymentDomain(payment)),
          createdAt: now,
        );
      }

      return preview;
    });
  }

  BackupRestorePreview _buildPreview(
    BackupDocument document, {
    required Set<String> existingGroupIds,
    required Set<String> existingDebtIds,
    required Set<String> existingPaymentIds,
  }) {
    _validateReferences(document, existingGroupIds, existingDebtIds);

    var newGroups = 0;
    var existingGroups = 0;
    for (final group in document.groups) {
      if (existingGroupIds.contains(group.id)) {
        existingGroups++;
      } else {
        newGroups++;
      }
    }

    var newDebts = 0;
    var existingDebts = 0;
    for (final debt in document.debts) {
      if (existingDebtIds.contains(debt.id)) {
        existingDebts++;
      } else {
        newDebts++;
      }
    }

    var newPayments = 0;
    var existingPayments = 0;
    for (final payment in document.payments) {
      if (existingPaymentIds.contains(payment.id)) {
        existingPayments++;
      } else {
        newPayments++;
      }
    }

    return BackupRestorePreview(
      newGroups: newGroups,
      existingGroups: existingGroups,
      newDebts: newDebts,
      existingDebts: existingDebts,
      newPayments: newPayments,
      existingPayments: existingPayments,
    );
  }

  void _validateReferences(
    BackupDocument document,
    Set<String> existingGroupIds,
    Set<String> existingDebtIds,
  ) {
    final availableGroupIds = <String>{
      ...existingGroupIds,
      ...document.groups.map((group) => group.id),
    };
    final availableDebtIds = <String>{
      ...existingDebtIds,
      ...document.debts.map((debt) => debt.id),
    };

    for (final debt in document.debts) {
      final groupId = debt.groupId;
      if (groupId != null && !availableGroupIds.contains(groupId)) {
        throw _referenceError(
          'hutang "${debt.title}" merujuk group yang tidak ada.',
        );
      }
    }

    for (final payment in document.payments) {
      if (!availableDebtIds.contains(payment.debtId)) {
        throw _referenceError(
          'pembayaran ${payment.id} merujuk hutang yang tidak ada.',
        );
      }
    }
  }

  AppException _referenceError(String detail) {
    return AppException(
      code: AppErrorCode.validation,
      message: 'Backup tidak dapat dipulihkan: $detail',
    );
  }

  DebtGroup _groupDomain(BackupDebtGroup group) {
    return DebtGroup(
      id: group.id,
      name: group.name,
      description: group.description,
      color: group.color,
      icon: group.icon,
      sortOrder: group.sortOrder,
      isArchived: group.isArchived,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      version: 1,
      syncState: SyncState.pending,
    );
  }

  Debt _debtDomain(BackupDebt debt) {
    return Debt(
      id: debt.id,
      groupId: debt.groupId,
      title: debt.title,
      principalAmount: debt.principalAmount,
      dueDate: debt.dueDate,
      notes: debt.notes,
      isArchived: debt.isArchived,
      createdAt: debt.createdAt,
      updatedAt: debt.updatedAt,
      version: 1,
      syncState: SyncState.pending,
    );
  }

  Payment _paymentDomain(BackupPayment payment) {
    return Payment(
      id: payment.id,
      debtId: payment.debtId,
      amount: payment.amount,
      paidAt: payment.paidAt,
      notes: payment.notes,
      operationId: payment.id,
      createdAt: payment.createdAt,
      syncState: SyncState.pending,
    );
  }
}
