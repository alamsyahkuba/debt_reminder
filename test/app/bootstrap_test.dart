import 'package:debt_reminder/app/bootstrap.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const AppConfig _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

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
        ],
        child: const AppBootstrap(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
    expect(await database.select(database.debtGroups).get(), isEmpty);
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
        ],
        child: const AppBootstrap(),
      ),
    );
    await tester.pumpAndSettle();

    expect(await database.select(database.debtGroups).get(), hasLength(2));
    expect(await database.select(database.debts).get(), hasLength(2));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(await database.select(database.syncQueue).get(), isEmpty);
  });
}
