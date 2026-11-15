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
    tester.view.physicalSize = const Size(800, 1800);
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

Future<void> _fillGeneratedBatch(
  WidgetTester tester, {
  String name = 'Budi',
  String count = '3',
  String principal = '500000',
}) async {
  await tester.enterText(find.byKey(const Key('bulk-debt-name-field')), name);
  await tester.enterText(
    find.byKey(const Key('bulk-debt-installment-field')),
    count,
  );
  await tester.enterText(
    find.byKey(const Key('bulk-debt-principal-field')),
    principal,
  );
  await tester.pump();
}

Future<void> _chooseDay15(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bulk-debt-default-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('15').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OKE').last);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key key) {
  final field = tester.widget<TextField>(find.byKey(key));
  return field.controller?.text ?? '';
}

void main() {
  testWidgets('menghasilkan judul Nama 1..N dan menyimpan semua angsuran', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);

      expect(find.byKey(const Key('debts-bulk-add-button')), findsOneWidget);
      await _openBulk(tester);
      expect(find.byKey(const Key('bulk-debt-screen')), findsOneWidget);

      await _fillGeneratedBatch(tester);

      expect(find.text('Pratinjau 3 hutang'), findsOneWidget);
      expect(find.text('Budi 1'), findsOneWidget);
      expect(find.text('Budi 2'), findsOneWidget);
      expect(find.text('Budi 3'), findsOneWidget);
      expect(find.text('Total: Rp 1.500.000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Simpan 3 hutang?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-debt-confirm-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debts-screen')), findsOneWidget);
      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(3));
      expect(stored.map((row) => row.title).toList()..sort(), <String>[
        'Budi 1',
        'Budi 2',
        'Budi 3',
      ]);
      expect(stored.every((row) => row.principalAmount == 500000), isTrue);

      final queue = await harness.database
          .select(harness.database.syncQueue)
          .get();
      expect(
        queue.where((row) => row.entityType == 'debt_batch'),
        hasLength(1),
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('hutang hasil generate dapat diedit sebelum disimpan', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);
      await _fillGeneratedBatch(tester);

      await tester.tap(find.byKey(const Key('bulk-debt-edit-1')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Hutang 2'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('bulk-debt-edit-title')),
        'Budi spesial',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-edit-principal')),
        '750000',
      );
      await tester.tap(find.byKey(const Key('bulk-debt-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('Budi spesial'), findsOneWidget);
      expect(find.text('Total: Rp 1.750.000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-debt-confirm-save')));
      await tester.pumpAndSettle();

      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(3));
      final edited = stored.singleWhere((row) => row.title == 'Budi spesial');
      expect(edited.principalAmount, 750000);
      expect(stored.map((row) => row.title).toList()..sort(), <String>[
        'Budi 1',
        'Budi 3',
        'Budi spesial',
      ]);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('group batch diterapkan ke semua angsuran', (tester) async {
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

      await _fillGeneratedBatch(
        tester,
        name: 'Hutang Keluarga',
        count: '1',
        principal: '75000',
      );
      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();

      final stored = await harness.database
          .select(harness.database.debts)
          .get();
      expect(stored, hasLength(1));
      expect(stored.single.groupId, group.id);
      expect(stored.single.title, 'Hutang Keluarga 1');
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('jatuh tempo default dan checklist per bulan bertahap', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await _chooseDay15(tester);
      expect(
        _fieldText(tester, const Key('bulk-debt-default-date')),
        startsWith('15/'),
      );
      await tester.tap(find.byKey(const Key('bulk-debt-monthly-checkbox')));
      await tester.pumpAndSettle();

      await _fillGeneratedBatch(tester);
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
      final first = DateTime.utc(dates[0].year, dates[0].month, dates[0].day);
      final second = DateTime.utc(dates[1].year, dates[1].month, dates[1].day);
      final third = DateTime.utc(dates[2].year, dates[2].month, dates[2].day);
      expect(second, addMonthsClamped(first, 1));
      expect(third, addMonthsClamped(first, 2));
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('validasi jumlah angsuran dan nominal menolak simpan', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);
      await _openBulk(tester);

      await tester.enterText(
        find.byKey(const Key('bulk-debt-name-field')),
        'Tidak valid',
      );
      await tester.enterText(
        find.byKey(const Key('bulk-debt-installment-field')),
        '51',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-debt-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Jumlah angsuran harus 1-50.'), findsOneWidget);
      expect(
        find.text('Pokok per angsuran harus berupa angka positif.'),
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
