import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_notification_gateway.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../local/app_database.dart';
import '../local/daos/debt_dao.dart';

class ReminderScheduler {
  ReminderScheduler({
    required AppDatabase database,
    required this.preferences,
    required this.gateway,
    DateTime Function()? now,
    this.location,
  }) : _debts = DebtDao(database),
       _now = now ?? (() => DateTime.now());

  final DebtDao _debts;
  final ReminderPreferencesRepository preferences;
  final ReminderNotificationGateway gateway;
  final DateTime Function() _now;
  final tz.Location? location;

  tz.Location get _zone => location ?? tz.local;

  Future<ReminderScheduleResult> reconcile() async {
    final currentPreferences = await preferences.load();
    if (!currentPreferences.enabled) {
      try {
        await gateway.cancelAll();
      } catch (_) {
        // Reminder permission can disappear at any time.
      }
      return ReminderScheduleResult(
        capability: ReminderCapability.unavailable,
        scheduled: const <ScheduledReminder>[],
        skippedPast: 0,
        disabled: true,
      );
    }

    try {
      await gateway.refreshTimeZone();
      final capability = await gateway.capability();
      if (!capability.canSchedule) {
        await gateway.cancelAll();
        return ReminderScheduleResult(
          capability: capability,
          scheduled: const <ScheduledReminder>[],
          skippedPast: 0,
          disabled: false,
          unavailableReason: capability.supported
              ? 'Izin notifikasi belum diberikan.'
              : 'Notifikasi tidak tersedia di perangkat ini.',
        );
      }

      final computed = await _computeSchedules(currentPreferences);
      await gateway.cancelAll();
      for (final reminder in computed.reminders) {
        await gateway.schedule(
          notificationId: reminder.notificationId,
          title: 'Pengingat: ${reminder.debtTitle}',
          body:
              '${_offsetLabel(reminder.offsetDays)} • '
              'Sisa ${formatRupiah(reminder.outstandingAmount)}. '
              'Notifikasi bukan bukti pembayaran.',
          scheduledAt: reminder.scheduledAt,
          exact: capability.exactAlarmsAllowed,
        );
      }

      return ReminderScheduleResult(
        capability: capability,
        scheduled: computed.reminders,
        skippedPast: computed.skippedPast,
        disabled: false,
      );
    } catch (_) {
      return ReminderScheduleResult(
        capability: ReminderCapability.unavailable,
        scheduled: const <ScheduledReminder>[],
        skippedPast: 0,
        disabled: false,
        unavailableReason:
            'Pengingat tidak dapat dijadwalkan di perangkat ini.',
      );
    }
  }

  Future<List<ScheduledReminder>> upcoming() async {
    final currentPreferences = await preferences.load();
    if (!currentPreferences.enabled) {
      return const <ScheduledReminder>[];
    }
    await gateway.refreshTimeZone();
    final computed = await _computeSchedules(currentPreferences);
    return computed.reminders;
  }

  Future<({List<ScheduledReminder> reminders, int skippedPast})>
  _computeSchedules(ReminderPreferences preferences) async {
    final overviews = await _debts.watchOverviews().first;
    final now = tz.TZDateTime.from(_now(), _zone);
    final reminders = <ScheduledReminder>[];
    var skippedPast = 0;

    for (final overview in overviews) {
      final dueDate = overview.debt.dueDate;
      if (dueDate == null) {
        continue;
      }
      final outstanding = overview.debt.principalAmount - overview.paidAmount;
      if (outstanding <= 0) {
        continue;
      }

      for (final offset in preferences.sortedOffsets) {
        final scheduledAt = tz.TZDateTime(
          _zone,
          dueDate.year,
          dueDate.month,
          dueDate.day - offset,
          preferences.hour,
          preferences.minute,
        );
        if (!scheduledAt.isAfter(now)) {
          skippedPast++;
          continue;
        }

        reminders.add(
          ScheduledReminder(
            notificationId: notificationId(overview.debt.id, offset),
            debtId: overview.debt.id,
            debtTitle: overview.debt.title,
            offsetDays: offset,
            scheduledAt: scheduledAt,
            outstandingAmount: outstanding,
          ),
        );
      }
    }

    reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return (reminders: reminders, skippedPast: skippedPast);
  }

  String _offsetLabel(int offset) {
    if (offset == 0) {
      return 'Jatuh tempo hari ini';
    }
    if (offset == 1) {
      return 'Jatuh tempo besok';
    }
    return 'Jatuh tempo H-$offset';
  }

  /// Stable positive 31-bit notification ID for a debt and offset.
  int notificationId(String debtId, int offset) {
    var hash = 0x811c9dc5;
    for (final codeUnit in '$debtId:$offset'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 1 + (hash % 0x7ffffffe);
  }
}
