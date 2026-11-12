import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_pin_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customer_form_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/debt_groups/presentation/group_detail_screen.dart';
import '../features/debt_groups/presentation/group_form_screen.dart';
import '../features/debt_groups/presentation/groups_screen.dart';
import '../features/debts/presentation/debts_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';
import 'error_screen.dart';
import 'navigation.dart';

final routerProvider = Provider<GoRouter>((ref) => createAppRouter());

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),
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
      GoRoute(
        path: AppRoutes.customerNew,
        builder: (context, state) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/customers/:customerId',
        builder: (context, state) => CustomerDetailScreen(
          customerId: state.pathParameters['customerId']!,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'edit',
            builder: (context, state) => CustomerFormScreen(
              customerId: state.pathParameters['customerId']!,
            ),
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
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersScreen(),
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
