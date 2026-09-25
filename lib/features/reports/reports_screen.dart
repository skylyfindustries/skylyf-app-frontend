import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/export.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _range = 'today', _kind = 'production';

  TableData _table(ReportData r) => (
        title: '$_kind report ($_range)',
        cols: ['Period', 'Value${r.unit.isEmpty ? '' : ' (${r.unit})'}'],
        rows: [
          for (final p in r.series) [p.label, '${p.value}'],
          for (final m in r.byMachine) ['Machine ${m.label}', '${m.value} ${m.unit}'],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final key = (range: _range, kind: _kind);
    final report = ref.watch(reportProvider(key));
    final kinds = [('production', t('Production')), ('downtime', t('Downtime')), ('performance', t('Machine Performance'))];

    return ListView(padding: navClearance, children: [
      Row(children: [
        Expanded(child: Text(t('Reports'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
        if (report.hasValue) ExportButton(() => _table(report.value!)),
      ]),
      const SizedBox(height: 12),
      Segments<String>(options: [('today', t('Today')), ('7d', t('7 Days')), ('30d', t('30 Days'))], value: _range, onChanged: (v) => setState(() => _range = v)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        for (final (k, label) in kinds)
          ChoiceChip(
            label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: _kind == k ? Brand.navy900 : Brand.ink)),
            selected: _kind == k,
            onSelected: (_) => setState(() => _kind = k),
            selectedColor: Brand.gold500,
            backgroundColor: Colors.white.withValues(alpha: 0.75),
            side: const BorderSide(color: Brand.line),
            showCheckmark: false,
          ),
      ]),
      const SizedBox(height: 14),
      // asyncView returns a box-less widget; give the loading/error states a fixed height inside the ListView.
      SizedBox(
        height: report.hasValue ? null : 240,
        child: asyncView(report, (r) => _Body(r, _kind, t), onRetry: () => ref.invalidate(reportProvider(key))),
      ),
    ]);
  }
}

class _Body extends StatelessWidget {
  const _Body(this.r, this.kind, this.t);
  final ReportData r;
  final String kind;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    if (r.series.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Muted('No data for this period', size: 14)));
    final perf = kind == 'performance';
    final unit = r.unit.isEmpty ? '' : ' ${r.unit}';
    return Column(children: [
      Row(children: [
        Expanded(child: _Stat(perf ? t('Average') : t('Total'), perf ? '${r.average}$unit' : '${fmt(r.total)}$unit')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(perf ? 'Best' : t('Average'), perf ? r.series.first.label : '${fmt(r.average)}$unit')),
      ]),
      const SizedBox(height: 12),
      if (!perf) GlassCard(padding: const EdgeInsets.fromLTRB(8, 18, 14, 8), child: SizedBox(height: 220, child: _Bars(r, kind == 'downtime' ? Brand.stopped : Brand.gold500))).reveal(1),
      if (kind == 'production' && r.byMachine.isNotEmpty) ...[
        const SectionTitle(LucideIcons.factory, 'Produced by each machine'),
        _ByMachine(r.byMachine).reveal(2),
      ],
      SectionTitle(LucideIcons.table, perf ? 'Uptime by machine' : 'Breakdown'),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          for (final p in r.series)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(width: 62, child: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (perf)
                  Expanded(child: AnimatedBar(p.value / 100, height: 8, color: p.value >= 85 ? Brand.running : p.value >= 60 ? Brand.idle : Brand.stopped))
                else
                  const Spacer(),
                SizedBox(width: 90, child: Text('${fmt(p.value)}$unit', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _ByMachine extends StatelessWidget {
  const _ByMachine(this.rows);
  final List<({String label, num value, String unit})> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<num>(1, (a, r) => r.value > a ? r.value : a);
    final sorted = [...rows]..sort((a, b) => b.value.compareTo(a.value));
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(children: [
        for (final r in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 52, child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              Expanded(child: AnimatedBar(r.value / max, height: 7)),
              SizedBox(width: 92, child: Text('${fmt(r.value)} ${r.unit}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            ]),
          ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Muted(label, size: 13),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        ]),
      );
}

class _Bars extends StatelessWidget {
  const _Bars(this.r, this.color);
  final ReportData r;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final step = math.max(1, (r.series.length / 6).ceil());
    final maxY = r.series.fold<num>(1, (a, p) => p.value > a ? p.value : a).toDouble();
    return BarChart(BarChartData(
      maxY: maxY * 1.15,
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Brand.line, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : Text(_short(v), style: const TextStyle(fontSize: 10, color: Brand.inkSoft)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i % step != 0 || i >= r.series.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.series[i].label, style: const TextStyle(fontSize: 10, color: Brand.inkSoft)));
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < r.series.length; i++)
          BarChartGroupData(x: i, barRods: [BarChartRodData(toY: r.series[i].value.toDouble(), color: color, width: r.series.length > 20 ? 6 : 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
      ],
    ));
  }

  String _short(double v) => v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)}M' : v >= 1e3 ? '${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)}k' : v.toStringAsFixed(0);
}
