import 'package:fl_chart/fl_chart.dart';
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
import 'spec_view.dart';
import 'manage_machine.dart';
import 'set_goal_screen.dart';

class MachineDetailScreen extends ConsumerWidget {
  const MachineDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final machine = ref.watch(machineProvider(id));
    final role = ref.watch(roleProvider) ?? Role.customer;
    return GlassPage(
      title: machine.valueOrNull?.code ?? '',
      child: Poll(
        onTick: () => ref.invalidate(machineProvider(id)),
        child: asyncView(machine, (m) {
          final info = m.info;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Hero(m, t).reveal(0),
              const SizedBox(height: 12),
              _BasicDetails(m).reveal(1),
              const SizedBox(height: 14),
              const SectionTitle(LucideIcons.activity, 'Live stats').reveal(2),
              _MainStats(m, t).reveal(2),
              if (role.canSetProductionGoal)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/machine/$id/goal');
                      ref.invalidate(machineProvider(id));
                    },
                    icon: const Icon(LucideIcons.target, size: 18),
                    label: const Text('Set daily production goal'),
                  ),
                ),
              if (m.photos.isNotEmpty ||
                  m.description.isNotEmpty ||
                  m.productionSpeed.isNotEmpty ||
                  m.spec != null ||
                  m.serial.isNotEmpty ||
                  m.cupSize.isNotEmpty ||
                  m.paperRequired.isNotEmpty) ...[
                const SizedBox(height: 12),
                _About(m).reveal(3),
              ],
              if (role.canManageMachines) ...[
                const SizedBox(height: 12),
                ManageMachineCard(m).reveal(3),
              ],
              if (info != null) ...[
                const SectionTitle(
                  LucideIcons.chartSpline,
                  "Today's output",
                ).reveal(3),
                _Hourly(info.hourly, m.outputUnit).reveal(3),
                const SectionTitle(
                  LucideIcons.activity,
                  'Performance (OEE)',
                ).reveal(4),
                _Oee(info).reveal(4),
                const SectionTitle(
                  LucideIcons.clock,
                  'Run time vs downtime',
                ).reveal(5),
                _RunDown(info, m.outputUnit).reveal(5),
              ],
              SectionTitle(LucideIcons.layers, 'Shift production').reveal(6),
              _Shifts(m).reveal(6),
              if (info != null) ...[
                const SectionTitle(
                  LucideIcons.info,
                  'Machine details',
                ).reveal(7),
                _Details(m, info).reveal(7),
                const SectionTitle(
                  LucideIcons.history,
                  'Recent activity',
                ).reveal(8),
                _Timeline(info.events).reveal(8),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/machine/$id/maintenance'),
                      icon: const Icon(LucideIcons.wrench, size: 18),
                      label: Text(t('Maintenance')),
                    ),
                  ),
                  if (role.canBuyParts) const SizedBox(width: 12),
                  if (role.canBuyParts)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/parts?machineId=$id'),
                        icon: const Icon(LucideIcons.shoppingCart, size: 18),
                        label: Text(t('Parts')),
                      ),
                    ),
                ],
              ).reveal(9),
            ],
          );
        }, onRetry: () => ref.invalidate(machineProvider(id))),
      ),
    );
  }
}

class _BasicDetails extends StatelessWidget {
  const _BasicDetails(this.m);
  final Machine m;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Column(
      children: [
        InfoRow('Machine code', m.code),
        const Divider(height: 1, color: Brand.line),
        InfoRow('Type', m.typeName),
        const Divider(height: 1, color: Brand.line),
        InfoRow('Model', m.model.isEmpty ? '—' : m.model),
        const Divider(height: 1, color: Brand.line),
        InfoRow('Status', m.statusLabel),
        const Divider(height: 1, color: Brand.line),
        InfoRow('Output unit', m.outputUnit.isEmpty ? '—' : m.outputUnit),
        if (m.serial.isNotEmpty) ...[
          const Divider(height: 1, color: Brand.line),
          InfoRow('Serial number', m.serial),
        ],
      ],
    ),
  );
}

