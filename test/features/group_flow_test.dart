import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_admin_session_store.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 12, 10);

class _Harness {
  _Harness(this.database);

  final AppDatabase database;

  late final DebtGroupRepositoryImpl groups = DebtGroupRepositoryImpl(
    database,
    now: _fixedNow,
  );
  late final DebtRepositoryImpl debts = DebtRepositoryImpl(
    database,
    now: _fixedNow,
  );
  late final PaymentRepositoryImpl payments = PaymentRepositoryImpl(
    database,
    now: _fixedNow,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await database.close();
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

Future<void> _tapDrawerItem(WidgetTester tester, String path) async {
  final finder = find.byKey(ValueKey<String>('drawer-item-$path'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openGroups(WidgetTester tester) async {
  await _openDrawer(tester);
  await _tapDrawerItem(tester, '/groups');
}

Future<void> _tapAfterScroll(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('membuat group dari form dan outbox tercatat', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openGroups(tester);

      expect(find.text('Belum ada group'), findsOneWidget);
      await tester.tap(find.byKey(const Key('groups-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('group-name-field')),
        'Keluarga',
      );
      await _tapAfterScroll(tester, find.byKey(const Key('group-save-button')));

      expect(find.text('Keluarga'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.debtGroups).get(),
        hasLength(1),
      );
      expect(
        await harness.database.select(harness.database.syncQueue).get(),
        hasLength(1),
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('hapus group memindahkan hutang ke Unassigned', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final group = await harness.groups.create(name: 'Keluarga');
      final debt = await harness.debts.create(
        groupId: group.id,
        title: 'Hutang keluarga',
        principalAmount: 500000,
      );

      await harness.pump(tester);
      await _openGroups(tester);
      await tester.tap(find.byKey(Key('group-tile-${group.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Hutang keluarga'), findsOneWidget);
      await tester.tap(find.byKey(const Key('group-delete-button')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Group'), findsOneWidget);
      await tester.tap(find.text('Hapus Group'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada group'), findsOneWidget);
      expect(await harness.groups.findById(group.id), isNull);
      final storedDebt = await harness.debts.findById(debt.id);
      expect(storedDebt, isNotNull);
      expect(storedDebt?.groupId, isNull);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('pindahkan hutang ke group lain dari detail', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final family = await harness.groups.create(name: 'Keluarga');
      final business = await harness.groups.create(name: 'Usaha');
      final debt = await harness.debts.create(
        groupId: family.id,
        title: 'Hutang',
        principalAmount: 100000,
      );

      await harness.pump(tester);
      await _openGroups(tester);
      await tester.tap(find.byKey(Key('group-tile-${family.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('debt-actions-${debt.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pindah group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usaha'));
      await tester.pumpAndSettle();

      final storedDebt = await harness.debts.findById(debt.id);
      expect(storedDebt?.groupId, business.id);
    } finally {
      await harness.dispose(tester);
    }
  });
}
