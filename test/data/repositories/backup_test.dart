import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/data/repositories/backup_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/domain/entities/backup_document.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 14, 12);

Future<void> _close(AppDatabase database) async {
  await database.close();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'export hanya memuat field bisnis dan tidak membocorkan metadata',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final groups = DebtGroupRepositoryImpl(database, now: _fixedNow);
        final debts = DebtRepositoryImpl(database, now: _fixedNow);
        final payments = PaymentRepositoryImpl(database, now: _fixedNow);
        final group = await groups.create(
          name: 'Keluarga',
          color: '#00695C',
          icon: 'family',
        );
        final debt = await debts.create(
          groupId: group.id,
          title: 'Hutang Sembako',
          principalAmount: 1000000,
          dueDate: DateTime.utc(2026, 12, 1),
          notes: 'Catatan',
        );
        await payments.create(
          debtId: debt.id,
          amount: 250000,
          notes: 'Cicilan',
        );

        final document = await BackupRepositoryImpl(
          database,
          now: _fixedNow,
        ).exportBackup();
        final json = document.toJson();

        expect(json['schema_version'], BackupDocument.currentSchemaVersion);
        expect(json['exported_at'], isA<String>());
        expect(json['debt_groups'], hasLength(1));
        expect(json['debts'], hasLength(1));
        expect(json['payments'], hasLength(1));

        final keys = <String>{};
        void collectKeys(Object? value) {
          if (value is Map) {
            for (final entry in value.entries) {
              keys.add(entry.key.toString());
              collectKeys(entry.value);
            }
          } else if (value is List) {
            for (final item in value) {
              collectKeys(item);
            }
          }
        }

        collectKeys(json);

        expect(keys, isNot(contains('version')));
        expect(keys, isNot(contains('operation_id')));
        expect(keys, isNot(contains('sync_state')));
        expect(keys, isNot(contains('server_updated_at')));
        expect(keys, isNot(contains('customer_id')));

        final groupJson = (json['debt_groups'] as List).single as Map;
        expect(groupJson['name'], 'Keluarga');
        expect(groupJson['color'], '#00695C');
        expect(groupJson['icon'], 'family');

        final debtJson = (json['debts'] as List).single as Map;
        expect(debtJson['group_id'], group.id);
        expect(debtJson['due_date'], '2026-12-01');

        final paymentJson = (json['payments'] as List).single as Map;
        expect(paymentJson['debt_id'], debt.id);
        expect(paymentJson['amount'], 250000);
      } finally {
        await _close(database);
      }
    },
  );

  test(
    'restore-merge menambahkan data baru dan mengabaikan duplikat',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      try {
        final sourceGroups = DebtGroupRepositoryImpl(source, now: _fixedNow);
        final sourceDebts = DebtRepositoryImpl(source, now: _fixedNow);
        final sourcePayments = PaymentRepositoryImpl(source, now: _fixedNow);
        final group = await sourceGroups.create(name: 'Keluarga');
        final debt = await sourceDebts.create(
          groupId: group.id,
          title: 'Hutang Sembako',
          principalAmount: 1000000,
          dueDate: DateTime.utc(2026, 12, 1),
        );
        final payment = await sourcePayments.create(
          debtId: debt.id,
          amount: 250000,
        );

        final backup = await BackupRepositoryImpl(
          source,
          now: _fixedNow,
        ).exportBackup();

        final targetRepository = BackupRepositoryImpl(target, now: _fixedNow);
        final preview = await targetRepository.previewRestore(backup);
        expect(preview.newGroups, 1);
        expect(preview.newDebts, 1);
        expect(preview.newPayments, 1);
        expect(preview.totalExisting, 0);

        final result = await targetRepository.restore(backup);
        expect(result.totalNew, 3);

        final storedGroup = await target.select(target.debtGroups).getSingle();
        final storedDebt = await target.select(target.debts).getSingle();
        final storedPayment = await target.select(target.payments).getSingle();

        expect(storedGroup.id, group.id);
        expect(storedGroup.syncState, 'pending');
        expect(storedGroup.version, 1);
        expect(storedDebt.id, debt.id);
        expect(storedDebt.syncState, 'pending');
        expect(storedDebt.version, 1);
        expect(storedPayment.id, payment.id);
        expect(storedPayment.operationId, payment.id);
        expect(storedPayment.syncState, 'pending');

        final queue = await SyncQueueDao(target).listAll();
        expect(queue, hasLength(3));
        expect(
          queue.map((row) => '${row.entityType}:${row.operation}'),
          containsAll(<String>[
            'debt_group:create',
            'debt:create',
            'payment:payment_create',
          ]),
        );

        final secondPreview = await targetRepository.previewRestore(backup);
        expect(secondPreview.totalNew, 0);
        expect(secondPreview.totalExisting, 3);

        await targetRepository.restore(backup);
        expect(await SyncQueueDao(target).listAll(), hasLength(3));
        expect(await target.select(target.debtGroups).get(), hasLength(1));
        expect(await target.select(target.debts).get(), hasLength(1));
        expect(await target.select(target.payments).get(), hasLength(1));
      } finally {
        await _close(source);
        await _close(target);
      }
    },
  );

  test('restore menolak referensi group/debt yang tidak ada', () async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      final group = await DebtGroupRepositoryImpl(
        database,
        now: _fixedNow,
      ).create(name: 'Keluarga');
      await DebtRepositoryImpl(
        database,
        now: _fixedNow,
      ).create(groupId: group.id, title: 'Hutang', principalAmount: 100000);

      final document = await BackupRepositoryImpl(
        database,
        now: _fixedNow,
      ).exportBackup();
      final json = document.toJson();

      final debts = (json['debts'] as List).cast<Map<String, Object?>>();
      debts.single['group_id'] = '00000000-0000-4000-8000-000000000099';
      final invalidGroupReference = BackupDocument.fromJson(json);

      final repository = BackupRepositoryImpl(database, now: _fixedNow);
      await expectLater(
        repository.previewRestore(invalidGroupReference),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.validation,
          ),
        ),
      );

      debts.single['group_id'] = group.id;
      final payments = (json['payments'] as List).cast<Map<String, Object?>>();
      payments
        ..clear()
        ..add(<String, Object?>{
          'id': '00000000-0000-4000-8000-000000000010',
          'debt_id': '00000000-0000-4000-8000-000000000099',
          'amount': 1000,
          'paid_at': '2026-11-14T12:00:00.000Z',
          'notes': null,
          'created_at': '2026-11-14T12:00:00.000Z',
        });
      final invalidDebtReference = BackupDocument.fromJson(json);

      await expectLater(
        repository.previewRestore(invalidDebtReference),
        throwsA(isA<AppException>()),
      );

      expect(await database.select(database.debts).get(), hasLength(1));
    } finally {
      await _close(database);
    }
  });

  test('backup invalid ditolak sebelum menyentuh database', () async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      expect(
        () => BackupDocument.fromJson(<String, Object?>{
          'schema_version': 99,
          'exported_at': '2026-11-14T12:00:00.000Z',
          'debt_groups': <Object?>[],
          'debts': <Object?>[],
          'payments': <Object?>[],
        }),
        throwsA(isA<AppException>()),
      );

      expect(
        () => BackupDocument.fromJson(<String, Object?>{
          'schema_version': 1,
          'exported_at': '2026-11-14T12:00:00.000Z',
          'debt_groups': <Object?>[],
          'debts': <Object?>[
            <String, Object?>{
              'id': '00000000-0000-4000-8000-000000000001',
              'group_id': null,
              'title': 'Hutang',
              'principal_amount': -1,
              'due_date': null,
              'notes': null,
              'is_archived': false,
              'created_at': '2026-11-14T12:00:00.000Z',
              'updated_at': '2026-11-14T12:00:00.000Z',
            },
          ],
          'payments': <Object?>[],
        }),
        throwsA(isA<AppException>()),
      );

      expect(
        () => BackupDocument.fromJsonString('{ bukan json'),
        throwsA(isA<AppException>()),
      );

      expect(await database.select(database.debts).get(), isEmpty);
      // A malformed file must never be applied.
    } finally {
      await _close(database);
    }
  });
}
