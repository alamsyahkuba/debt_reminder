import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_update_providers.dart';

class AppUpdateCard extends ConsumerWidget {
  const AppUpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(appUpdateControllerProvider);
    final version = ref.watch(appVersionProvider).value ?? state.current;

    return Card(
      key: const Key('app-update-card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.system_update_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Pembaruan aplikasi', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              version == null
                  ? 'Versi terpasang: memuat...'
                  : 'Versi terpasang: ${version.versionName} '
                        '(build ${version.buildNumber})',
              key: const Key('app-update-current-version'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildState(context, ref, state),
          ],
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    WidgetRef ref,
    AppUpdateState state,
  ) {
    final theme = Theme.of(context);
    final controller = ref.read(appUpdateControllerProvider.notifier);

    switch (state.status) {
      case AppUpdateStatus.idle:
        return _checkButton(controller);
      case AppUpdateStatus.checking:
        return const Row(
          children: <Widget>[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Memeriksa pembaruan...'),
          ],
        );
      case AppUpdateStatus.upToDate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Aplikasi sudah menggunakan versi terbaru.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _checkButton(controller),
          ],
        );
      case AppUpdateStatus.available:
        return _buildAvailable(context, ref, state, controller);
      case AppUpdateStatus.downloading:
        return _buildDownloading(context, state, controller);
      case AppUpdateStatus.readyToInstall:
        return _buildReadyToInstall(context, controller);
      case AppUpdateStatus.permissionRequired:
        return _buildPermissionRequired(context, controller);
      case AppUpdateStatus.installerOpened:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Installer Android sudah dibuka. Selesaikan pemasangan di '
              'layar sistem.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('app-update-check'),
              onPressed: controller.check,
              child: const Text('Cek lagi'),
            ),
          ],
        );
      case AppUpdateStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              state.error ?? 'Pembaruan tidak dapat diproses.',
              key: const Key('app-update-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const Key('app-update-retry'),
                  onPressed: controller.check,
                  child: const Text('Coba lagi'),
                ),
                if (state.file != null)
                  FilledButton(
                    key: const Key('app-update-install'),
                    onPressed: controller.installDownloaded,
                    child: const Text('Pasang update'),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildAvailable(
    BuildContext context,
    WidgetRef ref,
    AppUpdateState state,
    AppUpdateController controller,
  ) {
    final theme = Theme.of(context);
    final update = state.update!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Versi ${update.versionName} (build ${update.buildNumber}) tersedia.',
          key: const Key('app-update-available'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ukuran ${_formatBytes(update.apkSizeBytes)}',
          style: theme.textTheme.bodySmall,
        ),
        if (update.notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            update.notes,
            key: const Key('app-update-notes'),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('app-update-download'),
          onPressed: controller.downloadAndInstall,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download & Pasang'),
        ),
      ],
    );
  }

  Widget _buildDownloading(
    BuildContext context,
    AppUpdateState state,
    AppUpdateController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: state.progress),
        const SizedBox(height: 8),
        Text(
          state.totalBytes > 0
              ? 'Mengunduh ${_formatBytes(state.receivedBytes)} dari '
                    '${_formatBytes(state.totalBytes)}'
              : 'Mengunduh update...',
          key: const Key('app-update-progress'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('app-update-cancel'),
          onPressed: controller.cancelDownload,
          child: const Text('Batalkan'),
        ),
      ],
    );
  }

  Widget _buildReadyToInstall(
    BuildContext context,
    AppUpdateController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'APK sudah diunduh dan checksum-nya cocok.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('app-update-install'),
          onPressed: controller.installDownloaded,
          icon: const Icon(Icons.system_update_alt),
          label: const Text('Pasang update'),
        ),
      ],
    );
  }

  Widget _buildPermissionRequired(
    BuildContext context,
    AppUpdateController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Izinkan Debt Reminder memasang aplikasi dari sumber ini, lalu '
          'kembali untuk memasang update.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              key: const Key('app-update-permission'),
              onPressed: controller.openInstallPermissionSettings,
              child: const Text('Buka Pengaturan Izin'),
            ),
            FilledButton(
              key: const Key('app-update-install'),
              onPressed: controller.installDownloaded,
              child: const Text('Pasang update'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _checkButton(AppUpdateController controller) {
    return OutlinedButton.icon(
      key: const Key('app-update-check'),
      onPressed: controller.check,
      icon: const Icon(Icons.refresh),
      label: const Text('Cek Update'),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
