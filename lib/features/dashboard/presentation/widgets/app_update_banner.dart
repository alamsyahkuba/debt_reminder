import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation.dart';
import '../../../settings/application/app_update_providers.dart';

class DashboardUpdateBanner extends ConsumerWidget {
  const DashboardUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final update = state.update;
    if (state.status != AppUpdateStatus.available || update == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        key: const Key('dashboard-update-banner'),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.system_update_outlined, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Update tersedia: ${update.versionName} '
                      '(build ${update.buildNumber})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (update.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        update.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      key: const Key('dashboard-update-open'),
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Lihat Update'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
