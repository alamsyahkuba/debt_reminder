import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/payment_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import 'mappers.dart';
import 'outbox_payloads.dart';
import 'repository_support.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(
    AppDatabase db, {
    SyncQueueDao? syncQueueDao,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _db = db,
       _debts = DebtDao(db),
       _payments = PaymentDao(db),
       _queue = syncQueueDao ?? SyncQueueDao(db),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final DebtDao _debts;
  final PaymentDao _payments;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Stream<List<Payment>> watchByDebt(String debtId) {
    return _payments
        .watchByDebt(debtId)
        .map(
          (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }

  @override
  Future<List<Payment>> listByDebt(String debtId) async {
    final rows = await _payments.listByDebt(debtId);
    return rows.map((row) => row.toDomain()).toList(growable: false);
  }

  @override
  Future<int> totalPaidForDebt(String debtId) {
    return _payments.totalPaidForDebt(debtId);
  }

  @override
  Future<Payment> create({
    required String debtId,
    required int amount,
    DateTime? paidAt,
    String? notes,
  }) async {
    final normalizedAmount = validatePositiveRupiah(
      amount,
      field: 'Nominal pembayaran',
    );
    final normalizedNotes = validateOptionalText(
      notes,
      field: 'Catatan pembayaran',
    );

    return _db.transaction(() async {
      final debt = await _debts.findById(debtId) ?? throwNotFound('Hutang');
      if (debt.isArchived) {
        throw const AppException(
          code: AppErrorCode.validation,
          message:
              'Pembayaran tidak dapat ditambahkan ke hutang yang diarsipkan.',
        );
      }

      final paidAmount = await _payments.totalPaidForDebt(debtId);
      if (paidAmount + normalizedAmount > debt.principalAmount) {
        throw const AppException(
          code: AppErrorCode.validation,
          message: 'Pembayaran melebihi sisa hutang.',
        );
      }

      final now = _now().toUtc();
      final operationId = _uuid.v4();
      final row = PaymentRow(
        id: _uuid.v4(),
        debtId: debtId,
        amount: normalizedAmount,
        paidAt: normalizeTimestamp(paidAt ?? now),
        notes: normalizedNotes,
        operationId: operationId,
        createdAt: now,
        syncState: 'pending',
        serverUpdatedAt: null,
      );

      await _payments.insert(row);
      await _queue.enqueue(
        operationId: operationId,
        entityType: 'payment',
        entityId: row.id,
        operation: 'payment_create',
        payload: paymentCreatePayload(row.toDomain()),
        createdAt: now,
      );
      return row.toDomain();
    });
  }
}
