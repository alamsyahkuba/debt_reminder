import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_draft.dart';
import '../../domain/entities/debt_overview.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
import '../local/daos/payment_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import 'mappers.dart';
import 'outbox_payloads.dart';
import 'repository_support.dart';

class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(
    AppDatabase db, {
    SyncQueueDao? syncQueueDao,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _db = db,
       _debts = DebtDao(db),
       _groups = DebtGroupDao(db),
       _payments = PaymentDao(db),
       _queue = syncQueueDao ?? SyncQueueDao(db),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final DebtDao _debts;
  final DebtGroupDao _groups;
  final PaymentDao _payments;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Stream<List<DebtOverview>> watchOverviews({bool includeArchived = false}) {
    return _debts
        .watchOverviews(includeArchived: includeArchived)
        .map(
          (rows) => rows
              .map(
                (row) => DebtOverview.fromDebt(
                  row.debt.toDomain(),
                  paidAmount: row.paidAmount,
                  today: _now(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<DebtOverview?> watchOverviewById(String id) {
    return _debts
        .watchOverviewById(id)
        .map(
          (row) => row == null
              ? null
              : DebtOverview.fromDebt(
                  row.debt.toDomain(),
                  paidAmount: row.paidAmount,
                  today: _now(),
                ),
        );
  }

  @override
  Stream<List<Debt>> watchAll({bool includeArchived = false}) {
    return _debts
        .watchAll(includeArchived: includeArchived)
        .map(
          (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<List<Debt>> watchByGroup(
    String? groupId, {
    bool includeArchived = false,
  }) {
    return _debts
        .watchByGroup(groupId, includeArchived: includeArchived)
        .map(
          (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }

  @override
  Future<Debt?> findById(String id) async {
    final row = await _debts.findById(id);
    return row?.toDomain();
  }

  @override
  Future<Debt> create({
    String? groupId,
    required String title,
    required int principalAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    final normalizedTitle = validateText(
      title,
      field: 'Judul hutang',
      maxLength: 200,
    );
    final normalizedPrincipal = validatePositiveRupiah(
      principalAmount,
      field: 'Pokok hutang',
    );
    final normalizedNotes = validateOptionalText(
      notes,
      field: 'Catatan hutang',
    );
    final normalizedDueDate = normalizeDueDate(dueDate);

    return _db.transaction(() async {
      await _ensureGroupExists(groupId);
      final now = _now().toUtc();
      final row = DebtRow(
        id: _uuid.v4(),
        groupId: groupId,
        title: normalizedTitle,
        principalAmount: normalizedPrincipal,
        dueDate: normalizedDueDate,
        notes: normalizedNotes,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        version: 1,
        syncState: 'pending',
        serverUpdatedAt: null,
      );

      await _debts.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt',
        entityId: row.id,
        operation: 'create',
        payload: debtCreatePayload(row.toDomain()),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<List<Debt>> createMany({
    String? groupId,
    required List<DebtDraft> drafts,
  }) async {
    if (drafts.isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Minimal satu hutang harus diisi.',
      );
    }
    if (drafts.length > maxDebtBatchSize) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Maksimal $maxDebtBatchSize hutang per batch.',
      );
    }

    final normalized = <_NormalizedDebtDraft>[];
    for (var index = 0; index < drafts.length; index++) {
      final draft = drafts[index];
      final rowNumber = index + 1;
      normalized.add(
        _NormalizedDebtDraft(
          title: validateText(
            draft.title,
            field: 'Judul hutang baris $rowNumber',
            maxLength: 200,
          ),
          principalAmount: validatePositiveRupiah(
            draft.principalAmount,
            field: 'Pokok hutang baris $rowNumber',
          ),
          dueDate: normalizeDueDate(draft.dueDate),
          notes: validateOptionalText(
            draft.notes,
            field: 'Catatan hutang baris $rowNumber',
            maxLength: 2000,
          ),
        ),
      );
    }

    return _db.transaction(() async {
      await _ensureGroupExists(groupId);
      final now = _now().toUtc();
      final rows = <DebtRow>[
        for (final draft in normalized)
          DebtRow(
            id: _uuid.v4(),
            groupId: groupId,
            title: draft.title,
            principalAmount: draft.principalAmount,
            dueDate: draft.dueDate,
            notes: draft.notes,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
            version: 1,
            syncState: 'pending',
            serverUpdatedAt: null,
          ),
      ];

      for (final row in rows) {
        await _debts.upsert(row);
      }

      final batchId = _uuid.v4();
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt_batch',
        entityId: batchId,
        operation: 'create',
        payload: debtBatchCreatePayload(
          batchId,
          rows.map((row) => row.toDomain()).toList(growable: false),
        ),
        createdAt: now,
      );

      return rows.map((row) => row.toDomain()).toList(growable: false);
    });
  }

  @override
  Future<Debt> update({
    required String id,
    required int expectedVersion,
    String? groupId,
    required String title,
    required int principalAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    final normalizedTitle = validateText(
      title,
      field: 'Judul hutang',
      maxLength: 200,
    );
    final normalizedPrincipal = validatePositiveRupiah(
      principalAmount,
      field: 'Pokok hutang',
    );
    final normalizedNotes = validateOptionalText(
      notes,
      field: 'Catatan hutang',
    );
    final normalizedDueDate = normalizeDueDate(dueDate);

    return _db.transaction(() async {
      final existing = await _debts.findById(id) ?? throwNotFound('Hutang');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Hutang',
      );
      await _ensureGroupExists(groupId);

      final now = _now().toUtc();
      final row = DebtRow(
        id: existing.id,
        groupId: groupId,
        title: normalizedTitle,
        principalAmount: normalizedPrincipal,
        dueDate: normalizedDueDate,
        notes: normalizedNotes,
        isArchived: existing.isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _debts.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt',
        entityId: row.id,
        operation: 'update',
        payload: debtUpdatePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<Debt> moveToGroup({
    required String id,
    required int expectedVersion,
    String? groupId,
  }) async {
    return _db.transaction(() async {
      final existing = await _debts.findById(id) ?? throwNotFound('Hutang');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Hutang',
      );

      if (existing.groupId == groupId) {
        return existing.toDomain();
      }

      await _ensureGroupExists(groupId);
      final now = _now().toUtc();
      final row = DebtRow(
        id: existing.id,
        groupId: groupId,
        title: existing.title,
        principalAmount: existing.principalAmount,
        dueDate: existing.dueDate,
        notes: existing.notes,
        isArchived: existing.isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _debts.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt',
        entityId: row.id,
        operation: 'update',
        payload: debtUpdatePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<Debt> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  }) async {
    return _db.transaction(() async {
      final existing = await _debts.findById(id) ?? throwNotFound('Hutang');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Hutang',
      );

      if (existing.isArchived == isArchived) {
        return existing.toDomain();
      }

      final now = _now().toUtc();
      final row = DebtRow(
        id: existing.id,
        groupId: existing.groupId,
        title: existing.title,
        principalAmount: existing.principalAmount,
        dueDate: existing.dueDate,
        notes: existing.notes,
        isArchived: isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _debts.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt',
        entityId: row.id,
        operation: 'archive',
        payload: debtArchivePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<void> delete({
    required String id,
    required int expectedVersion,
  }) async {
    await _db.transaction(() async {
      final existing = await _debts.findById(id) ?? throwNotFound('Hutang');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Hutang',
      );

      final payments = await _payments.listByDebt(id);
      if (payments.isNotEmpty) {
        throw const AppException(
          code: AppErrorCode.validation,
          message:
              'Hutang yang sudah memiliki pembayaran tidak dapat dihapus. '
              'Arsipkan hutang ini agar histori pembayaran tetap tersimpan.',
        );
      }

      final now = _now().toUtc();
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt',
        entityId: existing.id,
        operation: 'delete',
        payload: debtDeletePayload(existing.toDomain(), expectedVersion),
        createdAt: now,
      );
      await _debts.deleteById(id);
    });
  }

  Future<void> _ensureGroupExists(String? groupId) async {
    if (groupId == null) {
      return;
    }

    final group = await _groups.findById(groupId);
    if (group == null) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Group tidak ditemukan.',
      );
    }
  }
}

final class _NormalizedDebtDraft {
  const _NormalizedDebtDraft({
    required this.title,
    required this.principalAmount,
    required this.dueDate,
    required this.notes,
  });

  final String title;
  final int principalAmount;
  final DateTime? dueDate;
  final String? notes;
}
