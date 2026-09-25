import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../staff/staff_screens.dart';
import 'home_screen.dart';

/// "/" is a different screen per role.
class RoleHome extends ConsumerWidget {
  const RoleHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(roleProvider) ?? Role.customer) {
        Role.customer => const HomeScreen(),
        Role.technician => const TechHomeScreen(),
        Role.admin => const AdminHomeScreen(),
      };
}
