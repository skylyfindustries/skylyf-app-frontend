import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/export.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../home/home_screen.dart' show StatusCount;
import '../machines/machines_screen.dart' show MachineRow;
import '../machines/manage_machine.dart';

// ---------- shared bits ----------
class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Brand.gold500.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.gold500.withValues(alpha: 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(role.icon, size: 14, color: Brand.gold300),
          const SizedBox(width: 6),
          Text(role.label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Brand.gold300)),
        ]),
      );
}

class _Header extends ConsumerWidget {
  const _Header(this.greeting);
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final role = ref.watch(roleProvider) ?? Role.technician;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$greeting${me == null ? '' : ', ${me.name.split(' ').first}'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      RoleBadge(role),
    ]);
  }
}

class StatTile extends StatelessWidget {
  const StatTile(this.icon, this.value, this.label, {super.key, this.color = Brand.gold300});
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          CountUp(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 4),
          Muted(label),
        ]),
      );
}

Color _priorityColor(String p) => switch (p) { 'high' => Brand.stopped, 'medium' => Brand.idle, _ => Brand.running };

// ---------- tasks ----------
class TicketCard extends ConsumerWidget {
  const TicketCard(this.k, {super.key, this.actions = false, this.owner = false});
  final StaffTicket k;
  final bool actions; // technician: start / resolve
  final bool owner; // owner: reassign to another technician

  Future<void> _move(BuildContext context, WidgetRef ref, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).patch('/tickets/${k.id}', {'status': status});
      ref.invalidate(staffTicketsProvider);
      messenger.showSnackBar(SnackBar(content: Text(status == 'done' ? '${k.code} marked resolved' : 'Started work on ${k.code}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final techId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ReassignSheet(current: k.technicianId),
    );
    if (techId == null || techId == k.technicianId || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).patch('/tickets/${k.id}', {'technicianId': techId});
      ref.invalidate(staffTicketsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Task reassigned')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = switch (k.status) { 'open' => ('in_progress', 'Start work', LucideIcons.play), 'in_progress' => ('done', 'Mark resolved', LucideIcons.check), _ => null };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => context.push('/machine/${k.machineId}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(k.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(width: 10),
            Expanded(child: Text(k.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _priorityColor(k.priority).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Text(k.priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _priorityColor(k.priority))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(k.note, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(LucideIcons.hardHat, size: 14, color: Brand.gold300),
            const SizedBox(width: 5),
            Text(k.technician ?? 'Unassigned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Muted(timeAgo(k.createdAt), size: 12),
          ]),
          if (actions && next != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => _move(context, ref, next.$1),
              icon: Icon(next.$3, size: 18),
              label: Text(next.$2),
            ),
          ],
          if (owner && k.status != 'done') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () => _reassign(context, ref),
              icon: const Icon(LucideIcons.arrowRightLeft, size: 16),
              label: const Text('Reassign technician'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ReassignSheet extends ConsumerWidget {
  const _ReassignSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Technician>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Reassign task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final t in techs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: () => Navigator.pop(context, t.id),
              child: Row(children: [
                CircleAvatar(backgroundColor: Brand.gold500, child: Text(t.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy900))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)), Muted(t.companies.isEmpty ? t.phone : 'Serves ${t.companies.join(', ')}', size: 12)])),
                if (t.id == current) const Icon(LucideIcons.circleCheck, color: Brand.gold300),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ---------- technician ----------
class TechHomeScreen extends ConsumerWidget {
  const TechHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref.invalidate(overviewProvider);
      ref.invalidate(staffTicketsProvider);
      await ref.read(staffTicketsProvider.future);
    }

    return RefreshIndicator(
      color: Brand.gold500,
      onRefresh: refresh,
      child: asyncView(
        ref.watch(overviewProvider),
        (ov) => asyncView(
          ref.watch(staffTicketsProvider),
          (tickets) {
            int n(String s) => tickets.where((t) => t.status == s).length;
            final pending = tickets.where((t) => t.status != 'done').take(3);
            return ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
              const _Header('Hello').reveal(0),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: StatTile(LucideIcons.circleAlert, n('open'), 'My open tasks', color: Brand.stopped)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(LucideIcons.wrench, n('in_progress'), 'In progress', color: Brand.idle)),
                const SizedBox(width: 10),
                Expanded(child: StatTile(LucideIcons.circleCheck, n('done'), 'Resolved', color: Brand.running)),
              ]).reveal(1),
              const SectionTitle(LucideIcons.triangleAlert, 'Machines down (my customers)'),
              if (ov.attention.isEmpty) const GlassCard(child: Text('No machines are down')),
              for (final a in ov.attention)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    onTap: () => context.push('/machine/${a.machineId}'),
                    child: Row(children: [
                      StatusDot(a.status),
                      const SizedBox(width: 12),
                      Text(a.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(a.company ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft))),
                      const Icon(LucideIcons.chevronRight, size: 20, color: Brand.inkSoft),
                    ]),
                  ),
                ),
              const SectionTitle(LucideIcons.clipboardList, 'Latest tasks for me'),
              if (pending.isEmpty) const GlassCard(child: Text('No open tasks. Nice work!')),
              for (final k in pending) TicketCard(k),
            ]);
          },
          onRetry: () => ref.invalidate(staffTicketsProvider),
        ),
        onRetry: () => ref.invalidate(overviewProvider),
      ),
    );
  }
}

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final canAct = (ref.watch(roleProvider) ?? Role.technician).canManageTickets;
    return asyncView(
      ref.watch(staffTicketsProvider),
      (all) {
        final shown = all.where((k) => k.status == _status).toList();
        return RefreshIndicator(
          color: Brand.gold500,
          onRefresh: () async {
            ref.invalidate(staffTicketsProvider);
            await ref.read(staffTicketsProvider.future);
          },
          child: ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
            Text('My tasks', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Muted('Tasks customers have given to you', size: 13),
            const SizedBox(height: 12),
            Segments<String>(
              options: [for (final (s, l) in const [('open', 'Open'), ('in_progress', 'In progress'), ('done', 'Done')]) (s, '$l (${all.where((k) => k.status == s).length})')],
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Muted('Nothing here', size: 14))),
            for (final (i, k) in shown.indexed) TicketCard(k, actions: canAct).reveal(i),
          ]),
        );
      },
      onRetry: () => ref.invalidate(staffTicketsProvider),
    );
  }
}

