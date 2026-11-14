import 'dart:convert';

import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/data/backup/backup_file_service.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/domain/entities/backup_document.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_admin_session_store.dart';

class _FakeBackupFileService extends BackupFileService {
  BackupDocument? shared;
  BackupDocument? picked;

  @override
  Future<void> shareBackup(BackupDocument document) async {
    shared = document;
  }

  @override
  Future<BackupDocument?> pickBackup() async => picked;
}

BackupDocument _backupDocument() {
  final now = DateTime.utc(2026, 11, 14, 8);
  return BackupDocument(
    exportedAt: now,
    groups: <BackupDebtGroup>[
      BackupDebtGroup(
        id: 'b1000000-0000-4000-8000-000000000001',
        name: 'Keluarga',
        description: null,
        color: null,
        icon: 'family',
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    debts: <BackupDebt>[
      BackupDebt(
        id: 'b1000000-0000-4000-8000-000000000002',
        groupId: 'b1000000-0000-4000-8000-000000000001',
        title: 'Hutang Restore',
        principalAmount: 500000,
        dueDate: DateTime.utc(2026, 12, 1),
        notes: null,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    payments: <BackupPayment>[
      BackupPayment(
        id: 'b1000000-0000-4000-8000-000000000003',
        debtId: 'b1000000-0000-4000-8000-000000000002',
        amount: 100000,
        paidAt: now,
        notes: null,
        createdAt: now,
      ),
    ],
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void main() {
  testWidgets('settings menampilkan status sync dan kartu konflik', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    var cleanedUp = false;
    Future<void> cleanup() async {
      if (cleanedUp) {
        return;
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      await database.close();
      cleanedUp = true;
    }

    addTearDown(cleanup);

    final queue = SyncQueueDao(database);
    await queue.enqueue(
      operationId: 'conflict-op',
      entityType: 'debt_group',
      entityId: 'group-1',
      operation: 'update',
      payload: <String, Object?>{'id': 'group-1', 'expected_version': 1},
      createdAt: DateTime.utc(2026, 11, 13, 10),
    );
    await queue.markConflict(
      operationId: 'conflict-op',
      conflictData: jsonEncode(<String, Object?>{
        'status': 'conflict',
        'entity_type': 'debt_group',
        'entity_id': 'group-1',
        'server_version': 2,
        'server_updated_at': '2026-11-13T10:00:00Z',
        'server_row': <String, Object?>{'id': 'group-1'},
      }),
    );

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              supabaseUrl: '',
              supabaseAnonKey: '',
            ),
          ),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('drawer-item-/settings')),
    );
    await _settle(tester);

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.textContaining('Supabase belum dikonfigurasi'), findsOneWidget);
    expect(find.byKey(const Key('conflict-tile-conflict-op')), findsOneWidget);
    expect(
      find.byKey(const Key('conflict-reload-conflict-op')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('conflict-keep-conflict-op')), findsOneWidget);
    expect(find.byKey(const Key('settings-sync-now')), findsOneWidget);

    await cleanup();
  });

  testWidgets('admin dapat export dan restore-merge backup JSON', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final fileService = _FakeBackupFileService();
    var cleanedUp = false;
    Future<void> cleanup() async {
      if (cleanedUp) {
        return;
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      await database.close();
      cleanedUp = true;
    }

    addTearDown(cleanup);

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              supabaseUrl: '',
              supabaseAnonKey: '',
            ),
          ),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
          backupFileServiceProvider.overrideWithValue(fileService),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('drawer-item-/settings')),
    );
    await _settle(tester);

    fileService.picked = _backupDocument();
    final importButton = find.byKey(const Key('settings-backup-import'));
    await tester.ensureVisible(importButton);
    await _settle(tester);
    await tester.tap(importButton);
    await _settle(tester);

    expect(find.text('Terapkan backup?'), findsOneWidget);
    expect(
      find.textContaining('1 group, 1 hutang, 1 pembayaran'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settings-backup-confirm')));
    await _settle(tester);

    expect(await database.select(database.debtGroups).get(), hasLength(1));
    expect(await database.select(database.debts).get(), hasLength(1));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(await SyncQueueDao(database).listAll(), hasLength(3));
    expect(find.textContaining('Restore selesai'), findsOneWidget);

    final exportButton = find.byKey(const Key('settings-backup-export'));
    await tester.ensureVisible(exportButton);
    await _settle(tester);
    await tester.tap(exportButton);
    await _settle(tester);

    expect(fileService.shared, isNotNull);
    expect(fileService.shared!.groups, hasLength(1));
    expect(fileService.shared!.debts, hasLength(1));
    expect(fileService.shared!.payments, hasLength(1));

    await cleanup();
  });
}
