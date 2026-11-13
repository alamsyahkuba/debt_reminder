import 'package:debt_reminder/domain/entities/reminder.dart';
import 'package:debt_reminder/domain/repositories/reminder_notification_gateway.dart';

class FakeReminderNotificationGateway implements ReminderNotificationGateway {
  FakeReminderNotificationGateway({
    this.supported = true,
    this.notificationsEnabled = true,
    this.exactAlarmsAllowed = true,
  });

  bool supported;
  bool notificationsEnabled;
  bool exactAlarmsAllowed;
  int cancelAllCalls = 0;
  final List<
    ({int id, String title, String body, DateTime scheduledAt, bool exact})
  >
  scheduled = [];

  @override
  Future<ReminderCapability> capability() async {
    return ReminderCapability(
      supported: supported,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
  }

  @override
  Future<bool> requestNotificationsPermission() async => notificationsEnabled;

  @override
  Future<bool> requestExactAlarmsPermission() async => exactAlarmsAllowed;

  @override
  Future<void> refreshTimeZone() async {}

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