// ---------- owner ----------
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: Brand.gold500,
      onRefresh: () async {
        refreshFleet(ref);
        ref.invalidate(staffTicketsProvider);
        await ref.read(overviewProvider.future);
      },
      child: asyncView(
        ref.watch(overviewProvider),
        (ov) {
          final customers = ref.watch(customersProvider).valueOrNull ?? const <CustomerSummary>[];
          final pending = (ref.watch(registrationsProvider).valueOrNull ?? const <Registration>[]).where((r) => r.status == 'pending').toList();
          final tasks = (ref.watch(staffTicketsProvider).valueOrNull ?? const <StaffTicket>[]).where((k) => k.status != 'done').take(4).toList();
          return ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
            const _Header('Welcome').reveal(0),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: StatTile(LucideIcons.building2, ov.customers, 'Customers')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(LucideIcons.factory, ov.machines, 'Machines')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(LucideIcons.hardHat, ov.technicians, 'Technicians')),
            ]).reveal(1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatusCount('running', ov.running, 'Running')),
              const SizedBox(width: 10),
              Expanded(child: StatusCount('stopped', ov.stopped, 'Stopped')),
              const SizedBox(width: 10),
              Expanded(child: StatusCount('idle', ov.idle, 'Idle')),
            ]).reveal(2),
            if (ov.unassigned > 0) ...[
              const SizedBox(height: 12),
              GlassCard(
                onTap: () => context.go('/machines'),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Brand.idle.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.warehouse, size: 20, color: Brand.idle)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${ov.unassigned} machines are not assigned to a customer', style: const TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(LucideIcons.chevronRight, size: 20, color: Brand.inkSoft),
                ]),
              ).reveal(3),
            ],
            if (pending.isNotEmpty) ...[
              const SectionTitle(LucideIcons.hourglass, 'Registration requests').reveal(4),
              for (final r in pending) _RegistrationCard(r).reveal(4),
            ],
            const SectionTitle(LucideIcons.clipboardList, 'Open tasks').reveal(5),
            if (tasks.isEmpty) const GlassCard(child: Text('No open tasks')),
            for (final k in tasks) TicketCard(k, owner: true),
            const SectionTitle(LucideIcons.triangleAlert, 'Customers needing attention'),
            for (final c in customers.where((c) => c.stopped > 0))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => context.push('/customer/${c.id}'),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)), Muted(c.city)])),
                    const StatusDot('stopped'),
                    const SizedBox(width: 8),
                    Text('${c.stopped} stopped', style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.chevronRight, size: 20, color: Brand.inkSoft),
                  ]),
                ),
              ),
          ]);
        },
        onRetry: () => ref.invalidate(overviewProvider),
      ),
    );
  }
}

