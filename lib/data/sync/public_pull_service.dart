import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/sync_state.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';
import '../local/daos/debt_group_dao.dart';
import '../local/daos/payment_dao.dart';
import '../local/daos/sync_metadata_dao.dart';
import '../remote/public_read_repository.dart';

class PublicPullResult {
  const PublicPullResult({
    required this.groups,
    required this.debts,
    required this.payments,
  });

  final int groups;
  final int debts;
  final int payments;
}

class PublicPullService {
  PublicPullService({
    required AppDatabase database,
    required this.repository,
    SyncMetadataDao? metadataDao,
    DateTime Function()? now,
  }) : _db = database,
       _metadata = metadataDao ?? SyncMetadataDao(database),
       _groups = DebtGroupDao(database),
       _debts = DebtDao(database),
       _payments = PaymentDao(database),
       _now = now ?? (() => DateTime.now().toUtc());

  static const String _groupsCursorKey = 'public_pull_groups_cursor';
  static const String _debtsCursorKey = 'public_pull_debts_cursor';
  static const String _paymentsCursorKey = 'public_pull_payments_cursor';
  static const String _lastPullKey = 'last_public_pull_at';

  final AppDatabase _db;
  final PublicPullSource repository;
  final SyncMetadataDao _metadata;
  final DebtGroupDao _groups;
  final DebtDao _debts;
  final PaymentDao _payments;
  final DateTime Function() _now;

  Future<PublicPullResult> pull({bool full = false}) async {
    if (full) {
      await _clearCursors();
    }

    final groupCount = await _pullGroups(full: full);
    final debtCount = await _pullDebts();
    final paymentCount = await _pullPayments();

    await _metadata.setValue(
      key: _lastPullKey,
      value: _now().toUtc().toIso8601String(),
      updatedAt: _now().toUtc(),
    );

    return PublicPullResult(
      groups: groupCount,
      debts: debtCount,
      payments: paymentCount,
    );
  }

  Future<int> _pullGroups({required bool full}) async {
    var cursor = await _readCursor(_groupsCursorKey);
    final remoteIds = <String>{};
    var count = 0;

    while (true) {
      final page = await repository.fetchGroups(cursor: cursor);
      if (page.items.isEmpty) {
        break;
      }

      await _db.transaction(() async {
        for (final group in page.items) {
          remoteIds.add(group.id);
          final existing = await _groups.findById(group.id);
          if (existing != null && existing.syncState != SyncState.synced.name) {
            continue;
          }

          final row = DebtGroupRow(
            id: group.id,
            name: group.name,
            description: group.description,
            color: group.color,
            icon: group.icon,
            sortOrder: group.sortOrder,
            isArchived: group.isArchived,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt,
            version: existing?.version ?? 1,
            syncState: SyncState.synced.name,
            serverUpdatedAt: group.updatedAt,
          );
          await _groups.upsert(row);
          count++;
        }
      });

      cursor = page.cursor;
      await _writeCursor(_groupsCursorKey, cursor);
      if (page.items.length < repository.pageSize) {
        break;
      }
    }

    if (full) {
      final localGroups = await _groups.listAll();
      for (final row in localGroups) {
        if (row.syncState == SyncState.synced.name &&
            !remoteIds.contains(row.id)) {
          await _db.transaction(() async {
            final references = await _db
                .customSelect(
                  '''
              SELECT COUNT(*) AS count
              FROM debts
              WHERE group_id = ? AND sync_state IN (?, ?)
              ''',
                  variables: [
                    Variable.withString(row.id),
                    Variable.withString(SyncState.pending.name),
                    Variable.withString(SyncState.conflict.name),
                  ],
                  readsFrom: {_db.debts},
                )
                .getSingle();

            // Never let the group FK cascade modify an unsynced local debt.
            if (references.read<int>('count') == 0) {
              await _groups.deleteById(row.id);
            }
          });
        }
      }
    }

    return count;
  }

  Future<int> _pullDebts() async {
    var cursor = await _readCursor(_debtsCursorKey);
    var count = 0;

    while (true) {
      final page = await repository.fetchDebts(cursor: cursor);
      if (page.items.isEmpty) {
        break;
      }

      await _db.transaction(() async {
        for (final debt in page.items) {
          final existing = await _debts.findById(debt.id);
          if (existing != null && existing.syncState != SyncState.synced.name) {
            continue;
          }

          final row = DebtRow(
            id: debt.id,
            groupId: debt.groupId,
            title: debt.title,
            principalAmount: debt.principalAmount,
            dueDate: debt.dueDate,
            notes: debt.notes,
            isArchived: debt.isArchived,
            createdAt: debt.createdAt,
            updatedAt: debt.updatedAt,
            version: existing?.version ?? 1,
            syncState: SyncState.synced.name,
            serverUpdatedAt: debt.updatedAt,
          );
          await _debts.upsert(row);
          count++;
        }
      });

      cursor = page.cursor;
      await _writeCursor(_debtsCursorKey, cursor);
      if (page.items.length < repository.pageSize) {
        break;
      }
    }

    return count;
  }

  Future<int> _pullPayments() async {
    var cursor = await _readCursor(_paymentsCursorKey);
    var count = 0;

    while (true) {
      final page = await repository.fetchPayments(cursor: cursor);
      if (page.items.isEmpty) {
        break;
      }

      await _db.transaction(() async {
        for (final payment in page.items) {
          await _payments.insertIfAbsent(
            PaymentRow(
              id: payment.id,
              debtId: payment.debtId,
              amount: payment.amount,
              paidAt: payment.paidAt,
              notes: payment.notes,
              operationId: payment.id,
              createdAt: payment.createdAt,
              syncState: SyncState.synced.name,
              serverUpdatedAt: payment.createdAt,
            ),
          );
          count++;
        }
      });

      cursor = page.cursor;
      await _writeCursor(_paymentsCursorKey, cursor);
      if (page.items.length < repository.pageSize) {
        break;
      }
    }

    return count;
  }

  Future<PublicCursor?> _readCursor(String key) async {
    return PublicCursor.fromJson(await _metadata.getValue(key));
  }

  Future<void> _writeCursor(String key, PublicCursor? cursor) async {
    await _metadata.setValue(
      key: key,
      value: cursor?.toJson() ?? '',
      updatedAt: _now().toUtc(),
    );
  }

  Future<void> _clearCursors() async {
    final now = _now().toUtc();
    for (final key in <String>[
      _groupsCursorKey,
      _debtsCursorKey,
      _paymentsCursorKey,
    ]) {
      await _metadata.setValue(key: key, value: '', updatedAt: now);
    }
  }
}

AppException publicPullFailure(Object error) {
  if (error is AppException) {
    return error;
  }
  return AppException(
    code: AppErrorCode.remoteUnavailable,
    message: 'Data publik tidak dapat diperbarui.',
    cause: error,
  );
}
