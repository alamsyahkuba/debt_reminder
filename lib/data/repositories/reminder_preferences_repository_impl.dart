import 'dart:convert';

import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../local/daos/local_settings_dao.dart';

class LocalReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  LocalReminderPreferencesRepository({
    required this.settings,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  static const String enabledKey = 'reminder_enabled';
  static const String offsetsKey = 'reminder_offsets';
  static const String timeKey = 'reminder_time';

  final LocalSettingsDao settings;
  final DateTime Function() _now;

  @override
  Future<ReminderPreferences> load() async {
    final enabled = await settings.getValue(enabledKey) == 'true';
    final offsets = _decodeOffsets(await settings.getValue(offsetsKey));
    final time = _decodeTime(await settings.getValue(timeKey));

    return ReminderPreferences(
      enabled: enabled,
      offsets: offsets,
      hour: time.$1,
      minute: time.$2,
    );
  }

  @override
  Future<void> save(ReminderPreferences preferences) async {
    final now = _now().toUtc();
    final offsets = preferences.sortedOffsets;
    await settings.setValue(
      key: enabledKey,
      value: preferences.enabled.toString(),
      updatedAt: now,
    );
    await settings.setValue(
      key: offsetsKey,
      value: jsonEncode(offsets),
      updatedAt: now,
    );
    await settings.setValue(
      key: timeKey,
      value: preferences.timeLabel,
      updatedAt: now,
    );
  }

  Set<int> _decodeOffsets(String? value) {
    if (value == null || value.isEmpty) {
      return ReminderPreferences.defaultOffsets;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return ReminderPreferences.defaultOffsets;
      }
      final offsets = decoded
          .whereType<num>()
          .map((item) => item.toInt())
          .where((item) => item >= 0 && item <= 30)
          .toSet();
      return offsets.isEmpty ? ReminderPreferences.defaultOffsets : offsets;
    } catch (_) {
      return ReminderPreferences.defaultOffsets;
    }
  }

  (int, int) _decodeTime(String? value) {
    if (value == null) {
      return (9, 0);
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return (9, 0);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return (9, 0);
    }
    return (hour, minute);
  }
}
