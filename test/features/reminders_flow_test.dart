import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:debt_reminder/features/reminders/application/reminder_providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_admin_session_store.dart';
import '../support/fake_reminder_notification_gateway.dart';
import '../support/fake_reminder_preferences_repository.dart';

const AppConfig _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

DateTime _fixedNow() => DateTime.utc(2026, 11, 13, 10);

class _Harness {
  _Harness(this.database)
    : debts = DebtRepositoryImpl(database, now: _fixedNow);

  final AppDatabase database;
  final DebtRepositoryImpl debts;
  final FakeReminderPreferencesRepository preferences =
      FakeReminderPreferencesRepository();
  final FakeReminderNotificationGateway gateway =
      FakeReminderNotificationGateway();

  Future<void> pump(WidgetTester tester, {required bool unlocked}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            unlocked
                ? FakeAdminSessionStore.unlocked()
                : FakeAdminSessionStore(),
          ),
          reminderPreferencesRepositoryProvider.overrideWithValue(preferences),
          reminderNotificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReminders(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('drawer-item-/reminders')),
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
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  });

  testWidgets('admin dapat mengaktifkan dan menyimpan pengingat', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.debts.create(
        title: 'Hutang Motor',
        principalAmount: 1000000,
        dueDate: DateTime.utc(2027, 1, 10),
      );
      await harness.pump(tester, unlocked: true);
      await harness.openReminders(tester);

      expect(find.byKey(const Key('reminders-screen')), findsOneWidget);
      expect(find.byKey(const Key('reminder-enabled-switch')), findsOneWidget);
      expect(find.byKey(const Key('reminder-offset-3')), findsOneWidget);
      expect(find.byKey(const Key('reminder-offset-1')), findsOneWidget);
      expect(find.byKey(const Key('reminder-offset-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reminder-enabled-switch')));
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('reminder-save-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('pengingat berhasil dijadwalkan'),
        findsOneWidget,
      );
      expect(harness.gateway.scheduled, isNotEmpty);
      final saved = await harness.preferences.load();
      expect(saved.enabled, true);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('admin melihat penjelasan saat izin notifikasi belum ada', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      harness.gateway.notificationsEnabled = false;
      harness.gateway.exactAlarmsAllowed = false;
      await harness.pump(tester, unlocked: true);
      await harness.openReminders(tester);

      expect(find.text('Izin notifikasi belum diberikan.'), findsOneWidget);
      expect(
        find.byKey(const Key('reminder-notification-permission')),
        findsOneWidget,
      );
      expect(find.textContaining('Pengingat dapat tertunda'), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('public mode dapat mengatur reminder lokal', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    try {
      await harness.pump(tester, unlocked: false);
      await harness.openReminders(tester);

      expect(find.byKey(const Key('admin-locked-banner')), findsNothing);
      expect(find.byKey(const Key('reminder-enabled-switch')), findsOneWidget);
      expect(find.byKey(const Key('reminder-save-button')), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });
}
