import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../../admin/application/admin_providers.dart';
import '../../sync/application/sync_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final status = ref.watch(syncStatusProvider);
    final run = ref.watch(syncRunControllerProvider);
    final conflicts =
        ref.watch(syncConflictsProvider).value ?? const <SyncQueueRow>[];
    final session = ref.watch(adminSessionControllerProvider).value;
    final isAdmin = session?.isValid ?? false;

    return Scaffold(
      key: const Key('settings-screen'),
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: <Widget>[
          const LocalDataNotice(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.cloud_sync_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sinkronisasi',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel(status, config.hasSupabaseConfig),
                      key: const Key('settings-sync-status'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _StatusChip(
                          keyValue: 'settings-sync-pending',
                          label: '${status.pending} menunggu',
                          icon: Icons.schedule,
                        ),
                        _StatusChip(
                          keyValue: 'settings-sync-conflicts',
                          label: '${status.conflicts} konflik',
                          icon: Icons.warning_amber_outlined,
                        ),
                        _StatusChip(
                          keyValue: 'settings-sync-failed',
                          label: '${status.failed} gagal',
                          icon: Icons.error_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _timestampLabel(
                        'Publik terakhir',
                        status.lastPublicPullAt,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _timestampLabel('Admin terakhir', status.lastAdminSyncAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (run.lastError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        run.lastError!,
                        key: const Key('settings-sync-error'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('settings-sync-now'),
                      onPressed: run.isSyncing || !config.hasSupabaseConfig
                          ? null
                          : () => ref
                                .read(syncRunControllerProvider.notifier)
                                .syncNow(fullPull: true),
                      icon: run.isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        run.isSyncing
                            ? 'Menyinkronkan...'
                            : 'Sinkronkan Sekarang',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAdmin
                          ? 'Perubahan lokal akan dikirim dengan sesi admin aktif.'
                          : 'Data publik tetap diperbarui. Buka Admin untuk mengirim perubahan lokal.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (conflicts.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Konflik sinkronisasi',
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final conflict in conflicts)
              _ConflictCard(
                key: Key('conflict-tile-${conflict.operationId}'),
                conflict: conflict,
                onReload: run.isSyncing
                    ? null
                    : () => ref
                          .read(syncRunControllerProvider.notifier)
                          .resolveConflictReload(conflict.operationId),
                onKeepLocal: run.isSyncing
                    ? null
                    : () => ref
                          .read(syncRunControllerProvider.notifier)
                          .resolveConflictKeepLocal(conflict.operationId),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Card(
              child: ListTile(
                leading: Icon(
                  isAdmin ? Icons.verified_user_outlined : Icons.lock_outline,
                ),
                title: Text(isAdmin ? 'Admin aktif' : 'Mode baca'),
                subtitle: Text(
                  isAdmin
                      ? 'Sesi admin terverifikasi server.'
                      : 'Buka Admin untuk mengubah data.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.admin),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(SyncStatus status, bool configured) {
    if (!configured) {
      return 'Supabase belum dikonfigurasi. Data lokal tetap dapat dibaca.';
    }
    if (status.isSyncing) {
      return 'Menyinkronkan data...';
    }
    if (status.hasIssues) {
      return 'Sebagian operasi membutuhkan perhatian.';
    }
    if (status.pending > 0) {
      return '${status.pending} perubahan menunggu sinkronisasi.';
    }
    return 'Data lokal sudah tersinkron.';
  }

  String _timestampLabel(String label, DateTime? value) {
    if (value == null) {
      return '$label: belum pernah';
    }
    return '$label: ${formatDateTime(value)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.keyValue,
    required this.label,
    required this.icon,
  });

  final String keyValue;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: Key(keyValue),
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.onReload,
    required this.onKeepLocal,
    super.key,
  });

  final SyncQueueRow conflict;
  final VoidCallback? onReload;
  final VoidCallback? onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = _conflictMessage(conflict.conflictData);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${conflict.entityType} • ${conflict.operation}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              payload,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: Key('conflict-reload-${conflict.operationId}'),
                  onPressed: onReload,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Muat ulang server'),
                ),
                FilledButton.icon(
                  key: Key('conflict-keep-${conflict.operationId}'),
                  onPressed: onKeepLocal,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Pertahankan lokal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _conflictMessage(String? data) {
    if (data == null || data.isEmpty) {
      return 'Data berubah di server. Pilih tindakan.';
    }
    return 'Data berubah di server. Muat ulang snapshot server atau kirim '
        'perubahan lokal dengan versi terbaru.';
  }
}
