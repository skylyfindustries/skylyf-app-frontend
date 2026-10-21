import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Napkin production line: hour by hour for today, day by day for 1w / 2w / 3w. Animates on every switch.
class ProductionGraph extends ConsumerStatefulWidget {
  const ProductionGraph({super.key, this.kind = 'production', this.title = 'Napkin production', this.total});
  final String kind, title; // kind: a /reports kind ('production' | 'packages')
  final num? total; // shown next to the title (all machines, today)
  @override
  ConsumerState<ProductionGraph> createState() => _ProductionGraphState();
}

class _ProductionGraphState extends ConsumerState<ProductionGraph> {
  static const _ranges = [('today', 'Today'), ('7d', '1w'), ('14d', '2w'), ('21d', '3w')];
  String _range = 'today';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(reportProvider((range: _range, kind: widget.kind)));
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.total == null ? widget.title : '${widget.title} · ${fmt(widget.total!)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          for (final (k, label) in _ranges)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                selected: _range == k,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onSelected: (_) => setState(() => _range = k),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Center(child: Muted('Could not load production')),
            data: (r) {
              if (r.series.isEmpty) return const Center(child: Muted('No production yet'));
              final maxV = r.series.fold<num>(1, (a, p) => p.value > a ? p.value : a).toDouble() * 1.3;
              final step = (r.series.length / 5).ceil();
              return LineChart(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                LineChartData(
                  minY: 0,
                  maxY: maxV,
                  gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxV / 3, getDrawingHorizontalLine: (_) => const FlLine(color: Brand.line, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: maxV / 3, getTitlesWidget: (v, m) => v == m.max ? const SizedBox() : Text(fmt(v), style: const TextStyle(fontSize: 10, color: Brand.inkSoft)))),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i % step != 0 || i >= r.series.length) return const SizedBox();
                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.series[i].label.replaceAll(':00', 'h'), style: const TextStyle(fontSize: 10, color: Brand.inkSoft)));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final (i, p) in r.series.indexed) FlSpot(i.toDouble(), p.value.toDouble())],
                      isCurved: true,
                      curveSmoothness: 0.28,
                      color: Brand.gold500,
                      barWidth: 3.5,
                      dotData: FlDotData(show: r.series.length <= 14),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.gold500.withValues(alpha: 0.32), Brand.gold500.withValues(alpha: 0)])),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Horizontal carousel: each technician with today's furthest stage (unassigned if none).
class TechnicianCarousel extends ConsumerWidget {
  const TechnicianCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const [];
    if (techs.isEmpty) return const SizedBox();
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: techs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: 130,
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Photo(techs[i].photo, 28),
              const SizedBox(height: 8),
              Text(techs[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Muted(techs[i].shift.isEmpty ? '—' : techs[i].shift, size: 11),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.path, this.radius);
  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Brand.goldSoft,
        backgroundImage: path == null ? null : NetworkImage(photoUrl(path!)),
        child: path == null ? Icon(LucideIcons.user, size: radius, color: Brand.gold300) : null,
      );
}

/// Today's status per technician, as a table (furthest stage reached across today's assignments).
class TechnicianStatusTable extends ConsumerWidget {
  const TechnicianStatusTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const [];
    final tasks = ref.watch(assignmentsProvider(today)).valueOrNull ?? const [];
    if (techs.isEmpty) return const SizedBox();
    const stage = ['assigned', 'started', 'running', 'done'];
    String statusOf(String id) {
      var best = -1;
      for (final a in tasks.where((a) => a.technicianId == id)) {
        final s = stage.indexOf(a.status);
        if (s > best) best = s;
      }
      return best < 0 ? 'unassigned' : stage[best];
    }

    Widget head(String t, {int flex = 1}) => Expanded(flex: flex, child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Brand.inkSoft)));
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [const SizedBox(width: 48), head('Technician', flex: 2), head('Shift', flex: 2), head('Status', flex: 2)]),
        const Divider(color: Brand.line),
        for (final t in techs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              _Photo(t.photo, 16),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Muted(t.shift.isEmpty ? '—' : t.shift, size: 12)),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Builder(builder: (_) {
                    final s = statusOf(t.id);
                    final c = switch (s) { 'running' || 'done' => Brand.running, 'started' || 'assigned' => Brand.idle, _ => Brand.inkSoft };
                    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: glassTint(c, 20), child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)));
                  }),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
