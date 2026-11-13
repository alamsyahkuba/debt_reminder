final class ReminderPreferences {
  const ReminderPreferences({
    required this.enabled,
    required this.offsets,
    required this.hour,
    required this.minute,
  });

  static const Set<int> defaultOffsets = <int>{3, 1, 0};

  static const ReminderPreferences defaults = ReminderPreferences(
    enabled: false,
    offsets: defaultOffsets,
    hour: 9,
    minute: 0,
  );

  final bool enabled;
  final Set<int> offsets;
  final int hour;
  final int minute;

  List<int> get sortedOffsets {
    final values = offsets.toList(growable: false)..sort();
    return values;
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderPreferences copyWith({
    bool? enabled,
    Set<int>? offsets,
    int? hour,
    int? minute,
  }) {
    return ReminderPreferences(
      enabled: enabled ?? this.enabled,
      offsets: offsets ?? this.offsets,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderPreferences &&
        other.enabled == enabled &&
        other.hour == hour &&
        other.minute == minute &&
        other.offsets.length == offsets.length &&
        other.offsets.containsAll(offsets);
  }

  @override
  int get hashCode =>
      Object.hash(enabled, Object.hashAll(sortedOffsets), hour, minute);
}

final class ReminderCapability {
  const ReminderCapability({
    required this.supported,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
  });

  static const ReminderCapability unavailable = ReminderCapability(
    supported: false,
    notificationsEnabled: false,
    exactAlarmsAllowed: false,
  );

  final bool supported;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;

  bool get canSchedule => supported && notificationsEnabled;
}

final class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.debtId,
    required this.debtTitle,
    required this.offsetDays,
    required this.scheduledAt,
    required this.outstandingAmount,
  });

  final int notificationId;
  final String debtId;
  final String debtTitle;
  final int offsetDays;
  final DateTime scheduledAt;
  final int outstandingAmount;
}

final class ReminderScheduleResult {
  const ReminderScheduleResult({
    required this.capability,
    required this.scheduled,
    required this.skippedPast,
    required this.disabled,
    this.unavailableReason,
  });

  final ReminderCapability capability;
  final List<ScheduledReminder> scheduled;
  final int skippedPast;
  final bool disabled;
  final String? unavailableReason;
}
