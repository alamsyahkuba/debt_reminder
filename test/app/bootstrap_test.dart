import 'package:debt_reminder/app/bootstrap.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_admin_session_store.dart';

const AppConfig _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('bootstrap membuka database lalu menampilkan dashboard', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
        ],
        child: const AppBootstrap(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
    expect(await database.select(database.debtGroups).get(), isEmpty);

    await _disposeApp(tester);
  });

  testWidgets('flag development mengisi seed demo tanpa outbox', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const seededConfig = AppConfig(
      environment: AppEnvironment.development,
      supabaseUrl: '',
      supabaseAnonKey: '',
      seedDemoData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(seededConfig),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
        ],
        child: const AppBootstrap(),
      ),
    );
    await tester.pumpAndSettle();

    expect(await database.select(database.debtGroups).get(), hasLength(2));
    expect(await database.select(database.debts).get(), hasLength(2));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(await database.select(database.syncQueue).get(), isEmpty);

    await _disposeApp(tester);
  });
}
