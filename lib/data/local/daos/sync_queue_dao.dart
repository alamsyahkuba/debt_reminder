import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

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
}
