import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/errors/admin_sync_exception.dart';
import '../../domain/entities/admin_mutation_result.dart';
import '../../domain/entities/sync_state.dart';
import '../../domain/repositories/admin_sync_repository.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
import '../local/daos/payment_dao.dart';
import '../local/daos/sync_queue_dao.dart';

class AdminSyncOutcome {
  const AdminSyncOutcome({
    this.applied = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.retryScheduled = 0,
    this.authRequired = false,
  });

  final int applied;
  final int conflicts;
  final int failed;
  final int retryScheduled;
  final bool authRequired;
}

class SyncRetryPolicy {
  const SyncRetryPolicy({
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 5),
    this.jitterSeconds = 3,
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final int jitterSeconds;

  Duration nextDelay(int retryCount, String operationId) {
    final exponent = retryCount.clamp(0, 6);
    final exponential = baseDelay.inSeconds * (1 << exponent);
    final jitter = jitterSeconds == 0
        ? 0
        : operationId.hashCode.abs() % (jitterSeconds + 1);
    final capped = exponential + jitter;
    return Duration(
      seconds: capped > maxDelay.inSeconds ? maxDelay.inSeconds : capped,
    );
  }
}

class AdminSyncService {
  AdminSyncService({
    required AppDatabase database,
    required this.repository,
    DateTime Function()? now,
    Uuid? uuid,
    this.retryPolicy = const SyncRetryPolicy(),
  }) : _db = database,
       _queue = SyncQueueDao(database),
       _groups = DebtGroupDao(database),
       _debts = DebtDao(database),
       _payments = PaymentDao(database),
       _now = now ?? (() => DateTime.now().toUtc()),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AdminSyncRepository repository;
  final SyncQueueDao _queue;
  final DebtGroupDao _groups;
  final DebtDao _debts;
  final PaymentDao _payments;
  final DateTime Function() _now;
  final Uuid _uuid;
  final SyncRetryPolicy retryPolicy;

  Future<AdminSyncOutcome> sync({
    required String token,
    int maxOperations = 50,
  }) async {
    await _queue.recoverInterrupted();
    final now = _now().toUtc();
    final ready = await _queue.listReady(now, limit: maxOperations);
    ready.sort(_compareDependencyOrder);

    var applied = 0;
    var conflicts = 0;
    var failed = 0;
    var retryScheduled = 0;
    var attempted = 0;

    for (final item in ready) {
      if (attempted >= maxOperations) {
        break;
      }

      Map<String, Object?> payload;
      try {
        payload = _decodeObject(item.payload);
      } catch (_) {
        await _queue.markFailed(
          operationId: item.operationId,
          errorCode: 'invalid_payload',
        );
        failed++;
        continue;
      }

      if (!await _dependenciesReady(item, payload)) {
        continue;
      }

      await _queue.markProcessing(item.operationId);
      attempted++;

      try {
        final result = await repository.applyMutation(
          token: token,
          operationId: item.operationId,
          operation: item.operation,
          entityType: item.entityType,
          entityId: item.entityId,
          payload: payload,
        );

        switch (result.status) {
          case AdminMutationStatus.applied:
            await _applySuccess(item, result, payload);
            await _queue.deleteOperation(item.operationId);
            applied++;

          case AdminMutationStatus.conflict:
            await _markEntityConflict(item, payload);
            await _queue.markConflict(
              operationId: item.operationId,
              conflictData: jsonEncode(<String, Object?>{
                ...result.toConflictData(),
                'entity_type': item.entityType,
                'entity_id': item.entityId,
              }),
            );
            conflicts++;

          case AdminMutationStatus.notFound:
            if (item.operation == 'delete' &&
                (item.entityType == 'debt_group' ||
                    item.entityType == 'debt')) {
              await _queue.deleteOperation(item.operationId);
              applied++;
            } else {
              await _queue.markFailed(
                operationId: item.operationId,
                errorCode: 'not_found',
              );
              failed++;
            }
        }
      } on AdminSyncException catch (error) {
        if (error.isAuthError) {
          await _queue.markAwaitingAuth(
            operationId: item.operationId,
            errorCode: error.code,
          );
          return AdminSyncOutcome(
            applied: applied,
            conflicts: conflicts,
            failed: failed,
            retryScheduled: retryScheduled,
            authRequired: true,
          );
        }

        if (error.isRetryable) {
          final retryCount = item.retryCount + 1;
          await _queue.markRetry(
            operationId: item.operationId,
            retryCount: retryCount,
            nextRetryAt: _now().toUtc().add(
              retryPolicy.nextDelay(retryCount, item.operationId),
            ),
            errorCode: error.code,
          );
          retryScheduled++;
          break;
        }

        await _queue.markFailed(
          operationId: item.operationId,
          errorCode: error.code,
        );
        failed++;
      } catch (_) {
        await _queue.markFailed(
          operationId: item.operationId,
          errorCode: 'sync_failed',
        );
        failed++;
      }
    }

    return AdminSyncOutcome(
      applied: applied,
      conflicts: conflicts,
      failed: failed,
      retryScheduled: retryScheduled,
    );
  }

