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

Future<void> _openDebts(WidgetTester tester) async {
  await _openDrawer(tester);
  await _tapDrawerItem(tester, '/debts');
}

Future<void> _tapAfterScroll(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('membuat hutang dari form tanpa customer', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester);
      await _openDebts(tester);

      expect(find.text('Belum ada hutang'), findsOneWidget);
      await tester.tap(find.byKey(const Key('debts-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('debt-title-field')),
        'Hutang Sembako',
      );
      await tester.enterText(
        find.byKey(const Key('debt-principal-field')),
        '500000',
      );
      await _tapAfterScroll(tester, find.byKey(const Key('debt-save-button')));

      expect(find.text('Hutang Sembako'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.debts).get(),
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

  testWidgets('search hutang bekerja dan status tampil di list', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final motor = await harness.debts.create(
        title: 'Hutang Motor',
        principalAmount: 2000000,
        dueDate: DateTime.utc(2026, 12, 1),
      );
      await harness.debts.create(
        title: 'Hutang Sembako',
        principalAmount: 500000,
        dueDate: DateTime.utc(2026, 12, 1),
      );
      await harness.payments.create(debtId: motor.id, amount: 500000);

      await harness.pump(tester);
      await _openDebts(tester);

      expect(find.text('Hutang Motor'), findsOneWidget);
      expect(find.text('Hutang Sembako'), findsOneWidget);
      expect(find.text('Sebagian'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('debt-search-field')),
        'Motor',
      );
      await tester.pumpAndSettle();

      expect(find.text('Hutang Motor'), findsOneWidget);
      expect(find.text('Hutang Sembako'), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('detail hutang menampilkan pembayaran dan archive', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final group = await harness.groups.create(name: 'Keluarga');
      final debt = await harness.debts.create(
        groupId: group.id,
        title: 'Hutang Keluarga',
        principalAmount: 1000000,
        notes: 'Catatan hutang',
      );
      await harness.payments.create(debtId: debt.id, amount: 250000);

      await harness.pump(tester);
      await _openDebts(tester);
      await tester.tap(find.byKey(Key('debt-tile-${debt.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Detail Hutang'), findsOneWidget);
      expect(find.text('Histori pembayaran'), findsOneWidget);
      expect(find.text('Rp 250.000'), findsWidgets);
      expect(find.text('Keluarga • Tanpa jatuh tempo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('debt-archive-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada hutang'), findsOneWidget);
      final stored = await harness.debts.findById(debt.id);
      expect(stored?.isArchived, isTrue);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('hard delete hutang tanpa pembayaran dari detail', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final debt = await harness.debts.create(
        title: 'Hutang Dihapus',
        principalAmount: 500000,
      );

      await harness.pump(tester);
      await _openDebts(tester);
      await tester.tap(find.byKey(Key('debt-tile-${debt.id}')));
      await tester.pumpAndSettle();

      await _tapAfterScroll(
        tester,
        find.byKey(const Key('debt-delete-button')),
      );
      expect(find.text('Hapus hutang permanen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus permanen'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada hutang'), findsOneWidget);
      expect(await harness.debts.findById(debt.id), isNull);
      final queue = await harness.database
          .select(harness.database.syncQueue)
          .get();
      expect(queue.where((row) => row.operation == 'delete'), hasLength(1));
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('hard delete dinonaktifkan jika sudah ada pembayaran', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final debt = await harness.debts.create(
        title: 'Hutang Cicilan',
        principalAmount: 1000000,
      );
      await harness.payments.create(debtId: debt.id, amount: 250000);

      await harness.pump(tester);
      await _openDebts(tester);
      await tester.tap(find.byKey(Key('debt-tile-${debt.id}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('debt-delete-blocked-message')),
        findsOneWidget,
      );
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('debt-delete-button')),
      );
      expect(button.onPressed, isNull);
      expect(await harness.debts.findById(debt.id), isNotNull);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('mencatat pembayaran dan memperbarui sisa hutang', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final debt = await harness.debts.create(
        title: 'Hutang Motor',
        principalAmount: 1000000,
        dueDate: DateTime.utc(2026, 12, 1),
      );

      await harness.pump(tester);
      await _openDebts(tester);
      await tester.tap(find.byKey(Key('debt-tile-${debt.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('debt-add-payment-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment-form-screen')), findsOneWidget);
      expect(find.text('Sisa hutang: Rp 1.000.000'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('payment-amount-field')),
        '250000',
      );
      await tester.enterText(
        find.byKey(const Key('payment-notes-field')),
        'Cicilan pertama',
      );
      await _tapAfterScroll(
        tester,
        find.byKey(const Key('payment-save-button')),
      );

      expect(find.text('Catat pembayaran?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Hutang'), findsOneWidget);
      expect(find.text('Rp 750.000'), findsWidgets);
      expect(find.textContaining('Cicilan pertama'), findsOneWidget);

      final stored = await harness.database
          .select(harness.database.payments)
          .get();
      expect(stored, hasLength(1));
      expect(stored.single.amount, 250000);

      final paymentQueue =
          (await harness.database.select(harness.database.syncQueue).get())
              .where((row) => row.entityType == 'payment')
              .toList();
      expect(paymentQueue, hasLength(1));
      expect(paymentQueue.single.operation, 'payment_create');
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('overpayment ditolak oleh form pembayaran', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final debt = await harness.debts.create(
        title: 'Hutang Motor',
        principalAmount: 500000,
      );

      await harness.pump(tester);
      await _openDebts(tester);
      await tester.tap(find.byKey(Key('debt-tile-${debt.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('debt-add-payment-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('payment-amount-field')),
        '600000',
      );
      await _tapAfterScroll(
        tester,
        find.byKey(const Key('payment-save-button')),
      );

      expect(find.text('Nominal melebihi sisa hutang.'), findsOneWidget);
      expect(find.byKey(const Key('payment-form-screen')), findsOneWidget);
      expect(
        await harness.database.select(harness.database.payments).get(),
        isEmpty,
      );
    } finally {
      await harness.dispose(tester);
    }
  });
}
