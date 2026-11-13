import '../entities/reminder.dart';

abstract interface class ReminderPreferencesRepository {
  Future<ReminderPreferences> load();

  Future<void> save(ReminderPreferences preferences);
}
