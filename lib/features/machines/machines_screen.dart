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
import 'store_grid.dart';

class MachinesScreen extends ConsumerStatefulWidget {
  const MachinesScreen({super.key});

  @override
  ConsumerState<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<MachinesScreen> {
  String? _type; // null = ALL
  String? _company; // staff filter: null = all customers, 'unassigned', or a customer name
  String? _status; // running | stopped | idle, null = any
  String _query = '';
  String _sort = 'code'; // code | status | production | efficiency
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
              child: asyncView(
                machines,
                (all) => _MineTab(
                  all, _type, (v) => setState(() => _type = v), t,
                  staff: role.isStaff, company: _company, onCompany: (v) => setState(() => _company = v),
                  status: _status, onStatus: (v) => setState(() => _status = v),
                  query: _query, onQuery: (v) => setState(() => _query = v),
                  sort: _sort, onSort: (v) => setState(() => _sort = v),
                  onClear: () => setState(() { _type = null; _status = null; _query = ''; _company = null; }),
                ),
                onRetry: () => ref.invalidate(machinesProvider),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------- My machines ----------------
class _MineTab extends StatelessWidget {
  const _MineTab(this.all, this.type, this.onType, this.t, {this.staff = false, this.company, this.onCompany, this.status, required this.onStatus, this.query = '', required this.onQuery, this.sort = 'code', required this.onSort, required this.onClear});
  final List<Machine> all;
  final String? type, status;
  final ValueChanged<String?> onType, onStatus;
  final String Function(String) t;
  final bool staff;
  final String? company;
  final ValueChanged<String?>? onCompany;
  final String query, sort;
  final ValueChanged<String> onQuery, onSort;
  final VoidCallback onClear;

  static const _sorts = {'code': 'Code (A–Z)', 'status': 'Stopped first', 'production': 'Most production today', 'efficiency': 'Lowest efficiency'};

  int _rank(Machine m) => switch (m.status) { 'stopped' => 0, 'idle' => 1, _ => 2 };

  @override
  Widget build(BuildContext context) {
    final types = <String, String>{for (final m in all) m.typeKey: m.typeName.toUpperCase()};
    final companies = <String>{for (final m in all) m.company ?? 'unassigned'};
    final q = query.trim().toLowerCase();
    bool typeOk(Machine m) => type == null || m.typeKey == type;
    bool companyOk(Machine m) => company == null || (m.company ?? 'unassigned') == company;
    bool textOk(Machine m) => q.isEmpty || '${m.code} ${m.name} ${m.model} ${m.typeName}'.toLowerCase().contains(q);
    // counts on the status chips follow the other filters
    final base = all.where((m) => typeOk(m) && companyOk(m) && textOk(m)).toList();
    final shown = base.where((m) => status == null || m.status == status).toList()
      ..sort((a, b) => switch (sort) {
            'status' => _rank(a) != _rank(b) ? _rank(a).compareTo(_rank(b)) : a.code.compareTo(b.code),
            'production' => b.todayProduction.compareTo(a.todayProduction),
            'efficiency' => a.efficiency.compareTo(b.efficiency),
            _ => a.code.compareTo(b.code),
          });
    final running = shown.where((m) => m.status == 'running').length;
    final produced = shown.fold<num>(0, (s, m) => s + m.todayProduction);
    final filtered = type != null || status != null || q.isNotEmpty || company != null;
    int n(String s) => base.where((m) => m.status == s).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _SearchBox(query, onQuery)),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Sort',
          onSelected: onSort,
          itemBuilder: (_) => [for (final e in _sorts.entries) CheckedPopupMenuItem(value: e.key, checked: sort == e.key, child: Text(e.value))],
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle, border: Border.all(color: Brand.line)),
            child: const Icon(LucideIcons.arrowUpDown, size: 20, color: Brand.navy700),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Chip('All (${base.length})', status == null, () => onStatus(null)),
          _Chip('${t('Running')} (${n('running')})', status == 'running', () => onStatus('running'), dot: Brand.running),
          _Chip('${t('Stopped')} (${n('stopped')})', status == 'stopped', () => onStatus('stopped'), dot: Brand.stopped),
          _Chip('${t('Idle')} (${n('idle')})', status == 'idle', () => onStatus('idle'), dot: Brand.idle),
        ]),
      ),
      if (types.length > 1) ...[
        const SizedBox(height: 2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Chip('All types', type == null, () => onType(null)),
            for (final e in types.entries) _Chip(t(e.value), type == e.key, () => onType(e.key)),
          ]),
        ),
      ],
      if (staff && companies.length > 1) ...[
        const SizedBox(height: 2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Chip('All customers', company == null, () => onCompany?.call(null)),
            for (final c in companies) _Chip(c == 'unassigned' ? 'Unassigned' : c, company == c, () => onCompany?.call(c)),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Icon(LucideIcons.factory, size: 18, color: Brand.gold300),
          const SizedBox(width: 8),
          Expanded(child: Text('${shown.length} machines • $running running', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (filtered) InkWell(onTap: onClear, borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text('Clear', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Brand.gold300))))
          else Muted('${fmt(produced)} made today', size: 12),
        ]),
      ).reveal(0),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Column(children: [
            const Icon(LucideIcons.searchX, size: 32, color: Brand.gold300),
            const SizedBox(height: 8),
            Muted(filtered ? 'No machines match your filters' : 'No machines found', size: 14),
            if (filtered) TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ])),
        ),
      for (final (i, m) in shown.indexed) MachineRow(m).reveal(math.min(i, 8)),
    ]);
  }
}

