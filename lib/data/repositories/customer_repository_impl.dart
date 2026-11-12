import 'package:uuid/uuid.dart';

import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_summary.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/validation/entity_validation.dart';
import '../local/app_database.dart';
import '../local/daos/customer_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import 'mappers.dart';
import 'outbox_payloads.dart';
import 'repository_support.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(
    AppDatabase db, {
    SyncQueueDao? syncQueueDao,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _db = db,
       _customers = CustomerDao(db),
       _queue = syncQueueDao ?? SyncQueueDao(db),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? nowUtc;

  final AppDatabase _db;
  final CustomerDao _customers;
  final SyncQueueDao _queue;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Stream<List<Customer>> watchAll({bool includeArchived = false}) {
    return _customers
        .watchAll(includeArchived: includeArchived)
        .map(
          (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }

  @override
  Stream<Customer?> watchById(String id) {
    return _customers.watchById(id).map((row) => row?.toDomain());
  }

  @override
  Stream<CustomerSummary> watchSummary(String id) {
    return _customers.watchSummary(id);
  }

  @override
  Stream<Map<String, CustomerSummary>> watchSummaries() {
    return _customers.watchSummaries();
  }

  @override
  Future<Customer?> findById(String id) async {
    final row = await _customers.findById(id);
    return row?.toDomain();
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final normalizedName = validateText(
      name,
      field: 'Nama pelanggan',
      maxLength: 200,
    );
    final normalizedPhone = validateOptionalText(
      phone,
      field: 'Nomor telepon',
      maxLength: 40,
    );
    final normalizedNotes = validateOptionalText(
      notes,
      field: 'Catatan pelanggan',
    );
    final now = _now().toUtc();
    final row = CustomerRow(
      id: _uuid.v4(),
      name: normalizedName,
      phone: normalizedPhone,
      notes: normalizedNotes,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      version: 1,
      syncState: 'pending',
      serverUpdatedAt: null,
    );

    return _dbTransaction(() async {
      await _customers.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'customer',
        entityId: row.id,
        operation: 'create',
        payload: customerCreatePayload(row.toDomain()),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<Customer> update({
    required String id,
    required int expectedVersion,
    required String name,
    String? phone,
    String? notes,
  }) async {
    final normalizedName = validateText(
      name,
      field: 'Nama pelanggan',
      maxLength: 200,
    );
    final normalizedPhone = validateOptionalText(
      phone,
      field: 'Nomor telepon',
      maxLength: 40,
    );
    final normalizedNotes = validateOptionalText(
      notes,
      field: 'Catatan pelanggan',
    );

    return _dbTransaction(() async {
      final existing =
          await _customers.findById(id) ?? throwNotFound('Pelanggan');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Pelanggan',
      );

      final now = _now().toUtc();
      final row = CustomerRow(
        id: existing.id,
        name: normalizedName,
        phone: normalizedPhone,
        notes: normalizedNotes,
        isArchived: existing.isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _customers.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'customer',
        entityId: row.id,
        operation: 'update',
        payload: customerUpdatePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  @override
  Future<Customer> setArchived({
    required String id,
    required int expectedVersion,
    required bool isArchived,
  }) async {
    return _dbTransaction(() async {
      final existing =
          await _customers.findById(id) ?? throwNotFound('Pelanggan');
      ensureExpectedVersion(
        currentVersion: existing.version,
        expectedVersion: expectedVersion,
        entityName: 'Pelanggan',
      );

      if (existing.isArchived == isArchived) {
        return existing.toDomain();
      }

      final now = _now().toUtc();
      final row = CustomerRow(
        id: existing.id,
        name: existing.name,
        phone: existing.phone,
        notes: existing.notes,
        isArchived: isArchived,
        createdAt: existing.createdAt,
        updatedAt: now,
        version: existing.version + 1,
        syncState: 'pending',
        serverUpdatedAt: existing.serverUpdatedAt,
      );

      await _customers.upsert(row);
      await _queue.enqueue(
        operationId: _uuid.v4(),
        entityType: 'customer',
        entityId: row.id,
        operation: 'archive',
        payload: customerArchivePayload(row.toDomain(), expectedVersion),
        createdAt: now,
      );
      return row.toDomain();
    });
  }

  Future<T> _dbTransaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }
}
