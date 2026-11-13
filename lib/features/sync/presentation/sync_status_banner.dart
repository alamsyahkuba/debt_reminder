import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../application/sync_providers.dart';

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.hasSupabaseConfig) {
      return const SizedBox.shrink();
    }

    final status = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, label, color) = _content(status, colors);

    return Container(
      key: const Key('sync-status-banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          status.isSyncing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          TextButton(
            key: const Key('sync-status-action'),
            onPressed: status.isSyncing
                ? null
                : () => context.push(AppRoutes.settings),
            child: const Text('Detail'),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _content(SyncStatus status, ColorScheme colors) {
    if (status.isSyncing) {
      return (Icons.sync, 'Menyinkronkan data...', colors.primary);
    }
    if (status.conflicts > 0 || status.failed > 0) {
      return (
        Icons.warning_amber_outlined,
        '${status.conflicts} konflik • ${status.failed} gagal',
        colors.error,
      );
    }
    if (status.pending > 0) {
      return (
        Icons.schedule,
        '${status.pending} perubahan menunggu sinkronisasi',
        colors.tertiary,
      );
    }
    final last = status.lastPublicPullAt;
    if (last != null) {
      return (
        Icons.cloud_done_outlined,
        'Tersinkron • ${formatDateTime(last)}',
        colors.primary,
      );
    }
    return (
      Icons.cloud_queue_outlined,
      'Belum pernah sinkronisasi',
      colors.onSurfaceVariant,
    );
  }
}
