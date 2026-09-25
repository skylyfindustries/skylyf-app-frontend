import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n.dart';
import '../../core/machine_art.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'manage_machine.dart';

class MachinesScreen extends ConsumerStatefulWidget {
  const MachinesScreen({super.key});

  @override
  ConsumerState<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<MachinesScreen> {
  String? _type; // null = ALL
  String? _company; // staff filter: null = all customers, 'unassigned', or a customer name
  String _tab = 'mine';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final role = ref.watch(roleProvider) ?? Role.customer;
    final machines = ref.watch(machinesProvider);

    return Poll(
      onTick: () => ref.invalidate(machinesProvider),
      child: RefreshIndicator(
        color: Brand.gold500,
        onRefresh: () async {
          ref.invalidate(machinesProvider);
          ref.invalidate(registrationsProvider);
          await ref.read(machinesProvider.future);
        },
        child: ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
          Row(children: [
            Expanded(child: Text(t('Machines'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            if (role.canManageMachines)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => showAddMachine(context, ref),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add'),
              ),
          ]),
          const SizedBox(height: 12),
          if (role.canRegisterMachines) ...[
            Segments<String>(
              options: [('mine', 'My machines${machines.valueOrNull == null ? '' : ' (${machines.valueOrNull!.length})'}'), ('register', 'Register new')],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 14),
          ],
          if (_tab == 'register' && role.canRegisterMachines)
            const _RegisterTab()
          else
            SizedBox(
              height: machines.hasValue ? null : 260,
              child: asyncView(machines, (all) => _MineTab(all, _type, (v) => setState(() => _type = v), t, staff: role.isStaff, company: _company, onCompany: (v) => setState(() => _company = v)), onRetry: () => ref.invalidate(machinesProvider)),
            ),
        ]),
      ),
    );
  }
}

// ---------------- My machines ----------------
class _MineTab extends StatelessWidget {
  const _MineTab(this.all, this.type, this.onType, this.t, {this.staff = false, this.company, this.onCompany});
  final List<Machine> all;
  final String? type;
  final ValueChanged<String?> onType;
  final String Function(String) t;
  final bool staff;
  final String? company;
  final ValueChanged<String?>? onCompany;

  @override
  Widget build(BuildContext context) {
    final types = <String, String>{for (final m in all) m.typeKey: m.typeName.toUpperCase()};
    final companies = <String>{for (final m in all) m.company ?? 'unassigned'};
    final shown = all.where((m) => (type == null || m.typeKey == type) && (company == null || (m.company ?? 'unassigned') == company)).toList();
    final running = shown.where((m) => m.status == 'running').length;
    final produced = shown.fold<num>(0, (s, m) => s + m.todayProduction);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (staff && companies.length > 1) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Chip('All customers', company == null, () => onCompany?.call(null)),
            for (final c in companies) _Chip(c == 'unassigned' ? 'Unassigned' : c, company == c, () => onCompany?.call(c)),
          ]),
        ),
        const SizedBox(height: 4),
      ],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Chip(t('ALL'), type == null, () => onType(null)),
          for (final e in types.entries) _Chip(t(e.value), type == e.key, () => onType(e.key)),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Icon(LucideIcons.factory, size: 18, color: Brand.gold300),
          const SizedBox(width: 8),
          Expanded(child: Text('${shown.length} machines • $running running', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Muted('${fmt(produced)} made today', size: 12),
        ]),
      ).reveal(0),
      const SizedBox(height: 12),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Muted('No machines found', size: 14))),
      for (final (i, m) in shown.indexed) MachineRow(m).reveal(math.min(i, 8)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Brand.navy900 : Brand.ink)),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: Brand.gold500,
          backgroundColor: Colors.white.withValues(alpha: 0.75),
          side: const BorderSide(color: Brand.line),
          showCheckmark: false,
          visualDensity: VisualDensity.comfortable,
        ),
      );
}