  Future<List<SyncQueueRow>> listConflicts() {
    return _db
        .select(_db.syncQueue)
        .get()
        .then(
          (rows) => rows
              .where((row) => row.status == 'conflict')
              .toList(growable: false),
        );
  }

  Future<void> resolveConflictKeepLocal(String operationId) async {
    final item = await _queue.findByOperationId(operationId);
    if (item == null || item.status != 'conflict') {
      throw const AdminSyncException(
        code: 'conflict_not_found',
        message: 'Konflik tidak ditemukan.',
      );
    }
    if (item.entityType == 'debt_batch') {
      throw const AdminSyncException(
        code: 'invalid_conflict',
        message: 'Konflik batch tidak dapat diselesaikan otomatis.',
      );
    }

    final conflict = _decodeConflict(item.conflictData);
    final serverVersion = _asInt(conflict['server_version']);
    final serverUpdatedAt = _asDateTime(conflict['server_updated_at']);
    if (serverVersion == null || serverUpdatedAt == null) {
      throw const AdminSyncException(
        code: 'invalid_conflict',
        message: 'Data konflik tidak lengkap.',
      );
    }

    final payload = _decodeObject(item.payload);
    payload['expected_version'] = serverVersion;

    if (item.entityType == 'debt_group' && item.operation != 'delete') {
      await _groups.prepareConflictRetry(
        id: item.entityId,
        serverVersion: serverVersion,
        serverUpdatedAt: serverUpdatedAt,
      );
    } else if (item.entityType == 'debt') {
      await _debts.prepareConflictRetry(
        id: item.entityId,
        serverVersion: serverVersion,
        serverUpdatedAt: serverUpdatedAt,
      );
    }

    final now = _now().toUtc();
    await _queue.enqueue(
      operationId: _uuid.v4(),
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      payload: payload,
      createdAt: now,
    );
    await _queue.deleteOperation(operationId);
  }

  Future<void> resolveConflictReload(String operationId) async {
    final item = await _queue.findByOperationId(operationId);
    if (item == null || item.status != 'conflict') {
      throw const AdminSyncException(
        code: 'conflict_not_found',
        message: 'Konflik tidak ditemukan.',
      );
    }
    if (item.entityType == 'debt_batch') {
      throw const AdminSyncException(
        code: 'invalid_conflict',
        message: 'Konflik batch tidak dapat diselesaikan otomatis.',
      );
    }

    final conflict = _decodeConflict(item.conflictData);
    final serverRow = conflict['server_row'];
    final serverUpdatedAt = _asDateTime(conflict['server_updated_at']);
    if (serverRow is! Map || serverUpdatedAt == null) {
      throw const AdminSyncException(
        code: 'invalid_conflict',
        message: 'Snapshot server tidak tersedia.',
      );
    }

    final row = _stringKeyed(serverRow);
    if (item.entityType == 'debt_group') {
      await _groups.upsert(
        DebtGroupRow(
          id: _asString(row['id']) ?? item.entityId,
          name: _asString(row['name']) ?? 'Group',
          description: _asString(row['description']),
          color: _asString(row['color']),
          icon: _asString(row['icon']),
          sortOrder: _asInt(row['sort_order']) ?? 0,
          isArchived: row['is_archived'] == true,
          createdAt: _asDateTime(row['created_at']) ?? serverUpdatedAt,
          updatedAt: _asDateTime(row['updated_at']) ?? serverUpdatedAt,
          version: _asInt(row['version']) ?? 1,
          syncState: SyncState.synced.name,
          serverUpdatedAt: serverUpdatedAt,
        ),
      );
    } else if (item.entityType == 'debt') {
      await _debts.upsert(
        DebtRow(
          id: _asString(row['id']) ?? item.entityId,
          groupId: _asString(row['group_id']),
          title: _asString(row['title']) ?? 'Hutang',
          principalAmount: _asInt(row['principal_amount']) ?? 1,
          dueDate: _asDateOnly(row['due_date']),
          notes: _asString(row['notes']),
          isArchived: row['is_archived'] == true,
          createdAt: _asDateTime(row['created_at']) ?? serverUpdatedAt,
          updatedAt: _asDateTime(row['updated_at']) ?? serverUpdatedAt,
          version: _asInt(row['version']) ?? 1,
          syncState: SyncState.synced.name,
          serverUpdatedAt: serverUpdatedAt,
        ),
      );
    } else {
      throw const AdminSyncException(
        code: 'invalid_conflict',
        message: 'Tipe konflik tidak dapat dimuat ulang.',
      );
    }

    await _queue.deleteOperation(operationId);
  }

