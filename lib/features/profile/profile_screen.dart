import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../staff/staff_screens.dart' show RoleBadge;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final role = ref.watch(roleProvider) ?? Role.customer;
    final plants = role.isStaff ? const [] : ref.watch(plantsProvider).valueOrNull ?? const [];
    final machines = ref.watch(machinesProvider).valueOrNull?.length;

    return asyncView(
      ref.watch(meProvider),
      (me) => ListView(padding: navClearance, children: [
        Text(t('Profile'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE8B85A), Brand.gold500])),
                child: Text(me.name.isEmpty ? '?' : me.name[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.navy900)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Muted(me.email, size: 13),
                  const SizedBox(height: 6),
                  RoleBadge(role),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Brand.line),
            const SizedBox(height: 14),
            Row(children: [
              _Fact(LucideIcons.building2, 'Company', me.company),
              if (!role.isStaff) _Fact(LucideIcons.mapPin, 'Plants', plants.isEmpty ? '–' : plants.map((p) => p.name).join(', ')),
              if (!role.isStaff) _Fact(LucideIcons.factory, 'Machines', machines == null ? '–' : '$machines'),
            ]),
          ]),
        ).reveal(0),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            _MenuTile(LucideIcons.settings, 'Settings', 'Notifications, language, display', () => context.push('/settings')),
            const Divider(height: 1, color: Brand.line, indent: 66),
            _MenuTile(LucideIcons.shieldCheck, 'Security', 'Password, two-step verification, devices', () => context.push('/security')),
            if (!role.isStaff) ...[
              const Divider(height: 1, color: Brand.line, indent: 66),
              _MenuTile(LucideIcons.wrench, 'My technicians', 'Add or remove your technicians', () => context.push('/technicians')),
              const Divider(height: 1, color: Brand.line, indent: 66),
              _MenuTile(LucideIcons.clipboardList, 'Service requests', 'Tasks given to your technicians', () => context.push('/tasks')),
              const Divider(height: 1, color: Brand.line, indent: 66),
              _MenuTile(LucideIcons.bell, t('Alerts'), 'Machine stop and target alerts', () => context.push('/alerts')),
            ],
            const Divider(height: 1, color: Brand.line, indent: 66),
            _MenuTile(LucideIcons.lifeBuoy, 'Help & support', 'Call, email or read the FAQ', () => context.push('/help')),
          ]),
        ).reveal(1),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text('You will need to sign in again to see your machines.'),
                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out'))],
              ),
            );
            if (ok == true) ref.read(authProvider.notifier).logout();
          },
          icon: const Icon(LucideIcons.logOut, size: 18),
          label: Text(t('Logout')),
        ).reveal(2),
        const SizedBox(height: 16),
        const Center(child: Muted('Skylyf Machine • v1.0.0', size: 11)),
      ]),
      onRetry: () => ref.invalidate(meProvider),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: Brand.gold300), const SizedBox(width: 5), Muted(label, size: 11)]),
          const SizedBox(height: 4),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: Brand.gold300)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Muted(subtitle, size: 12)])),
            const Icon(LucideIcons.chevronRight, size: 18, color: Brand.inkSoft),
          ]),
        ),
      );
}
