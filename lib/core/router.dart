import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/auth_widgets.dart' show GearsAnimation;
import '../features/auth/forgot_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/role_home.dart';
import '../features/machines/machine_detail_screen.dart';
import '../features/machines/set_goal_screen.dart';
import '../features/machines/machines_screen.dart';
import '../features/machines/maintenance_screen.dart';
import '../features/parts/cart_screen.dart';
import '../features/parts/my_orders_screen.dart';
import '../features/parts/part_detail_screen.dart';
import '../features/parts/wishlist_screen.dart';
import '../features/parts/parts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/team/assignments_screen.dart';
import '../features/team/my_tasks_screen.dart';
import '../features/team/technicians_screen.dart';
import '../features/profile/settings_screens.dart';
import '../features/reports/reports_screen.dart';
import '../features/shell/shell.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/staff/staff_screens.dart';
import 'providers.dart';
import 'analytics.dart';
import 'role.dart';
import 'theme.dart';
import 'widgets.dart' show GlassPage;

/// Screens a signed-out user may open.
const _public = {'/login', '/register', '/forgot', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<Session>(ref.read(authProvider));
  ref.listen(authProvider, (_, s) => session.value = s);
  ref.onDispose(session.dispose);

  final analytics = Analytics(ref.read(apiProvider));
  return GoRouter(
    observers: [AnalyticsObserver(analytics)],
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (_, state) {
      final loc = state.uri.path;
      return switch (session.value) {
        Session.unknown => loc == '/splash' ? null : '/splash',
        Session.out => _public.contains(loc) ? null : '/login',
        Session.active => _public.contains(loc) || loc == '/splash'
            ? '/'
            // a tab that belongs to another role → back to this role's home
            : Role.allTabPaths.contains(loc) && !(ref.read(roleProvider) ?? Role.customer).tabs.any((t) => t.path == loc)
                ? '/'
                : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const GlassBackground(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [GearsAnimation(size: 120), LogoBadge()])))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotScreen()),
      // opened from the link in the reset email
      GoRoute(path: '/reset-password', builder: (_, s) => ForgotScreen(resetToken: s.uri.queryParameters['token'])),
      ShellRoute(
        builder: (_, state, child) => Shell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, s) => _tab(s, const RoleHome())),
          GoRoute(path: '/machines', pageBuilder: (_, s) => _tab(s, const MachinesScreen())),
          GoRoute(path: '/assignments', pageBuilder: (_, s) => _tab(s, const AssignmentsScreen())),
          GoRoute(
            path: '/parts',
            pageBuilder: (_, s) => _tab(s, PartsScreen(machineId: s.uri.queryParameters['machineId'])),
          ),
          GoRoute(path: '/my-tasks', pageBuilder: (_, s) => _tab(s, const MyTasksScreen())),
          GoRoute(path: '/customers', pageBuilder: (_, s) => _tab(s, const CustomersScreen())),
          GoRoute(path: '/users', pageBuilder: (_, s) => _tab(s, const UsersScreen())),
          GoRoute(path: '/profile', pageBuilder: (_, s) => _tab(s, const ProfileScreen())),
        ],
      ),
      GoRoute(path: '/machine/:id', builder: (_, s) => MachineDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/machine/:id/goal', builder: (_, s) => SetGoalScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/machine/:id/maintenance', builder: (_, s) => MaintenanceScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/customer/:id', builder: (_, s) => CustomerDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/technicians', builder: (_, __) => const TechniciansScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const GlassPage(title: 'Reports', child: ReportsScreen(standalone: true))),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/my-orders', builder: (_, __) => const MyOrdersScreen()),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/part/:id', builder: (_, s) => PartDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/security', builder: (_, __) => const SecurityScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
    ],
  );
});

/// Bottom-tab page: incoming fades + slides up slightly, outgoing fades out (pages are transparent).
Page<void> _tab(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, a, sa, c) => FadeTransition(
        opacity: ReverseAnimation(sa),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
        ),
      ),
    );
