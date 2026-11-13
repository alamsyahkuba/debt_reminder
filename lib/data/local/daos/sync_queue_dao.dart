import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

class SyncQueueSummary {
  const SyncQueueSummary({
    required this.pending,
    required this.processing,
    required this.conflict,
    required this.failed,
  });

  factory SyncQueueSummary.fromCounts(Map<String, int> counts) {
    return SyncQueueSummary(
      pending: counts['pending'] ?? 0,
      processing: counts['processing'] ?? 0,
      conflict: counts['conflict'] ?? 0,
      failed: counts['failed'] ?? 0,
    );
  }

  static const SyncQueueSummary empty = SyncQueueSummary(
    pending: 0,
    processing: 0,
    conflict: 0,
    failed: 0,
  );

  final int pending;
  final int processing;
  final int conflict;
  final int failed;

  int get total => pending + processing + conflict + failed;

  bool get hasIssues => conflict > 0 || failed > 0;
}

class SyncQueueDao {
  SyncQueueDao(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String operationId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) async {
    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            operationId: operationId,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            createdAt: createdAt,
          ),
        );
  }

  Future<SyncQueueRow?> findByOperationId(String operationId) {
    return (_db.select(_db.syncQueue)
          ..where((table) => table.operationId.equals(operationId)))
        .getSingleOrNull();
  }

  Future<List<SyncQueueRow>> listAll() {
    return (_db.select(
      _db.syncQueue,
    )..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();
  }

  Stream<SyncQueueSummary> watchSummary() {
    final query = _db.customSelect(
      '''
      SELECT status, COUNT(*) AS count
      FROM sync_queue
      GROUP BY status
      ''',
      readsFrom: {_db.syncQueue},
    );

    return query.watch().map((rows) {
      final counts = <String, int>{};
      for (final row in rows) {
        counts[row.read<String>('status')] = row.read<int>('count');
      }
      return SyncQueueSummary.fromCounts(counts);
    });
  }

  Stream<List<SyncQueueRow>> watchConflicts() {
    return (_db.select(_db.syncQueue)
          ..where((table) => table.status.equals('conflict'))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .watch();
  }

  Future<List<SyncQueueRow>> listReady(DateTime now, {int limit = 50}) {
    final query = _db.select(_db.syncQueue)
      ..where(
        (table) =>
            table.status.equals('pending') &
            (table.nextRetryAt.isNull() |
                table.nextRetryAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
      ..limit(limit);

    return query.get();
  }

  Future<void> recoverInterrupted() async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.status.equals('processing'))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        lastErrorCode: Value(null),
      ),
    );
  }

  Future<void> markProcessing(String operationId) async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).write(
      const SyncQueueCompanion(
        status: Value('processing'),
        lastErrorCode: Value(null),
      ),
    );
  }

  Future<void> markRetry({
    required String operationId,
    required int retryCount,
    required DateTime nextRetryAt,
    required String errorCode,
  }) async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: const Value('pending'),
        retryCount: Value(retryCount),
        nextRetryAt: Value(nextRetryAt),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  Future<void> markAwaitingAuth({
    required String operationId,
    required String errorCode,
  }) async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: const Value('pending'),
        nextRetryAt: const Value(null),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  Future<void> markFailed({
    required String operationId,
    required String errorCode,
  }) async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: const Value('failed'),
        nextRetryAt: const Value(null),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  Future<void> markConflict({
    required String operationId,
    required String conflictData,
    String errorCode = 'version_conflict',
  }) async {
    await (_db.update(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: const Value('conflict'),
        nextRetryAt: const Value(null),
        lastErrorCode: Value(errorCode),
        conflictData: Value(conflictData),
      ),
    );
  }

  Future<void> deleteOperation(String operationId) async {
    await (_db.delete(
      _db.syncQueue,
    )..where((table) => table.operationId.equals(operationId))).go();
  }
}