/// A customer asked to add a machine: the owner approves (machine appears in their app) or rejects.
class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard(this.r);
  final Registration r;

  Future<void> _decide(BuildContext context, WidgetRef ref, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).patch('/registrations/${r.id}', {'status': status});
      refreshFleet(ref);
      ref.invalidate(staffTicketsProvider);
      messenger.showSnackBar(SnackBar(content: Text(status == 'approved' ? '${r.nickname} added to ${r.company}' : 'Registration rejected')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.company ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.gold300, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${r.nickname} • ${r.model}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Muted('Serial ${r.serial} • ${timeAgo(r.createdAt)}', size: 12),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), onPressed: () => _decide(context, ref, 'rejected'), child: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)), onPressed: () => _decide(context, ref, 'approved'), child: const Text('Approve'))),
            ]),
          ]),
        ),
      );
}

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncView(
        ref.watch(customersProvider),
        (list) => RefreshIndicator(
          color: Brand.gold500,
          onRefresh: () async {
            ref.invalidate(customersProvider);
            await ref.read(customersProvider.future);
          },
          child: ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
            Row(children: [
              Expanded(child: Text('Customers', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              ExportButton(() => (
                title: 'customers',
                cols: ['Customer', 'City', 'Machines', 'Running', 'Stopped', 'Idle', 'Technicians'],
                rows: [for (final c in list) [c.name, c.city, '${c.machines}', '${c.running}', '${c.stopped}', '${c.idle}', '${c.technicians}']],
              )),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => _addCustomer(context, ref),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 12),
            for (final (i, c) in list.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => context.push('/customer/${c.id}'),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      const Icon(LucideIcons.chevronRight, size: 20, color: Brand.inkSoft),
                    ]),
                    Muted('${c.city} • ${c.machines} machines • ${c.technicians} technicians'),
                    const SizedBox(height: 12),
                    Row(children: [
                      for (final (s, n) in [('running', c.running), ('stopped', c.stopped), ('idle', c.idle)]) ...[StatusDot(s, size: 10), const SizedBox(width: 6), Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 18)],
                    ]),
                  ]),
                ),
              ).reveal(i),
          ]),
        ),
        onRetry: () => ref.invalidate(customersProvider),
      );

  Future<void> _addCustomer(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final city = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(c).viewInsets.bottom),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Muted('A customer is a separate tenant: they only ever see their own machines.', size: 13),
            const SizedBox(height: 16),
            TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Company name', prefixIcon: Icon(LucideIcons.building2)), validator: (v) => (v == null || v.trim().length < 2) ? 'Enter the company name' : null),
            const SizedBox(height: 12),
            TextFormField(controller: city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(LucideIcons.mapPin)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the city' : null),
            const SizedBox(height: 18),
            FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(c, true); }, child: const Text('Add customer')),
          ]),
        ),
      ),
    );
    final n = name.text, ci = city.text;
    name.dispose();
    city.dispose();
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).post('/customers', {'name': n, 'city': ci});
      refreshFleet(ref);
      messenger.showSnackBar(SnackBar(content: Text('${n.trim().toUpperCase()} added. Now assign machines and technicians.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// One customer (tenant): their machines, the technicians they may give tasks to, and their users.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _api(BuildContext context, WidgetRef ref, Future<dynamic> Function() call, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call();
      refreshFleet(ref, customerId: id);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manage = ref.watch(roleProvider)?.canManageMachines ?? false;
    final detail = ref.watch(customerDetailProvider(id));
    return GlassPage(
      title: detail.valueOrNull?.summary.name ?? '',
      child: asyncView(
        detail,
        (d) {
          final assignedIds = [for (final t in d.technicians) if (t.assigned) t.id];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(LucideIcons.mapPin, size: 18, color: Brand.gold300),
                const SizedBox(width: 8),
                Text(d.summary.city, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                for (final (s, n) in [('running', d.summary.running), ('stopped', d.summary.stopped), ('idle', d.summary.idle)]) ...[StatusDot(s, size: 10), const SizedBox(width: 5), Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 14)],
              ]),
            ).reveal(0),
            SectionTitle(LucideIcons.factory, 'Machines (${d.machines.length})', trailing: manage ? TextButton.icon(onPressed: () => _pickUnassigned(context, ref), icon: const Icon(LucideIcons.link, size: 16), label: const Text('Assign')) : null),
            if (d.machines.isEmpty) const GlassCard(child: Text('No machines assigned yet')),
            for (final m in d.machines)
              Column(children: [
                MachineRow(m),
                if (manage)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _api(context, ref, () => ref.read(apiProvider).patch('/machines/${m.id}', {'companyId': null}), '${m.code} removed from ${d.summary.name}'),
                      icon: const Icon(LucideIcons.unlink, size: 14),
                      label: const Text('Remove from customer'),
                      style: TextButton.styleFrom(foregroundColor: Brand.stopped),
                    ),
                  ),
              ]),
            if (manage) OutlinedButton.icon(onPressed: () => showAddMachine(context, ref, presetCustomerId: id), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Add a new machine for this customer')),
            const SectionTitle(LucideIcons.hardHat, 'Technicians'),
            const Muted('Only these technicians can be given tasks by this customer.', size: 12),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (i, t) in d.technicians.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: Brand.line),
                  if (manage)
                    SwitchListTile.adaptive(
                      value: t.assigned,
                      onChanged: (v) {
                        final next = v ? [...assignedIds, t.id] : [...assignedIds]..remove(t.id);
                        _api(context, ref, () => ref.read(apiProvider).patch('/customers/$id', {'technicianIds': next}), v ? '${t.name} can now serve ${d.summary.name}' : '${t.name} removed');
                      },
                      secondary: CircleAvatar(backgroundColor: Brand.gold500, child: Text(t.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy900))),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(t.phone, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    )
                  else if (t.assigned)
                    ListTile(leading: CircleAvatar(backgroundColor: Brand.gold500, child: Text(t.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy900))), title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(t.phone)),
                ],
              ]),
            ),
            const SectionTitle(LucideIcons.users, 'Users'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                if (d.users.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Muted('No users yet', size: 13)),
                for (final u in d.users) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.user, size: 20, color: Brand.gold300), title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(u.email)),
              ]),
            ),
          ]);
        },
        onRetry: () => ref.invalidate(customerDetailProvider(id)),
      ),
    );
  }

  /// Pick from the owner's unassigned pool and give it to this customer.
  Future<void> _pickUnassigned(BuildContext context, WidgetRef ref) async {
    final all = await ref.read(machinesProvider.future);
    final pool = all.where((m) => m.companyId == null).toList();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Machine>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Assign a machine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Muted('Unassigned machines in Skylyf stock', size: 13),
          const SizedBox(height: 12),
          if (pool.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Muted('No unassigned machines. Add one first.', size: 14))),
          for (final m in pool)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => Navigator.pop(c, m),
                child: Row(children: [
                  StatusDot(m.status),
                  const SizedBox(width: 12),
                  Text(m.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Muted('${m.typeName} • ${m.model}', size: 12)),
                  const Icon(LucideIcons.plus, size: 18, color: Brand.gold300),
                ]),
              ),
            ),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _api(context, ref, () => ref.read(apiProvider).patch('/machines/${picked.id}', {'companyId': id}), '${picked.code} assigned');
  }
}

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncView(
        ref.watch(usersProvider),
        (list) => ListView(padding: navClearance, children: [
          Text('Team', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Muted('Everyone with access, and who they can see', size: 13),
          const SizedBox(height: 12),
          for (final (i, u) in list.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(children: [
                  CircleAvatar(backgroundColor: Brand.gold500, child: Text(u.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy900))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Muted(u.email),
                      Text(u.company, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Brand.gold300, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  RoleBadge(u.role),
                ]),
              ),
            ).reveal(i),
        ]),
        onRetry: () => ref.invalidate(usersProvider),
      );
}
