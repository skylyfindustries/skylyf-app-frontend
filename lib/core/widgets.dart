import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';

/// Loading / error (with retry) / data. Keeps showing old data while refreshing.
Widget asyncView<T>(AsyncValue<T> v, Widget Function(T) builder, {required VoidCallback onRetry}) {
  return v.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator(color: Brand.gold500)),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.cloudOff, size: 36, color: Brand.gold300),
            const SizedBox(height: 8),
            Text('$e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      ),
    ),
  );
}

/// Calls [onTick] every [every] while mounted (live machine data).
class Poll extends StatefulWidget {
  const Poll({super.key, required this.onTick, required this.child, this.every = const Duration(seconds: 15)});
  final VoidCallback onTick;
  final Widget child;
  final Duration every;

  @override
  State<Poll> createState() => _PollState();
}

class _PollState extends State<Poll> {
  late final Timer _t = Timer.periodic(widget.every, (_) => widget.onTick());

  @override
  void initState() {
    super.initState();
    _t; // start
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Full-screen page (outside the tab shell) with the glass background and a back arrow.
class GlassPage extends StatelessWidget {
  const GlassPage({super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), actions: actions),
          body: SafeArea(child: child),
        ),
      );
}

/// Pill segmented control on glass.
class Segments<T> extends StatelessWidget {
  const Segments({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(4),
        radius: 16,
        child: Row(children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: v == value ? navPill(12) : BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: v == value ? Brand.navy900 : Brand.ink)),
                ),
              ),
            ),
        ]),
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, this.label, {super.key});
  final String status, label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: glassTint(statusColor(status), 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusDot(status, size: 10, pulse: false),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
        ]),
      );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 12});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: size, color: const Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.w900));
}

/// Bottom padding so content clears the floating nav bar.
const navClearance = EdgeInsets.fromLTRB(16, 8, 16, 112);

String timeAgo(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  if (m < 1440) return '${m ~/ 60} h ago';
  return '${m ~/ 1440} d ago';
}

/// Staggered entrance: fade + slight rise. Use `.reveal(i)` on list items.
extension Reveal on Widget {
  Widget reveal([int index = 0]) => animate(delay: (60 * index).ms).fadeIn(duration: 380.ms).slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
}

/// Number that counts up from 0 (or its previous value) when it first appears / changes.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.suffix = '', this.decimals = 0});
  final num value;
  final TextStyle? style;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${decimals == 0 ? fmt(v) : v.toStringAsFixed(decimals)}$suffix', style: style),
      );
}

/// Thin progress bar that animates to its value.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar(this.value, {super.key, this.color = Brand.gold500, this.height = 8});
  final double value; // 0..1
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: height, backgroundColor: Brand.track, color: color),
        ),
      );
}

/// Circular gauge with the value in the middle (used for availability / performance / quality).
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.label, this.color = Brand.gold500, this.size = 86});
  final num value; // percent 0..100
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (value / 100).clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(value: v, strokeWidth: 9, strokeCap: StrokeCap.round, backgroundColor: Brand.track, color: color)),
              Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Muted(label, size: 12),
      ]);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.icon, this.text, {super.key, this.trailing});
  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: Brand.gold300),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Label on the left, value on the right (machine info sheets).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Muted(label, size: 13)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor))),
        ]),
      );
}

/// Field caption shown above an input (instead of a floating label / placeholder).
Widget above(Object label, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text('$label', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Brand.ink))),
        field,
      ],
    );

/// Filter chip in the bottom-navigation style: glass when off, cream glowing pill when selected.
class PillChip extends StatelessWidget {
  const PillChip(this.label, this.selected, this.onTap, {super.key, this.dot});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: selected ? navPill(22) : glassTint(Colors.white, 22),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot != null) ...[Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 7)],
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Brand.gold300 : Brand.ink)),
            ]),
          ),
        ),
      );
}
