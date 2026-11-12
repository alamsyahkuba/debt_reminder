import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/customer_dao.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
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
       _customers = CustomerDao(db),
       _groups = DebtGroupDao(db),
       _queue = syncQueueDao ?? SyncQueueDao(db),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final DebtDao _debts;
  final CustomerDao _customers;
  final DebtGroupDao _groups;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

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
  Stream<List<Debt>> watchByCustomer(
    String customerId, {
    bool includeArchived = false,
  }) {
    return _debts
        .watchByCustomer(customerId, includeArchived: includeArchived)
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
    required String customerId,
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
      await _ensureRelationsExist(customerId, groupId);
      final now = _now().toUtc();
      final row = DebtRow(
        id: _uuid.v4(),
        customerId: customerId,
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
  Future<Debt> update({
    required String id,
    required int expectedVersion,
    required String customerId,
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
      await _ensureRelationsExist(customerId, groupId);

      final now = _now().toUtc();
      final row = DebtRow(
        id: existing.id,
        customerId: customerId,
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
        customerId: existing.customerId,
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
        customerId: existing.customerId,
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

  Future<void> _ensureRelationsExist(String customerId, String? groupId) async {
    final customer = await _customers.findById(customerId);
    if (customer == null) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Pelanggan tidak ditemukan.',
      );
    }

    await _ensureGroupExists(groupId);
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
