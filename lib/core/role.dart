import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NavTab {
  const NavTab(this.path, this.icon, this.label);
  final String path, label;
  final IconData icon;
}

/// One place that decides what each role sees: tabs, and what actions are allowed.
///  customer   – factory owner/manager: own plant only
///  technician – Skylyf service engineer: tickets + machines across customers
///  admin      – Skylyf staff: customers, users, everything read-only + overview
enum Role {
  customer('Customer'),
  technician('Technician'),
  admin('Owner'); // key stays `admin` to match the backend enum

  const Role(this.label);
  final String label;

  static Role parse(String? s) => Role.values.firstWhere((r) => r.name == s, orElse: () => Role.customer);

  bool get isStaff => this != customer;
  bool get canBuyParts => this == customer;
  bool get canRequestService => this == customer;
  bool get canRegisterMachines => this == customer;
  bool get canSetProductionGoal => this == customer || this == admin;
  bool get canManageTickets => this == technician;
  bool get canManageMachines => this == admin; // add machines, assign to customers, assign technicians

  List<NavTab> get tabs => switch (this) {
        Role.customer => const [
            NavTab('/', LucideIcons.house, 'Home'),
            NavTab('/machines', LucideIcons.factory, 'Machines'),
            NavTab('/assignments', LucideIcons.calendarCheck, 'Assignments'),
            NavTab('/parts', LucideIcons.shoppingCart, 'Parts'),
            NavTab('/profile', LucideIcons.user, 'Profile'),
          ],
        Role.technician => const [
            NavTab('/', LucideIcons.layoutDashboard, 'Dashboard'),
            NavTab('/my-tasks', LucideIcons.clipboardList, 'Tasks'),
            NavTab('/profile', LucideIcons.user, 'Profile'),
          ],
        Role.admin => const [
            NavTab('/', LucideIcons.layoutDashboard, 'Overview'),
            NavTab('/customers', LucideIcons.building2, 'Customers'),
            NavTab('/machines', LucideIcons.factory, 'Machines'),
            NavTab('/users', LucideIcons.users, 'Team'),
            NavTab('/profile', LucideIcons.user, 'Profile'),
          ],
      };

  IconData get icon => switch (this) {
        Role.customer => LucideIcons.factory,
        Role.technician => LucideIcons.wrench,
        Role.admin => LucideIcons.shieldCheck,
      };

  /// Tab paths that exist for some role but not this one (used by the router guard).
  static Set<String> get allTabPaths => {for (final r in values) ...r.tabs.map((t) => t.path)};
}
