import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String debts = '/debts';
  static const String groups = '/groups';
  static const String reminders = '/reminders';
  static const String settings = '/settings';
  static const String admin = '/admin';

  static const String groupNew = '/groups/new';
  static String groupDetail(String id) => '/groups/$id';
  static String groupEdit(String id) => '/groups/$id/edit';

  static const String debtNew = '/debts/new';
  static String debtDetail(String id) => '/debts/$id';
  static String debtEdit(String id) => '/debts/$id/edit';
  static String paymentNew(String debtId) => '/debts/$debtId/payments/new';
}

@immutable
final class AppDestination {
  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const AppDestination dashboardDestination = AppDestination(
  path: AppRoutes.dashboard,
  label: 'Dashboard',
  icon: Icons.space_dashboard_outlined,
  selectedIcon: Icons.space_dashboard,
);

const AppDestination debtsDestination = AppDestination(
  path: AppRoutes.debts,
  label: 'Semua Hutang',
  icon: Icons.receipt_long_outlined,
  selectedIcon: Icons.receipt_long,
);

const AppDestination groupsDestination = AppDestination(
  path: AppRoutes.groups,
  label: 'Group Hutang',
  icon: Icons.folder_outlined,
  selectedIcon: Icons.folder,
);

const AppDestination remindersDestination = AppDestination(
  path: AppRoutes.reminders,
  label: 'Reminder',
  icon: Icons.notifications_none,
  selectedIcon: Icons.notifications,
);

const AppDestination settingsDestination = AppDestination(
  path: AppRoutes.settings,
  label: 'Pengaturan',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
);

const AppDestination adminDestination = AppDestination(
  path: AppRoutes.admin,
  label: 'Admin',
  icon: Icons.admin_panel_settings_outlined,
  selectedIcon: Icons.admin_panel_settings,
);

const List<AppDestination> primaryDestinations = <AppDestination>[
  dashboardDestination,
  debtsDestination,
  groupsDestination,
  remindersDestination,
  settingsDestination,
];

const List<AppDestination> allDestinations = <AppDestination>[
  ...primaryDestinations,
  adminDestination,
];

AppDestination destinationForPath(String path) {
  return allDestinations.firstWhere(
    (destination) =>
        path == destination.path || path.startsWith('${destination.path}/'),
    orElse: () => dashboardDestination,
  );
}
