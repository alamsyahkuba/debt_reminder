import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/navigation.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/domain/entities/debt_group.dart';
import 'package:debt_reminder/domain/entities/group_summary.dart';
import 'package:debt_reminder/features/debt_groups/application/group_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const AppConfig _testConfig = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        groupListProvider.overrideWith(
          (ref, includeArchived) => Stream<List<DebtGroup>>.value(const []),
        ),
        groupSummariesProvider.overrideWith(
          (ref) => Stream<Map<String, GroupSummary>>.value(const {}),
        ),
      ],
      child: const DebtReminderApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

Future<void> _tapDrawerItem(WidgetTester tester, String path) async {
  final Finder finder = find.byKey(ValueKey<String>('drawer-item-$path'));

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan dashboard sebagai halaman awal', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('drawer menavigasi ke seluruh menu utama', (tester) async {
    await _pumpApp(tester);

    const destinations = <String, Key>{
      AppRoutes.debts: Key('debts-screen'),
      AppRoutes.groups: Key('groups-screen'),
      AppRoutes.reminders: Key('reminders-screen'),
      AppRoutes.settings: Key('settings-screen'),
      AppRoutes.admin: Key('admin-pin-screen'),
      AppRoutes.dashboard: Key('dashboard-screen'),
    };

    for (final entry in destinations.entries) {
      await _openDrawer(tester);
      await _tapDrawerItem(tester, entry.key);

      expect(find.byKey(entry.value), findsOneWidget);
    }
  });

  testWidgets('rute tidak dikenal menampilkan halaman error', (tester) async {
    await _pumpApp(tester);

    final BuildContext context = tester.element(
      find.byKey(const Key('dashboard-screen')),
    );
    GoRouter.of(context).go('/halaman-tidak-ada');
    await tester.pumpAndSettle();

    expect(find.text('Halaman tidak ditemukan'), findsOneWidget);
    expect(find.text('Kembali ke Dashboard'), findsOneWidget);
  });
}
