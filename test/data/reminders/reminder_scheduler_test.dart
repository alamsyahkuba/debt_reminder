import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/local/daos/local_settings_dao.dart';
import 'package:debt_reminder/data/reminders/reminder_scheduler.dart';
import 'package:debt_reminder/data/repositories/debt_repository_impl.dart';
import 'package:debt_reminder/data/repositories/payment_repository_impl.dart';
import 'package:debt_reminder/data/repositories/reminder_preferences_repository_impl.dart';
import 'package:debt_reminder/domain/entities/reminder.dart';
import 'package:debt_reminder/domain/repositories/reminder_notification_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

DateTime _fixedNow() => DateTime.utc(2026, 11, 13, 0);
tz.Location _jakarta() => tz.getLocation('Asia/Jakarta');
tz.Location _utc() => tz.UTC;

class _FakeGateway implements ReminderNotificationGateway {
  _FakeGateway({
    this.notificationsEnabled = true,
    this.exactAlarmsAllowed = true,
  });

  bool notificationsEnabled;
  bool exactAlarmsAllowed;
  int cancelAllCalls = 0;
  int timezoneRefreshes = 0;
  final List<
    ({int id, String title, String body, DateTime scheduledAt, bool exact})
  >
  scheduled = [];

  @override
  Future<ReminderCapability> capability() async {
    return ReminderCapability(
      supported: true,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
  }

  @override
  Future<bool> requestNotificationsPermission() async => notificationsEnabled;

  @override
  Future<bool> requestExactAlarmsPermission() async => exactAlarmsAllowed;

  @override
  Future<void> refreshTimeZone() async {
    timezoneRefreshes++;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required bool exact,
  }) async {
    scheduled.add((
      id: notificationId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      exact: exact,
    ));
  }

  @override
  Future<int> pendingCount() async => scheduled.length;
}