/// One machine: thumbnail, status, speed and today's progress. Staff also see the customer name.
class MachineRow extends ConsumerWidget {
  const MachineRow(this.m, {super.key});
  final Machine m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final staff = ref.watch(roleProvider)?.isStaff ?? false;
    final pct = m.todayTarget == 0 ? 0.0 : (m.todayProduction / m.todayTarget).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => context.push('/machine/${m.id}'),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SizedBox(width: 78, child: MachineArt(m.typeKey, status: m.status, height: 70, radius: 14)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(m.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(width: 10),
                StatusDot(m.status, size: 9),
                const SizedBox(width: 6),
                Text(t(m.statusLabel), style: TextStyle(color: statusColor(m.status), fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              if (staff) Text(m.company ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: m.company == null ? Brand.idle : Brand.gold300, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(children: [
                Text('${fmt(m.speed)} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted(m.speedUnit, size: 12),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: AnimatedBar(pct, height: 5, color: m.status == 'stopped' ? Brand.stopped : Brand.gold500)),
                const SizedBox(width: 8),
                Muted('${fmt(m.todayProduction)} ${m.outputUnit}', size: 11),
              ]),
            ]),
          ),
          const Icon(LucideIcons.chevronRight, size: 18, color: Brand.inkSoft),
        ]),
      ),
    );
  }
}

// ---------------- Register new ----------------
class _RegisterTab extends ConsumerWidget {
  const _RegisterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final regs = ref.watch(registrationsProvider).valueOrNull ?? const <Registration>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (regs.isNotEmpty) ...[
        const SectionTitle(LucideIcons.hourglass, 'Pending registrations').reveal(0),
        for (final r in regs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(children: [
                SizedBox(width: 64, child: MachineArt(r.typeKey, height: 52, radius: 12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.nickname} • ${r.model}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Muted('Serial ${r.serial}', size: 11),
                    Muted('Submitted ${timeAgo(r.createdAt)}', size: 11),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Brand.idle.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.idle, letterSpacing: 0.6)),
                ),
              ]),
            ),
          ).reveal(1),
      ],
      const SectionTitle(LucideIcons.circlePlus, 'Available to register'),
      const Muted('Pick a Skylyf machine you own, enter its serial number, and we will connect it to your account.', size: 13),
      const SizedBox(height: 12),
      SizedBox(
        height: catalog.hasValue ? null : 220,
        child: asyncView(
          catalog,
          (list) => Column(children: [for (final (i, c) in list.indexed) _CatalogCard(c).reveal(i)]),
          onRetry: () => ref.invalidate(catalogProvider),
        ),
      ),
    ]);
  }
}

class _CatalogCard extends ConsumerWidget {
  const _CatalogCard(this.c);
  final CatalogItem c;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MachineArt(c.typeKey, height: 130, radius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text(c.model, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.gold300)),
                  ),
                ]),
                const SizedBox(height: 4),
                Muted(c.tagline, size: 13),
                const SizedBox(height: 10),
                Row(children: [const Icon(LucideIcons.gauge, size: 16, color: Brand.gold300), const SizedBox(width: 6), Text(c.speed, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  for (final s in c.specs) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.check, size: 14, color: Brand.running), const SizedBox(width: 4), Text(s, style: const TextStyle(fontSize: 12))]),
                ]),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: () => _register(context, ref), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Register this machine')),
              ]),
            ),
          ]),
        ),
      );

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RegisterSheet(c),
    );
    if (done == true && context.mounted) {
      ref.invalidate(registrationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration submitted. Skylyf will verify the serial number within 24 hours.')));
    }
  }
}

class _RegisterSheet extends ConsumerStatefulWidget {
  const _RegisterSheet(this.c);
  final CatalogItem c;

  @override
  ConsumerState<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<_RegisterSheet> {
  final _form = GlobalKey<FormState>();
  final _serial = TextEditingController();
  final _nick = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serial.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(apiProvider).post('/registrations', {'catalogId': widget.c.id, 'serial': _serial.text.trim().toUpperCase(), 'nickname': _nick.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Register ${widget.c.model}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Muted('The serial number is on the nameplate at the back of the machine.', size: 13),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Serial number', prefixIcon: Icon(LucideIcons.hash)),
              validator: (v) => (v == null || v.trim().length < 8) ? 'Enter the full serial number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nick,
              decoration: const InputDecoration(labelText: 'Machine name (e.g. PC-12)', prefixIcon: Icon(LucideIcons.tag)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a short name' : null,
            ),
            const SizedBox(height: 12),
            const GlassCard(padding: EdgeInsets.all(14), child: Row(children: [Icon(LucideIcons.mapPin, size: 18, color: Brand.gold300), SizedBox(width: 10), Text('Plant: Noida Plant', style: TextStyle(fontWeight: FontWeight.w600))])),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
            const SizedBox(height: 18),
            FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : const Text('Submit registration')),
          ]),
        ),
      );
}
