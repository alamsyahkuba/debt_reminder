import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/reminder.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../application/reminder_providers.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  ReminderPreferences? _draft;
  bool _initialized = false;
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(reminderControllerProvider);
    final capability = ref.watch(reminderCapabilityProvider);

    final preferences = preferencesAsync.value;
    if (!_initialized && preferences != null) {
      _draft = preferences;
      _initialized = true;
    }

    return Scaffold(
      key: const Key('reminders-screen'),
      backgroundColor: Colors.transparent,
      body: preferencesAsync.when(
        loading: () => const LoadingState(label: 'Memuat pengingat...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Preferensi pengingat tidak dapat dimuat.',
          onRetry: () => ref.invalidate(reminderControllerProvider),
        ),
        data: (stored) {
          final current = _draft ?? stored;
          return ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: <Widget>[
              const LocalDataNotice(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Pengingat jatuh tempo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              _buildReminderSettings(context, current, capability),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReminderSettings(
    BuildContext context,
    ReminderPreferences preferences,
    AsyncValue<ReminderCapability> capability,
  ) {
    final theme = Theme.of(context);
    final hasOffset = preferences.offsets.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  key: const Key('reminder-enabled-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan pengingat'),
                  subtitle: const Text(
                    'Pengingat lokal tetap bekerja tanpa internet.',
                  ),
                  value: preferences.enabled,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _draft = preferences.copyWith(enabled: value);
                          _message = null;
                        }),
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Waktu pengingat'),
                ),
                ListTile(
                  key: const Key('reminder-time-button'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(preferences.timeLabel),
                  subtitle: const Text('Waktu lokal perangkat'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _busy ? null : () => _pickTime(preferences),
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Hari sebelum jatuh tempo'),
                ),
                for (final offset in <int>[0, 1, 3])
                  CheckboxListTile(
                    key: Key('reminder-offset-$offset'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_offsetOptionLabel(offset)),
                    value: preferences.offsets.contains(offset),
                    onChanged: _busy
                        ? null
                        : (selected) {
                            final offsets = Set<int>.from(preferences.offsets);
                            if (selected == true) {
                              offsets.add(offset);
                            } else {
                              offsets.remove(offset);
                            }
                            setState(() {
                              _draft = preferences.copyWith(offsets: offsets);
                              _message = null;
                            });
                          },
                  ),
                if (preferences.enabled && !hasOffset)
                  Text(
                    'Pilih minimal satu hari pengingat.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('reminder-save-button'),
                    onPressed: _busy ? null : () => _save(preferences),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_busy ? 'Menyimpan...' : 'Simpan & Jadwalkan'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Notifikasi adalah pengingat, bukan bukti pembayaran. '
                  'Catat pembayaran setelah transaksi benar-benar terjadi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _message!,
              key: const Key('reminder-message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        _buildPermissionCard(context, capability),
        _buildUpcomingSection(context),
      ],
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    AsyncValue<ReminderCapability> capabilityAsync,
  ) {
    final theme = Theme.of(context);
    final capability = capabilityAsync.value;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Izin perangkat', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (capability == null)
              const LinearProgressIndicator()
            else if (!capability.supported)
              Text(
                'Notifikasi tidak tersedia di perangkat ini.',
                key: const Key('reminder-capability-unavailable'),
                style: theme.textTheme.bodySmall,
              )
            else ...<Widget>[
              Text(
                capability.notificationsEnabled
                    ? 'Izin notifikasi aktif.'
                    : 'Izin notifikasi belum diberikan.',
                key: const Key('reminder-notification-status'),
                style: theme.textTheme.bodySmall,
              ),
              if (!capability.notificationsEnabled)
                TextButton.icon(
                  key: const Key('reminder-notification-permission'),
                  onPressed: _busy ? null : _requestNotificationPermission,
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Izinkan Notifikasi'),
                ),
              const Divider(),
              Text(
                capability.exactAlarmsAllowed
                    ? 'Alarm tepat waktu aktif.'
                    : 'Alarm tepat waktu belum diizinkan. Pengingat dapat '
                          'tertunda beberapa menit.',
                key: const Key('reminder-exact-status'),
                style: theme.textTheme.bodySmall,
              ),
              if (!capability.exactAlarmsAllowed)
                TextButton.icon(
                  key: const Key('reminder-exact-permission'),
                  onPressed: _busy ? null : _requestExactPermission,
                  icon: const Icon(Icons.alarm),
                  label: const Text('Izinkan Alarm Tepat Waktu'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context) {
    final upcoming = ref.watch(reminderUpcomingProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Jadwal pengingat',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('reminder-reschedule-button'),
                onPressed: _busy ? null : _reschedule,
                child: const Text('Jadwalkan ulang'),
              ),
            ],
          ),
        ),
        upcoming.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Jadwal pengingat tidak dapat dihitung.'),
          ),
          data: (items) {
            if (!(_draft?.enabled ?? false)) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aktifkan pengingat untuk melihat jadwal.'),
              );
            }
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tidak ada pengingat mendatang. Tanggal mungkin sudah lewat '
                  'atau semua hutang lunas/diarsipkan.',
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final item in items.take(12))
                  Card(
                    key: Key(
                      'reminder-upcoming-${item.debtId}-${item.offsetDays}',
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: Text(item.debtTitle),
                      subtitle: Text(
                        '${formatDateTime(item.scheduledAt)} • '
                        '${_offsetOptionLabel(item.offsetDays)}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickTime(ReminderPreferences preferences) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.hour,
        minute: preferences.minute,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _draft = preferences.copyWith(
          hour: selected.hour,
          minute: selected.minute,
        );
        _message = null;
      });
    }
  }

  Future<void> _save(ReminderPreferences preferences) async {
    if (preferences.enabled && preferences.offsets.isEmpty) {
      setState(() => _message = 'Pilih minimal satu hari pengingat.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final result = await ref
          .read(reminderControllerProvider.notifier)
          .save(preferences);
      if (!mounted) {
        return;
      }
      ref.invalidate(reminderCapabilityProvider);
      ref.invalidate(reminderUpcomingProvider);
      setState(() => _message = _resultMessage(result));
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Preferensi pengingat tidak dapat disimpan.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reschedule() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(reminderControllerProvider.notifier)
          .reschedule();
      if (!mounted) {
        return;
      }
      ref.invalidate(reminderCapabilityProvider);
      ref.invalidate(reminderUpcomingProvider);
      setState(() => _message = _resultMessage(result));
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Jadwal pengingat tidak dapat diperbarui.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await ref
          .read(reminderNotificationGatewayProvider)
          .requestNotificationsPermission();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Izin notifikasi tidak dapat diminta dari perangkat ini.',
        );
      }
    } finally {
      ref.invalidate(reminderCapabilityProvider);
    }
  }

  Future<void> _requestExactPermission() async {
    try {
      await ref
          .read(reminderNotificationGatewayProvider)
          .requestExactAlarmsPermission();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Izin alarm tepat waktu tidak dapat diminta dari perangkat ini.',
        );
      }
    } finally {
      ref.invalidate(reminderCapabilityProvider);
    }
  }

  String _resultMessage(ReminderScheduleResult result) {
    if (result.disabled) {
      return 'Pengingat dinonaktifkan.';
    }
    if (result.unavailableReason != null) {
      return result.unavailableReason!;
    }
    if (result.scheduled.isEmpty) {
      return 'Tidak ada pengingat baru yang perlu dijadwalkan.';
    }
    return '${result.scheduled.length} pengingat berhasil dijadwalkan.';
  }

  String _offsetOptionLabel(int offset) {
    if (offset == 0) {
      return 'Hari H';
    }
    return 'H-$offset';
  }
}
