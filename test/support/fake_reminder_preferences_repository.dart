import 'package:debt_reminder/domain/entities/reminder.dart';
import 'package:debt_reminder/domain/repositories/reminder_preferences_repository.dart';

class FakeReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  FakeReminderPreferencesRepository({
    ReminderPreferences initial = ReminderPreferences.defaults,
  }) : _value = initial;

  ReminderPreferences _value;

  @override
  Future<ReminderPreferences> load() async => _value;

  @override
  Future<void> save(ReminderPreferences preferences) async {
    _value = preferences;
  }
}
