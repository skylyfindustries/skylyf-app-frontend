import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/role_home.dart';
import '../features/machines/machine_detail_screen.dart';
import '../features/machines/machines_screen.dart';
import '../features/machines/maintenance_screen.dart';
import '../features/parts/parts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/team/technicians_screen.dart';
import '../features/profile/settings_screens.dart';
import '../features/reports/reports_screen.dart';
import '../features/shell/shell.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/staff/staff_screens.dart';
import 'providers.dart';
import 'role.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<Session>(ref.read(authProvider));
  ref.listen(authProvider, (_, s) => session.value = s);
  ref.onDispose(session.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (_, state) {
      final loc = state.uri.path;
      return switch (session.value) {
        Session.unknown => loc == '/splash' ? null : '/splash',
        Session.out => loc == '/login' ? null : '/login',
        Session.active => loc == '/login' || loc == '/splash'
            ? '/'
            // a tab that belongs to another role → back to this role's home
            : Role.allTabPaths.contains(loc) && !(ref.read(roleProvider) ?? Role.customer).tabs.any((t) => t.path == loc)
                ? '/'
                : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const GlassBackground(child: Center(child: LogoBadge()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, state, child) => Shell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, __) => const NoTransitionPage(child: RoleHome())),
          GoRoute(path: '/machines', pageBuilder: (_, __) => const NoTransitionPage(child: MachinesScreen())),
          GoRoute(path: '/reports', pageBuilder: (_, __) => const NoTransitionPage(child: ReportsScreen())),
          GoRoute(
            path: '/parts',
            pageBuilder: (_, s) => NoTransitionPage(child: PartsScreen(machineId: s.uri.queryParameters['machineId'])),
          ),
          GoRoute(path: '/tickets', pageBuilder: (_, __) => const NoTransitionPage(child: TicketsScreen())),
          GoRoute(path: '/customers', pageBuilder: (_, __) => const NoTransitionPage(child: CustomersScreen())),
          GoRoute(path: '/users', pageBuilder: (_, __) => const NoTransitionPage(child: UsersScreen())),
          GoRoute(path: '/profile', pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen())),
        ],
      ),
      GoRoute(path: '/machine/:id', builder: (_, s) => MachineDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/machine/:id/maintenance', builder: (_, s) => MaintenanceScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/customer/:id', builder: (_, s) => CustomerDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/technicians', builder: (_, __) => const TechniciansScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/security', builder: (_, __) => const SecurityScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
    ],
  );
});