  int _compareDependencyOrder(SyncQueueRow a, SyncQueueRow b) {
    final priority = _dependencyPriority(a).compareTo(_dependencyPriority(b));
    if (priority != 0) {
      return priority;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  int _dependencyPriority(SyncQueueRow item) {
    if (item.entityType == 'debt_group') {
      return item.operation == 'delete' ? 3 : 0;
    }
    if (item.entityType == 'debt' || item.entityType == 'debt_batch') {
      return 1;
    }
    return 2;
  }

  Future<bool> _dependenciesReady(
    SyncQueueRow item,
    Map<String, Object?> payload,
  ) async {
    if (item.entityType == 'debt_group') {
      final group = await _groups.findById(item.entityId);
      if (group?.syncState == SyncState.conflict.name) {
        return false;
      }
    }

    if (item.entityType == 'debt') {
      final debt = await _debts.findById(item.entityId);
      if (debt?.syncState == SyncState.conflict.name) {
        return false;
      }
      final groupId = _asString(payload['group_id']);
      if (groupId == null) {
        return true;
      }
      final group = await _groups.findById(groupId);
      return group != null && group.syncState == SyncState.synced.name;
    }

    if (item.entityType == 'debt_batch') {
      final groupIds = <String>{
        for (final debt in _payloadDebts(payload))
          if (_asString(debt['group_id']) case final String groupId) groupId,
      };
      for (final groupId in groupIds) {
        final group = await _groups.findById(groupId);
        if (group == null || group.syncState != SyncState.synced.name) {
          return false;
        }
      }
      return true;
    }

    if (item.entityType == 'payment') {
      final debtId = _asString(payload['debt_id']);
      if (debtId == null) {
        return false;
      }
      final debt = await _debts.findById(debtId);
      return debt != null && debt.syncState == SyncState.synced.name;
    }

    return true;
  }

  Future<void> _applySuccess(
    SyncQueueRow item,
    AdminMutationResult result,
    Map<String, Object?> payload,
  ) async {
    final serverUpdatedAt = result.serverUpdatedAt ?? _now().toUtc();
    if (item.entityType == 'debt_batch') {
      final itemsById = <String, AdminMutationItemResult>{
        for (final resultItem in result.items) resultItem.id: resultItem,
      };
      for (final debt in _payloadDebts(payload)) {
        final id = _asString(debt['id']);
        if (id == null) {
          continue;
        }
        final existing = await _debts.findById(id);
        if (existing == null) {
          continue;
        }
        final resultItem = itemsById[id];
        await _debts.markSynced(
          id: id,
          version: resultItem?.version ?? existing.version,
          serverUpdatedAt: resultItem?.serverUpdatedAt ?? serverUpdatedAt,
        );
      }
      return;
    }

    if (item.entityType == 'debt_group') {
      final existing = await _groups.findById(item.entityId);
      if (existing != null) {
        await _groups.markSynced(
          id: item.entityId,
          version: result.version ?? existing.version,
          serverUpdatedAt: serverUpdatedAt,
        );
      }
    } else if (item.entityType == 'debt') {
      final existing = await _debts.findById(item.entityId);
      if (existing != null) {
        await _debts.markSynced(
          id: item.entityId,
          version: result.version ?? existing.version,
          serverUpdatedAt: serverUpdatedAt,
        );
      }
    } else if (item.entityType == 'payment') {
      await _payments.markSynced(
        id: item.entityId,
        serverUpdatedAt: serverUpdatedAt,
      );
    }
  }

  Future<void> _markEntityConflict(
    SyncQueueRow item,
    Map<String, Object?> payload,
  ) async {
    if (item.entityType == 'debt_batch') {
      for (final debt in _payloadDebts(payload)) {
        final id = _asString(debt['id']);
        if (id != null) {
          await _debts.markConflict(id);
        }
      }
    } else if (item.entityType == 'debt_group') {
      await _groups.markConflict(item.entityId);
    } else if (item.entityType == 'debt') {
      await _debts.markConflict(item.entityId);
    }
  }

  List<Map<String, Object?>> _payloadDebts(Map<String, Object?> payload) {
    final value = payload['debts'];
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }

    return <Map<String, Object?>>[
      for (final raw in value)
        if (raw is Map) _stringKeyed(raw),
    ];
  }

  Map<String, Object?> _decodeObject(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('payload bukan objek');
    }
    return _stringKeyed(decoded);
  }

  Map<String, Object?> _decodeConflict(String? value) {
    if (value == null || value.isEmpty) {
      return const <String, Object?>{};
    }
    try {
      return _decodeObject(value);
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  Map<String, Object?> _stringKeyed(Map<dynamic, dynamic> value) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  String? _asString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _asInt(Object? value) {
    return value is num ? value.toInt() : null;
  }

  DateTime? _asDateTime(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  DateTime? _asDateOnly(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime.utc(year, month, day);
  }
}
