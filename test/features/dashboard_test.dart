import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/repositories/debt_group_repository_impl.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _fixedNow() => DateTime.utc(2026, 11, 12, 10);

Finder _metricText(String key, String value) {
  return find.descendant(of: find.byKey(Key(key)), matching: find.text(value));
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

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
        overrides: [appDatabaseProvider.overrideWithValue(database)],
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

void main() {
  testWidgets('dashboard menghitung total, status, group, dan jatuh tempo', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final group = await harness.groups.create(name: 'Keluarga');

      final partial = await harness.debts.create(
        groupId: group.id,
        title: 'Hutang Motor',
        principalAmount: 1000000,
        dueDate: today.add(const Duration(days: 3)),
      );
      await harness.payments.create(debtId: partial.id, amount: 400000);

      final overdue = await harness.debts.create(
        groupId: group.id,
        title: 'Hutang Listrik',
        principalAmount: 500000,
        dueDate: today.subtract(const Duration(days: 2)),
      );

      final paid = await harness.debts.create(
        groupId: group.id,
        title: 'Hutang Buku',
        principalAmount: 300000,
      );
      await harness.payments.create(debtId: paid.id, amount: 300000);

      final unassigned = await harness.debts.create(
        title: 'Hutang Pulsa',
        principalAmount: 200000,
      );

      await harness.pump(tester);

      expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
      expect(
        _metricText('dashboard-total-principal', 'Rp 2.000.000'),
        findsOneWidget,
      );
      expect(_metricText('dashboard-total-paid', 'Rp 700.000'), findsOneWidget);
      expect(
        _metricText('dashboard-total-outstanding', 'Rp 1.300.000'),
        findsOneWidget,
      );
      expect(_metricText('dashboard-count-active', '4'), findsOneWidget);
      expect(_metricText('dashboard-count-partial', '1'), findsOneWidget);
      expect(_metricText('dashboard-count-overdue', '1'), findsOneWidget);
      expect(_metricText('dashboard-count-paid', '1'), findsOneWidget);

      await _scrollUntilVisible(
        tester,
        find.byKey(Key('dashboard-group-${group.id}')),
      );
      expect(find.text('3 hutang • Rp 1.100.000 sisa'), findsOneWidget);

      await _scrollUntilVisible(
        tester,
        find.byKey(const Key('dashboard-group-unassigned')),
      );
      expect(find.text('1 hutang • Rp 200.000 sisa'), findsOneWidget);

      await _scrollUntilVisible(
        tester,
        find.byKey(Key('dashboard-upcoming-${partial.id}')),
      );
      expect(
        find.byKey(Key('dashboard-upcoming-${overdue.id}')),
        findsOneWidget,
      );
      expect(find.byKey(Key('dashboard-upcoming-${paid.id}')), findsNothing);
      expect(
        find.byKey(Key('dashboard-upcoming-${unassigned.id}')),
        findsNothing,
      );
    } finally {
      await harness.dispose(tester);
    }
  });
}