/// Pill search field that keeps its text when the list rebuilds.
class _SearchBox extends StatefulWidget {
  const _SearchBox(this.value, this.onChanged);
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_SearchBox old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value; // e.g. "Clear" reset it from outside
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search code, name or model',
          prefixIcon: const Icon(LucideIcons.search, size: 20),
          suffixIcon: _c.text.isEmpty ? null : IconButton(icon: const Icon(LucideIcons.x, size: 18), onPressed: () { _c.clear(); widget.onChanged(''); }),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.gold500, width: 1.6)),
        ),
      );
}

typedef _Chip = PillChip;

/// One machine: picture (no backdrop card), status, name/model, speed, efficiency, today's progress and when it last reported. Staff also see the customer name.
class MachineRow extends ConsumerWidget {
  const MachineRow(this.m, {super.key});
  final Machine m;

  Widget _fact(IconData icon, String text, {Color color = Brand.inkSoft}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final staff = ref.watch(roleProvider)?.isStaff ?? false;
    final pct = m.todayTarget == 0 ? 0.0 : (m.todayProduction / m.todayTarget).clamp(0, 1).toDouble();
    final title = [if (m.name.isNotEmpty) m.name else m.typeName, if (m.model.isNotEmpty && m.model != m.name) m.model].join(' · ');
    final eff = m.efficiency.round();
    final effColor = eff >= 85 ? Brand.running : eff >= 60 ? Brand.idle : Brand.stopped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => context.push('/machine/${m.id}'),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: MachineArt(m.typeKey, photo: m.photos.firstOrNull, status: m.status, height: 84, radius: 16, plain: true)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(m.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(width: 10),
                StatusDot(m.status, size: 9),
                const SizedBox(width: 6),
                Text(t(m.statusLabel), style: TextStyle(color: statusColor(m.status), fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              if (title.isNotEmpty) Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
              if (staff) Text(m.company ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: m.company == null ? Brand.idle : Brand.gold300, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 12, runSpacing: 3, children: [
                _fact(LucideIcons.gauge, '${fmt(m.speed)} ${m.speedUnit}'.trim()),
                _fact(LucideIcons.zap, '$eff% efficiency', color: effColor),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AnimatedBar(pct, height: 5, color: m.status == 'stopped' ? Brand.stopped : Brand.gold500)),
                const SizedBox(width: 8),
                Muted('${fmt(m.todayProduction)} / ${fmt(m.todayTarget)} ${m.outputUnit}', size: 11),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(LucideIcons.clock, size: 11, color: Brand.inkSoft),
                const SizedBox(width: 4),
                Muted(m.lastSeenAt == null ? 'No data yet' : 'Updated ${timeAgo(m.lastSeenAt!)}', size: 11),
              ]),
            ]),
          ),
          const Padding(padding: EdgeInsets.only(top: 26), child: Icon(LucideIcons.chevronRight, size: 18, color: Brand.inkSoft)),
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
                    Muted(r.qty > 1 ? '${r.qty} machines · Serial ${r.serials.isEmpty ? r.serial : r.serials.join(', ')}' : 'Serial ${r.serial}', size: 11),
                    Muted('Submitted ${timeAgo(r.createdAt)}', size: 11),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: glassTint(Brand.idle, 20),
                  child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.idle, letterSpacing: 0.6)),
                ),
              ]),
            ),
          ).reveal(1),
      ],
      const SectionTitle(LucideIcons.circlePlus, 'Available to register'),
      const Muted('Pick a Skylyf machine you own, enter its serial number, and we will connect it to your account.', size: 13),
      const SizedBox(height: 12),
      const StoreGrid(),
    ]);
  }
}
