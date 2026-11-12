import 'package:uuid/uuid.dart';

import '../../domain/entities/debt_group.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/debt_group_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import 'mappers.dart';
import 'outbox_payloads.dart';
import 'repository_support.dart';

class DebtGroupRepositoryImpl implements DebtGroupRepository {
  DebtGroupRepositoryImpl(
    AppDatabase db, {
    SyncQueueDao? syncQueueDao,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _db = db,
       _groups = DebtGroupDao(db),
       _debts = DebtDao(db),
       _queue = syncQueueDao ?? SyncQueueDao(db),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final DebtGroupDao _groups;
  final DebtDao _debts;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Stream<List<DebtGroup>> watchAll({bool includeArchived = false}) {
    return _groups
        .watchAll(includeArchived: includeArchived)
        .map(
          (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<DebtGroup?> watchById(String id) {
    return _groups.watchById(id).map((row) => row?.toDomain());
  }

  @override
  Stream<GroupSummary> watchSummary(String id) {
    return _groups.watchSummary(id);
  }

  @override
  Stream<Map<String, GroupSummary>> watchSummaries() {
    return _groups.watchSummaries();
  }

  @override
  Future<DebtGroup?> findById(String id) async {
    final row = await _groups.findById(id);
    return row?.toDomain();
  }

  @override
  Future<DebtGroup> create({
    required String name,
    String? description,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) async {
    final normalizedName = validateText(
      name,
      field: 'Nama group',
      maxLength: 100,
    );
    final normalizedDescription = validateOptionalText(
      description,
      field: 'Deskripsi group',
      maxLength: 1000,
    );
    final normalizedColor = validateHexColor(color);
    final normalizedIcon = validateDebtGroupIcon(icon);
    final normalizedSortOrder = validateSortOrder(sortOrder);
    final now = _now().toUtc();
    final row = DebtGroupRow(
      id: _uuid.v4(),
      name: normalizedName,
      description: normalizedDescription,
      color: normalizedColor,
      icon: normalizedIcon,
      sortOrder: normalizedSortOrder,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      version: 1,
      syncState: 'pending',
      serverUpdatedAt: null,
    );

    return _db.transaction(() async {
      await _groups.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt_group',
        entityId: row.id,
        operation: 'create',
        payload: debtGroupCreatePayload(row.toDomain()),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<DebtGroup> update({
    required String id,
    required int expectedVersion,
    required String name,
    String? description,
    String? color,
    String? icon,
    required int sortOrder,
  }) async {
    final normalizedName = validateText(
      name,
      field: 'Nama group',
      maxLength: 100,
    );
    final normalizedDescription = validateOptionalText(
      description,
      field: 'Deskripsi group',
      maxLength: 1000,
    );
    final normalizedColor = validateHexColor(color);
    final normalizedIcon = validateDebtGroupIcon(icon);
    final normalizedSortOrder = validateSortOrder(sortOrder);

    return _db.transaction(() async {
      final existing = await _groups.findById(id) ?? throwNotFound('Group');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Group',
      );

      final now = _now().toUtc();
      final row = DebtGroupRow(
        id: existing.id,
        name: normalizedName,
        description: normalizedDescription,
        color: normalizedColor,
        icon: normalizedIcon,
        sortOrder: normalizedSortOrder,
        isArchived: existing.isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _groups.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt_group',
        entityId: row.id,
        operation: 'update',
        payload: debtGroupUpdatePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<DebtGroup> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  }) async {
    return _db.transaction(() async {
      final existing = await _groups.findById(id) ?? throwNotFound('Group');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Group',
      );

      if (existing.isArchived == isArchived) {
        return existing.toDomain();
      }

      final now = _now().toUtc();
      final row = DebtGroupRow(
        id: existing.id,
        name: existing.name,
        description: existing.description,
        color: existing.color,
        icon: existing.icon,
        sortOrder: existing.sortOrder,
        isArchived: isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _groups.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt_group',
        entityId: row.id,
        operation: 'archive',
        payload: debtGroupArchivePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<int> delete({required String id, required int expectedVersion}) {
    return _db.transaction(() async {
      final existing = await _groups.findById(id) ?? throwNotFound('Group');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Group',
      );

      final debts = await _debts.listByGroup(id);
      var timestamp = _now().toUtc();

      for (final debt in debts) {
        final updated = DebtRow(
          id: debt.id,
          customerId: debt.customerId,
          groupId: null,
          title: debt.title,
          principalAmount: debt.principalAmount,
          dueDate: debt.dueDate,
          notes: debt.notes,
          isArchived: debt.isArchived,
          createdAt: debt.createdAt,
          updatedAt: timestamp,
          version: debt.version + 1,
          syncState: 'pending',
          serverUpdatedAt: debt.serverUpdatedAt,
        );

        await _debts.upsert(updated);
        await _queue.enqueue(
          operationId: _uuid.v4(),
          entityType: 'debt',
          entityId: updated.id,
          operation: 'update',
          payload: debtUpdatePayload(updated.toDomain(), debt.version),
          createdAt: timestamp,
        );
        timestamp = timestamp.add(const Duration(microseconds: 1));
      }

      await _groups.deleteById(id);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'debt_group',
        entityId: id,
        operation: 'delete',
        payload: debtGroupDeletePayload(existing.toDomain(), expectedVersion),
        createdAt: timestamp,
      );

      return debts.length;
    });
  }
}
