import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/utils/date_formatter.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_admin_session_store.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 14, 10);

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

  Future<void> pump(WidgetTester tester, {bool unlocked = true}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            unlocked
                ? FakeAdminSessionStore.unlocked()
                : FakeAdminSessionStore(),
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

Future<void> _openDebts(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('drawer-item-/debts')));
  await tester.pumpAndSettle();
}

Future<void> _openBulk(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('debts-bulk-add-button')));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key key) {
  final field = tester.widget<TextField>(find.byKey(key));
  return field.controller?.text ?? '';
}

void main() {
  testWidgets('admin dapat menyimpan dua hutang sekaligus', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.groups.create(name: 'Keluarga');
      await harness.pump(tester);
      await _openDebts(tester);

      expect(find.byKey(const Key('debts-bulk-add-button')), findsOneWidget);
      await _openBulk(tester);

      expect(find.byKey(const Key('bulk-debt-screen')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('bulk-debt-title-0')),
        'Hutang satu',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-principal-0')),
        '100000',
      );

      await tester.tap(find.byKey(const Key('bulk-debt-add-row')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bulk-debt-title-1')),
        'Hutang dua',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-principal-1')),
        '200000',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Simpan 2 hutang?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-debt-confirm-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debts-screen')), findsOneWidget);
      expect(find.text('Hutang satu'), findsOneWidget);
      expect(find.text('Hutang dua'), findsOneWidget);

      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(2));
      final queue = await harness.database
          .select(harness.database.syncQueue)
          .get();
      final batch = queue.where((row) => row.entityType == 'debt_batch');
      expect(batch, hasLength(1));
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('group batch diterapkan ke semua hutang', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final group = await harness.groups.create(name: 'Keluarga');
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await tester.tap(find.byKey(const Key('bulk-debt-group-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluarga').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('bulk-debt-title-0')),
        'Hutang keluarga',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-principal-0')),
        '75000',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();

      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(1));
      expect(stored.single.groupId, group.id);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('tanggal default otomatis dan checklist per bulan bertahap', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await tester.tap(find.byKey(const Key('bulk-debt-default-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OKE').last);
      await tester.pumpAndSettle();

      expect(
        _fieldText(tester, const Key('bulk-debt-due-0')),
        startsWith('15/'),
      );

      await tester.tap(find.byKey(const Key('bulk-debt-monthly-checkbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk-debt-add-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-debt-add-row')));
      await tester.pumpAndSettle();

      final firstDate = _fieldText(tester, const Key('bulk-debt-due-0'));
      final secondDate = _fieldText(tester, const Key('bulk-debt-due-1'));
      final thirdDate = _fieldText(tester, const Key('bulk-debt-due-2'));
      expect(firstDate, startsWith('15/'));
      expect(secondDate, isNot(firstDate));
      expect(thirdDate, isNot(secondDate));

      for (var index = 0; index < 3; index++) {
        await tester.enterText(
          find.byKey(Key('bulk-debt-title-$index')),
          'Hutang bulan ${index + 1}',
        );
        await tester.enterText(
          find.byKey(Key('bulk-debt-principal-$index')),
          '${100000 * (index + 1)}',
        );
      }
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-debt-confirm-save')));
      await tester.pumpAndSettle();

      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(3));
      final dates =
          stored.map((row) => row.dueDate).whereType<DateTime>().toList()
            ..sort();
      expect(dates, hasLength(3));
      final firstDateOnly = DateTime.utc(
        dates[0].year,
        dates[0].month,
        dates[0].day,
      );
      final secondDateOnly = DateTime.utc(
        dates[1].year,
        dates[1].month,
        dates[1].day,
      );
      final thirdDateOnly = DateTime.utc(
        dates[2].year,
        dates[2].month,
        dates[2].day,
      );
      expect(secondDateOnly, addMonthsClamped(firstDateOnly, 1));
      expect(thirdDateOnly, addMonthsClamped(firstDateOnly, 2));
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('baris kosong di akhir diabaikan', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await tester.enterText(
        find.byKey(const Key('bulk-debt-title-0')),
        'Hutang saja',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-principal-0')),
        '50000',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-debt-add-row')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Simpan 1 hutang?'), findsNothing);
      expect(find.text('Hutang saja'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.debts).get(),
        hasLength(1),
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('baris terisi sebagian menampilkan error tanpa menyimpan', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await tester.enterText(
        find.byKey(const Key('bulk-debt-title-0')),
        'Belum ada nominal',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Pokok hutang harus berupa angka positif.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bulk-debt-screen')), findsOneWidget);
      expect(
        await harness.database.select(harness.database.debts).get(),
        isEmpty,
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('publik tidak melihat tombol dan route bulk dijaga PIN', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester, unlocked: false);
      await _openDebts(tester);

      expect(find.byKey(const Key('debts-bulk-add-button')), findsNothing);

      final context = tester.element(find.byKey(const Key('debts-screen')));
      GoRouter.of(context).go('/debts/bulk');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-pin-screen')), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });
}
