import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/application/admin_providers.dart';
import '../features/admin/presentation/admin_pin_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/debt_groups/presentation/group_detail_screen.dart';
import '../features/debt_groups/presentation/group_form_screen.dart';
import '../features/debt_groups/presentation/groups_screen.dart';
import '../features/debts/presentation/bulk_debt_form_screen.dart';
import '../features/debts/presentation/debt_detail_screen.dart';
import '../features/debts/presentation/debt_form_screen.dart';
import '../features/debts/presentation/debts_screen.dart';
import '../features/payments/presentation/payment_form_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';
import 'error_screen.dart';
import 'navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(adminSessionControllerProvider, (previous, next) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return createAppRouter(
    isAdminUnlocked: () => ref.read(adminUnlockedProvider),
    refreshListenable: refresh,
  );
});

GoRouter createAppRouter({
  required bool Function() isAdminUnlocked,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (_isAdminOnlyPath(state.uri) && !isAdminUnlocked()) {
        return AppRoutes.adminFrom(state.uri.toString());
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),
      GoRoute(
        path: AppRoutes.debtNew,
        builder: (context, state) => const DebtFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.debtBulk,
        builder: (context, state) => const BulkDebtFormScreen(),
      ),
      GoRoute(
        path: '/debts/:debtId',
        builder: (context, state) =>
            DebtDetailScreen(debtId: state.pathParameters['debtId']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                DebtFormScreen(debtId: state.pathParameters['debtId']!),
          ),
          GoRoute(
            path: 'payments/new',
            builder: (context, state) =>
                PaymentFormScreen(debtId: state.pathParameters['debtId']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.groupNew,
        builder: (context, state) => const GroupFormScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) =>
            GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                GroupFormScreen(groupId: state.pathParameters['groupId']!),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.debts,
            builder: (context, state) => const DebtsScreen(),
          ),
          GoRoute(
            path: AppRoutes.groups,
            builder: (context, state) => const GroupsScreen(),
          ),
          GoRoute(
            path: AppRoutes.reminders,
            builder: (context, state) => const RemindersScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.admin,
            builder: (context, state) => const AdminPinScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const AppErrorScreen(),
  );
}

bool _isAdminOnlyPath(Uri uri) {
  final segments = uri.pathSegments;

  if (segments.length == 2) {
    return (segments[0] == 'groups' && segments[1] == 'new') ||
        (segments[0] == 'debts' &&
            (segments[1] == 'new' || segments[1] == 'bulk'));
  }

  if (segments.length == 3) {
    return (segments[0] == 'groups' || segments[0] == 'debts') &&
        segments[2] == 'edit';
  }

  return segments.length == 4 &&
      segments[0] == 'debts' &&
      segments[2] == 'payments' &&
      segments[3] == 'new';
}