class _MainStats extends StatelessWidget {
  const _MainStats(this.m, this.t);
  final Machine m;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _Metric(
              LucideIcons.packageCheck,
              t('Production'),
              m.todayProduction,
              m.outputUnit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Metric(
              LucideIcons.target,
              t('Target'),
              m.todayTarget,
              m.outputUnit,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _Metric(
              LucideIcons.zap,
              t('Efficiency'),
              m.efficiency,
              '%',
              progress: m.efficiency / 100,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Metric(LucideIcons.gauge, t('Speed'), m.speed, m.speedUnit),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _Metric(
              LucideIcons.package,
              t('Packages complete'),
              m.todayPackages,
              'packages',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Metric(
              LucideIcons.play,
              t('Start count'),
              m.startCount,
              '',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _Metric(
              LucideIcons.square,
              t('Stop count'),
              m.stopCount,
              '',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Metric(
              LucideIcons.timer,
              t('Machine runtime'),
              m.machineRuntime,
              '',
            ),
          ),
        ],
      ),
    ],
  );
}

class _Hero extends ConsumerWidget {
  const _Hero(this.m, this.t);
  final Machine m;
  final String Function(String) t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(roleProvider)?.isStaff ?? false;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MachineArt(
                m.typeKey,
                photo: m.photos.firstOrNull,
                status: m.status,
                height: 190,
                radius: 0,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: StatusBadge(m.status, t(m.statusLabel)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.code,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Muted(
                  '${m.typeName}${m.model.isEmpty ? '' : ' • ${m.model}'}',
                  size: 14,
                ),
                if (staff)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      m.company ?? 'Unassigned',
                      style: TextStyle(
                        color: m.company == null ? Brand.idle : Brand.gold300,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.label, this.value, this.unit, {this.progress});
  final IconData icon;
  final String label, unit;
  final num value;
  final double? progress;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Brand.gold300),
            const SizedBox(width: 6),
            Muted(label, size: 13),
          ],
        ),
        const SizedBox(height: 8),
        CountUp(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        Muted(unit),
        if (progress != null) ...[
          const SizedBox(height: 8),
          AnimatedBar(progress!, height: 6),
        ],
      ],
    ),
  );
}

class _Oee extends StatelessWidget {
  const _Oee(this.i);
  final MachineInfo i;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Ring(
              value: i.availability,
              label: 'Availability',
              color: Brand.running,
            ),
            Ring(
              value: i.performance,
              label: 'Performance',
              color: Brand.gold500,
            ),
            Ring(value: i.quality, label: 'Quality', color: Brand.navy500),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Brand.goldSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.badgeCheck,
                size: 18,
                color: Brand.gold300,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Overall equipment effectiveness',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              CountUp(
                i.oee,
                suffix: '%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Brand.gold300,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hourly extends StatelessWidget {
  const _Hourly(this.data, this.unit);
  final List<num> data;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<num>(1, (a, b) => b > a ? b : a).toDouble();
    const startHour = 0;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 20, 18, 8),
      child: SizedBox(
        height: 170,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxV * 1.3,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxV * 1.3 / 3,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Brand.line, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxV * 1.3 / 3,
                  getTitlesWidget: (v, meta) => v == meta.max
                      ? const SizedBox()
                      : Text(
                          fmt(v),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Brand.inkSoft,
                          ),
                        ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, _) => v.toInt() % 3 == 0
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${(v.toInt() + startHour).toString().padLeft(2, '0')}h',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Brand.inkSoft,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, v) in data.indexed)
                    FlSpot(i.toDouble(), v.toDouble()),
                ],
                isCurved: true,
                curveSmoothness: 0.28,
                color: Brand.gold500,
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 3.5,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: Brand.gold500,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Brand.gold500.withValues(alpha: 0.32),
                      Brand.gold500.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunDown extends StatelessWidget {
  const _RunDown(this.i, this.unit);
  final MachineInfo i;
  final String unit;

  String _hm(int m) => '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';

  @override
  Widget build(BuildContext context) {
    final total = (i.runtimeMin + i.downtimeMin).clamp(1, 1 << 30);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: i.runtimeMin / total),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: (v * 1000).round().clamp(1, 999),
                      child: const ColoredBox(color: Brand.running),
                    ),
                    Expanded(
                      flex: ((1 - v) * 1000).round().clamp(1, 999),
                      child: const ColoredBox(color: Brand.stopped),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _legend(Brand.running, 'Running', _hm(i.runtimeMin)),
              _legend(Brand.stopped, 'Downtime', _hm(i.downtimeMin)),
              _legend(Brand.idle, 'Rejects', '${fmt(i.rejects)} $unit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Muted(label, size: 12),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    ),
  );
}

