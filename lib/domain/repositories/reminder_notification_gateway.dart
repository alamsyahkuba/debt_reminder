import '../entities/reminder.dart';

abstract interface class ReminderNotificationGateway {
  Future<ReminderCapability> capability();

  Future<bool> requestNotificationsPermission();

  Future<bool> requestExactAlarmsPermission();

  Future<void> refreshTimeZone();

  Future<void> cancelAll();

  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required bool exact,
  });

  Future<int> pendingCount();
}
