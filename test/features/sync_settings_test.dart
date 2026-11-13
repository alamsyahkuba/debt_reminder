import 'dart:convert';

import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/sync_queue_dao.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_admin_session_store.dart';

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
}
