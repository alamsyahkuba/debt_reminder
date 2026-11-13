import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/daos/local_settings_dao.dart';
import '../../../data/reminders/local_notification_gateway.dart';
import '../../../data/reminders/reminder_scheduler.dart';
import '../../../data/repositories/reminder_preferences_repository_impl.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/repositories/reminder_notification_gateway.dart';
import '../../../domain/repositories/reminder_preferences_repository.dart';
import '../../debts/application/debt_providers.dart';

final localSettingsDaoProvider = Provider<LocalSettingsDao>((ref) {
  return LocalSettingsDao(ref.watch(appDatabaseProvider));
});

final reminderPreferencesRepositoryProvider =
    Provider<ReminderPreferencesRepository>((ref) {
      return LocalReminderPreferencesRepository(
        settings: ref.watch(localSettingsDaoProvider),
      );
    });

final reminderNotificationGatewayProvider =
    Provider<ReminderNotificationGateway>((ref) {
      return LocalNotificationGateway();
    });

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    database: ref.watch(appDatabaseProvider),
    preferences: ref.watch(reminderPreferencesRepositoryProvider),
    gateway: ref.watch(reminderNotificationGatewayProvider),
  );
});

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderPreferences>(
      ReminderController.new,
    );

final reminderCapabilityProvider = FutureProvider<ReminderCapability>((ref) {
  return ref.watch(reminderNotificationGatewayProvider).capability();
});

final reminderUpcomingProvider = FutureProvider<List<ScheduledReminder>>((
  ref,
) async {
  ref.watch(debtOverviewsProvider(false));
  ref.watch(reminderControllerProvider);
  return ref.watch(reminderSchedulerProvider).upcoming();
});

class ReminderController extends AsyncNotifier<ReminderPreferences> {
  @override
  Future<ReminderPreferences> build() {
    return ref.watch(reminderPreferencesRepositoryProvider).load();
  }

  Future<ReminderScheduleResult> save(ReminderPreferences preferences) async {
    await ref.read(reminderPreferencesRepositoryProvider).save(preferences);
    state = AsyncData(preferences);
    return ref.read(reminderSchedulerProvider).reconcile();
  }

  Future<ReminderScheduleResult> reschedule() async {
    return ref.read(reminderSchedulerProvider).reconcile();
  }
}
