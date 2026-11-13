import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../features/admin/application/admin_providers.dart';

/// Read-only notice shown in the app while no admin session is active.
class AdminLockedBanner extends ConsumerWidget {
  const AdminLockedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(adminUnlockedProvider)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      key: const Key('admin-locked-banner'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            size: 18,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode baca. Buka Admin untuk mengubah data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            key: const Key('admin-locked-banner-button'),
            onPressed: () => context.push(AppRoutes.adminFrom(location)),
            child: const Text('Buka Admin'),
          ),
        ],
      ),
    );
  }
}