class _Shifts extends StatelessWidget {
  const _Shifts(this.m);
  final Machine m;

  @override
  Widget build(BuildContext context) {
    final shifts = m.shifts ?? const <String, num>{};
    final max = shifts.values.fold<num>(1, (a, b) => b > a ? b : a);
    const labels = {
      'A': '06:00 – 14:00',
      'B': '14:00 – 22:00',
      'C': '22:00 – 06:00',
    };
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          for (final s in const ['A', 'B', 'C'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Shift $s',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Muted(labels[s]!, size: 11),
                      const Spacer(),
                      CountUp(
                        shifts[s] ?? 0,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Muted(m.outputUnit, size: 11),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedBar((shifts[s] ?? 0) / max, height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Photos and product details entered by Skylyf in the dashboard.
class _About extends StatelessWidget {
  const _About(this.m);
  final Machine m;

  @override
  Widget build(BuildContext context) {
    final rows = [
      if (m.serial.isNotEmpty) ('Serial number', m.serial),
      if ((m.price ?? 0) > 0) ('Price', '₹${fmt(m.price!)}'),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.description.isNotEmpty) ...[
            Text(m.description, style: const TextStyle(fontSize: 14)),
          ],
          const Divider(height: 18, color: Brand.line),
          SpecView(
            typeKey: m.typeKey,
            spec: m.spec,
            speedText: m.productionSpeed,
            sizeText: m.cupSize,
            paperText: m.paperRequired,
          ),
          for (final r in rows) ...[
            const Divider(height: 18, color: Brand.line),
            InfoRow(r.$1, r.$2),
          ],
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details(this.m, this.i);
  final Machine m;
  final MachineInfo i;

  @override
  Widget build(BuildContext context) {
    final warranty = DateTime.tryParse(i.warrantyUntil);
    final active = warranty != null && warranty.isAfter(DateTime.now());
    final next = DateTime.tryParse(i.nextService);
    final days = next?.difference(DateTime.now()).inDays;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        children: [
          InfoRow('Model', m.model),
          const Divider(height: 1, color: Brand.line),
          InfoRow('Serial number', i.serial),
          const Divider(height: 1, color: Brand.line),
          InfoRow('Installed on', i.installedOn),
          const Divider(height: 1, color: Brand.line),
          InfoRow(
            'Warranty',
            active
                ? 'Active until ${i.warrantyUntil}'
                : 'Expired ${i.warrantyUntil}',
            valueColor: active ? Brand.running : Brand.stopped,
          ),
          const Divider(height: 1, color: Brand.line),
          InfoRow('Last service', i.lastService),
          const Divider(height: 1, color: Brand.line),
          InfoRow(
            'Next service',
            days == null
                ? i.nextService
                : '${i.nextService}  (${days > 0 ? 'in $days days' : 'due now'})',
            valueColor: days != null && days < 30 ? Brand.idle : null,
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.events);
  final List<MachineEvent> events;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
    child: Column(
      children: [
        for (final (i, e) in events.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    e.time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Brand.inkSoft,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: statusColor(e.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != events.length - 1)
                      Expanded(child: Container(width: 2, color: Brand.line)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      e.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