void main() {
  late AppDatabase database;
  late LocalReminderPreferencesRepository preferences;
  late DebtRepositoryImpl debts;
  late PaymentRepositoryImpl payments;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(_jakarta());
  });

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    preferences = LocalReminderPreferencesRepository(
      settings: LocalSettingsDao(database),
      now: _fixedNow,
    );
    debts = DebtRepositoryImpl(database, now: _fixedNow);
    payments = PaymentRepositoryImpl(database, now: _fixedNow);
  });

  tearDown(() async {
    await database.close();
  });

  Future<ReminderPreferences> enabledPreferences({
    Set<int> offsets = const <int>{3, 1, 0},
    int hour = 9,
  }) async {
    final value = ReminderPreferences(
      enabled: true,
      offsets: offsets,
      hour: hour,
      minute: 0,
    );
    await preferences.save(value);
    return value;
  }

  test('preferences default disabled dan roundtrip tersimpan lokal', () async {
    final defaults = await preferences.load();
    expect(defaults.enabled, false);
    expect(defaults.offsets, <int>{3, 1, 0});
    expect(defaults.timeLabel, '09:00');

    await preferences.save(
      const ReminderPreferences(
        enabled: true,
        offsets: <int>{3, 0},
        hour: 7,
        minute: 30,
      ),
    );
    final loaded = await preferences.load();
    expect(loaded.enabled, true);
    expect(loaded.offsets, <int>{3, 0});
    expect(loaded.timeLabel, '07:30');
  });

  test('scheduler membuat pengingat H-3, H-1, dan H', () async {
    await enabledPreferences();
    final debt = await debts.create(
      title: 'Hutang Motor',
      principalAmount: 1000000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    final gateway = _FakeGateway();
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: gateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _jakarta(),
    );

    final result = await scheduler.reconcile();

    expect(result.scheduled, hasLength(3));
    expect(result.skippedPast, 0);
    expect(gateway.cancelAllCalls, 1);
    expect(gateway.scheduled, hasLength(3));
    expect(gateway.scheduled.every((item) => item.exact), true);
    expect(gateway.scheduled.first.body, contains('Sisa Rp 1.000.000'));
    expect(
      gateway.scheduled.first.scheduledAt.toUtc(),
      DateTime.utc(2026, 11, 17, 2),
    );
    expect(
      gateway.scheduled.last.scheduledAt.toUtc(),
      DateTime.utc(2026, 11, 20, 2),
    );
    expect(gateway.scheduled.map((item) => item.id).toSet(), hasLength(3));
    expect(
      gateway.scheduled.any((item) => item.title.contains(debt.title)),
      true,
    );
  });

  test('pengingat yang sudah lewat dilewati', () async {
    await enabledPreferences();
    await debts.create(
      title: 'Hutang Listrik',
      principalAmount: 500000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    final gateway = _FakeGateway();
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: gateway,
      now: () => tz.TZDateTime(_jakarta(), 2026, 11, 19, 10),
      location: _jakarta(),
    );

    final result = await scheduler.reconcile();

    expect(result.scheduled, hasLength(1));
    expect(result.skippedPast, 2);
    expect(gateway.scheduled.single.scheduledAt.day, 20);
  });

  test('perubahan due date mengganti jadwal pengingat', () async {
    await enabledPreferences(offsets: const <int>{0});
    final original = await debts.create(
      title: 'Hutang Pindah',
      principalAmount: 100000,
      dueDate: DateTime.utc(2027, 1, 10),
    );
    final gateway = _FakeGateway();
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: gateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _jakarta(),
    );

    await scheduler.reconcile();
    final firstSchedule = gateway.scheduled.single.scheduledAt.toUtc();

    await debts.update(
      id: original.id,
      expectedVersion: original.version,
      title: original.title,
      principalAmount: original.principalAmount,
      dueDate: DateTime.utc(2027, 2, 10),
    );
    gateway.scheduled.clear();
    await scheduler.reconcile();

    expect(gateway.cancelAllCalls, 2);
    expect(gateway.scheduled.single.scheduledAt.toUtc(), isNot(firstSchedule));
    expect(gateway.scheduled.single.scheduledAt.month, 2);
  });

  test('hutang lunas dan arsip tidak dijadwalkan', () async {
    await enabledPreferences();
    final paid = await debts.create(
      title: 'Lunas',
      principalAmount: 100000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    await payments.create(debtId: paid.id, amount: 100000);
    final archived = await debts.create(
      title: 'Arsip',
      principalAmount: 100000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    await debts.setArchived(
      id: archived.id,
      expectedVersion: archived.version,
      isArchived: true,
    );

    final gateway = _FakeGateway();
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: gateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _jakarta(),
    );
    final result = await scheduler.reconcile();

    expect(result.scheduled, isEmpty);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'preferensi disabled membatalkan jadwal dan tidak menjadwalkan',
    () async {
      final gateway = _FakeGateway();
      final scheduler = ReminderScheduler(
        database: database,
        preferences: preferences,
        gateway: gateway,
        now: () => DateTime.utc(2026, 11, 13, 2),
        location: _jakarta(),
      );

      final result = await scheduler.reconcile();

      expect(result.disabled, true);
      expect(gateway.cancelAllCalls, 1);
      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'izin notifikasi ditolak tidak menjadwalkan dan memberi alasan',
    () async {
      await enabledPreferences();
      await debts.create(
        title: 'Hutang Sekolah',
        principalAmount: 300000,
        dueDate: DateTime.utc(2026, 11, 20),
      );
      final gateway = _FakeGateway(notificationsEnabled: false);
      final scheduler = ReminderScheduler(
        database: database,
        preferences: preferences,
        gateway: gateway,
        now: () => DateTime.utc(2026, 11, 13, 2),
        location: _jakarta(),
      );

      final result = await scheduler.reconcile();

      expect(result.scheduled, isEmpty);
      expect(result.unavailableReason, contains('Izin notifikasi'));
      expect(gateway.scheduled, isEmpty);
    },
  );

  test('perubahan timezone mengubah instant UTC pengingat', () async {
    await enabledPreferences(offsets: const <int>{0});
    await debts.create(
      title: 'Hutang Pulsa',
      principalAmount: 100000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    final jakartaGateway = _FakeGateway();
    final jakartaScheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: jakartaGateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _jakarta(),
    );
    final utcGateway = _FakeGateway();
    final utcScheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: utcGateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _utc(),
    );

    await jakartaScheduler.reconcile();
    await utcScheduler.reconcile();

    expect(
      jakartaGateway.scheduled.single.scheduledAt.toUtc(),
      DateTime.utc(2026, 11, 20, 2),
    );
    expect(
      utcGateway.scheduled.single.scheduledAt.toUtc(),
      DateTime.utc(2026, 11, 20, 9),
    );
  });

  test('alarm tepat waktu tidak diizinkan memakai fallback inexact', () async {
    await enabledPreferences(offsets: const <int>{0});
    await debts.create(
      title: 'Hutang Fallback',
      principalAmount: 100000,
      dueDate: DateTime.utc(2026, 11, 20),
    );
    final gateway = _FakeGateway(exactAlarmsAllowed: false);
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: gateway,
      now: () => DateTime.utc(2026, 11, 13, 2),
      location: _jakarta(),
    );

    final result = await scheduler.reconcile();

    expect(result.capability.exactAlarmsAllowed, false);
    expect(gateway.scheduled.single.exact, false);
  });

  test('notification id stabil dan tidak bergantung pada waktu', () {
    final scheduler = ReminderScheduler(
      database: database,
      preferences: preferences,
      gateway: _FakeGateway(),
      location: _jakarta(),
    );
    final first = scheduler.notificationId('debt-1', 3);
    final second = scheduler.notificationId('debt-1', 3);
    expect(first, second);
    expect(first, greaterThan(0));
  });
}
