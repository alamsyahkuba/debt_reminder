import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'navigation.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.currentPath, super.key});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final selectedDestination = destinationForPath(currentPath);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            const _DrawerHeader(),
            for (final destination in primaryDestinations)
              _DrawerDestinationTile(
                destination: destination,
                isSelected: selectedDestination.path == destination.path,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(),
            ),
            _DrawerDestinationTile(
              destination: adminDestination,
              isSelected: selectedDestination.path == adminDestination.path,
              subtitle: 'Perlu PIN',
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset('assets/branding/logo.jpg', fit: BoxFit.contain),
          ),
          const SizedBox(height: 14),
          Text(
            'Debt Reminder',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kelola hutang dengan rapi',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.destination,
    required this.isSelected,
    this.subtitle,
  });

  final AppDestination destination;
  final bool isSelected;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey<String>('drawer-item-${destination.path}'),
      leading: Icon(isSelected ? destination.selectedIcon : destination.icon),
      title: Text(destination.label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      selected: isSelected,
      onTap: () {
        Navigator.of(context).pop();
        if (!isSelected) {
          context.go(destination.path);
        }
      },
    );
  }
}
