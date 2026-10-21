import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n.dart';
import '../../core/machine_art.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'home_extras.dart';

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final dash = ref.watch(dashboardProvider);
    Future<void> refresh() async {
      ref.invalidate(dashboardProvider);
      ref.invalidate(alertsProvider);
      await ref.read(dashboardProvider.future);
    }

    return Poll(
      onTick: () => ref.invalidate(dashboardProvider),
      child: RefreshIndicator(
        onRefresh: refresh,
        color: Brand.gold500,
        child: asyncView(
          dash,
          (d) => ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
            _Header(t: t).reveal(0),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: StatusCount('running', d.running, t('Running'))),
              const SizedBox(width: 10),
              Expanded(child: StatusCount('stopped', d.stopped, t('Stopped'))),
              const SizedBox(width: 10),
              Expanded(child: StatusCount('idle', d.idle, t('Idle'))),
            ]).reveal(1),
            const SizedBox(height: 12),
            _Production(d, t("Today's Production")).reveal(2),
            const SizedBox(height: 12),
            const ProductionGraph().reveal(2),
            const SizedBox(height: 12),
            ProductionGraph(kind: 'packages', title: 'Packages completed', total: d.packagesToday).reveal(2),
            const SizedBox(height: 12),
            const TechnicianCarousel().reveal(3),
            const SizedBox(height: 12),
            _Kpis(d.stats).reveal(3),
            if (d.stats.top.isNotEmpty) ...[
              const SectionTitle(LucideIcons.trendingUp, 'Top machines today').reveal(4),
              _TopMachines(d.stats.top).reveal(5),
            ],
            SectionTitle(LucideIcons.triangleAlert, t('Attention')).reveal(6),
            if (d.attention.isEmpty)
              GlassCard(child: Row(children: [const Icon(LucideIcons.circleCheck, color: Brand.running), const SizedBox(width: 10), Text(t('All machines OK'))])).reveal(6)
            else
              for (final (i, a) in d.attention.indexed) _AttentionRow(a, t).reveal(6 + i),
            const SizedBox(height: 12),
            const TechnicianStatusTable().reveal(8),
          ]),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.t});
  final String Function(String) t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final plants = ref.watch(plantsProvider).valueOrNull ?? const <Plant>[];
    final selected = ref.watch(selectedPlantProvider);
    final plantName = plants.where((p) => p.id == selected).firstOrNull?.name ?? (plants.length == 1 ? plants.first.name : plants.isEmpty ? '' : 'All plants');
    final open = ref.watch(alertsProvider).valueOrNull?.where((a) => a.status == 'open').length ?? 0;

    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Muted('${_greeting()}${me == null ? '' : ', ${me.name.split(' ').first}'}', size: 13),
          const SizedBox(height: 2),
          Text(me?.company ?? ' ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (plants.length > 1)
            PopupMenuButton<String?>(
              onSelected: (v) => ref.read(selectedPlantProvider.notifier).select(v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All plants')),
                for (final p in plants) PopupMenuItem(value: p.id, child: Text(p.name)),
              ],
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.mapPin, size: 14, color: Brand.gold300), const SizedBox(width: 4), Text(plantName, style: const TextStyle(color: Brand.gold300, fontWeight: FontWeight.w700)), const Icon(LucideIcons.chevronDown, size: 16, color: Brand.gold300)]),
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.mapPin, size: 14, color: Brand.gold300), const SizedBox(width: 4), Text(plantName, style: const TextStyle(color: Brand.gold300, fontWeight: FontWeight.w700))]),
        ]),
      ),
      GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/alerts'),
        child: Badge(isLabelVisible: open > 0, label: Text('$open'), backgroundColor: Brand.stopped, child: const Icon(LucideIcons.bell, size: 22)),
      ),
    ]);
  }
}

class StatusCount extends StatelessWidget {
  const StatusCount(this.status, this.n, this.label, {super.key});
  final String status, label;
  final int n;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(children: [
          StatusDot(status, size: 14),
          const SizedBox(height: 10),
          CountUp(n, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 4),
          Muted(label),
        ]),
      );
}

class _Production extends StatelessWidget {
  const _Production(this.d, this.label);
  final Dashboard d;
  final String label;

  @override
  Widget build(BuildContext context) {
    final good = d.progress >= 0.8;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Muted(label, size: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: glassTint((good ? Brand.running : Brand.idle), 20),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(good ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 14, color: good ? Brand.running : Brand.idle),
              const SizedBox(width: 4),
              Text(good ? 'On track' : 'Behind target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: good ? Brand.running : Brand.idle)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          CountUp(d.today, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
          Text('  /  ${fmt(d.target)}', style: const TextStyle(fontSize: 18, color: Brand.inkSoft)),
        ]),
        const SizedBox(height: 12),
        AnimatedBar(d.progress, color: Brand.gold500, height: 10),
        const SizedBox(height: 8),
        Muted('${(d.progress * 100).round()}% of daily target • ${fmt(d.target - d.today)} to go'),
      ]),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis(this.s);
  final Stats s;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, Widget value, Color color) => GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: glassTint(color, 12), child: Icon(icon, size: 20, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [value, Muted(label, size: 11)])),
          ]),
        );
    const big = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1);
    return Column(children: [
      Row(children: [
        Expanded(child: tile(LucideIcons.activity, 'Uptime', CountUp(s.uptime, suffix: '%', style: big), Brand.running)),
        const SizedBox(width: 10),
        Expanded(child: tile(LucideIcons.gauge, 'Efficiency', CountUp(s.efficiency, suffix: '%', style: big), Brand.gold300)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: tile(LucideIcons.timer, 'Downtime today', CountUp(s.downtimeMin, suffix: ' min', style: big), Brand.stopped)),
        const SizedBox(width: 10),
        Expanded(child: tile(LucideIcons.packageCheck, 'This week', CountUp(s.weekProduced, style: big), Brand.navy500)),
      ]),
    ]);
  }
}

class _TopMachines extends StatelessWidget {
  const _TopMachines(this.top);
  final List<TopMachine> top;

  @override
  Widget build(BuildContext context) {
    final max = top.fold<num>(1, (a, m) => m.value > a ? m.value : a);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(children: [
        for (final m in top)
          InkWell(
            onTap: () => context.push('/machine/${m.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(width: 56, height: 40, child: MachineArt(m.typeKey, photo: m.photo, height: 40, radius: 10)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(m.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('${fmt(m.value)} ${m.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                    const SizedBox(height: 6),
                    AnimatedBar(m.value / max, height: 6),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow(this.a, this.t);
  final Attention a;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          onTap: () => context.push('/machine/${a.machineId}'),
          child: Row(children: [
            StatusDot(a.status),
            const SizedBox(width: 12),
            Text(a.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(width: 12),
            Text(t(a.status == 'stopped' ? 'Stopped' : 'Idle'), style: TextStyle(color: statusColor(a.status), fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(LucideIcons.chevronRight, size: 20, color: Brand.inkSoft),
          ]),
        ),
      );
}
