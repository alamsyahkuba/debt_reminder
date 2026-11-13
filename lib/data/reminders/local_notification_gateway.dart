import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_notification_gateway.dart';

class LocalNotificationGateway implements ReminderNotificationGateway {
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'debt_due_reminders';
  static const String channelName = 'Pengingat Hutang';
  static const String channelDescription =
      'Pengingat jatuh tempo hutang yang tersimpan di perangkat.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<ReminderCapability> capability() async {
    if (!_isAndroid) {
      return ReminderCapability.unavailable;
    }

    try {
      await _ensureInitialized();
      final android = _androidPlugin;
      final notificationsEnabled =
          await android?.areNotificationsEnabled() ?? false;
      final exactAlarmsAllowed =
          await android?.canScheduleExactNotifications() ?? false;
      return ReminderCapability(
        supported: android != null,
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAlarmsAllowed,
      );
    } on MissingPluginException {
      return ReminderCapability.unavailable;
    } on PlatformException {
      return ReminderCapability.unavailable;
    }
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    await _ensureInitialized();
    return await _androidPlugin?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    await _ensureInitialized();
    return await _androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<void> refreshTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      // Fall back to the timezone package default (UTC) when the platform
      // timezone plugin is unavailable, for example in unit tests.
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required bool exact,
  }) async {
    await _ensureInitialized();
    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'debt_reminder',
    );
  }

  @override
  Future<int> pendingCount() async {
    try {
      await _ensureInitialized();
      return (await _plugin.pendingNotificationRequests()).length;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await refreshTimeZone();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    await _androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );
    _initialized = true;
  }
}
