import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../staff/staff_screens.dart' show TicketCard;
import 'stages.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _nice(String ymd) {
  final p = ymd.split('-');
  return p.length == 3 ? '${int.parse(p[2])} ${_mon[int.parse(p[1]) - 1]}' : ymd;
}

/// Technician tab: the machines the owner gave me, each with its stage. I move a task forward as I work; the history is kept.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});
  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  String _tab = 'today'; // today | upcoming | earlier

  @override
  Widget build(BuildContext context) {
    final today = _ymd(DateTime.now());
    final requests = (ref.watch(staffTicketsProvider).valueOrNull ?? const <StaffTicket>[]).where((k) => k.status != 'done').toList();
    return asyncView(
      ref.watch(myTasksProvider),
      (all) {
        final groups = {
          'today': all.where((a) => a.date == today).toList(),
          'upcoming': all.where((a) => a.date.compareTo(today) > 0).toList(),
          'earlier': (all.where((a) => a.date.compareTo(today) < 0).toList()..sort((a, b) => b.date.compareTo(a.date))),
        };
        final shown = groups[_tab]!;
        return RefreshIndicator(
          color: Brand.gold500,
          onRefresh: () async {
            ref.invalidate(staffTicketsProvider);
            ref.invalidate(myTasksProvider);
            await ref.read(myTasksProvider.future);
          },
          child: ListView(padding: navClearance, physics: const AlwaysScrollableScrollPhysics(), children: [
            Text('My tasks', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Muted('Machines your owner gave you. Update the stage as you work.', size: 13),
            const SizedBox(height: 14),
            Segments<String>(
              options: [('today', 'Today (${groups['today']!.length})'), ('upcoming', 'Upcoming (${groups['upcoming']!.length})'), ('earlier', 'Earlier (${groups['earlier']!.length})')],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              GlassCard(
                alpha: 0.92,
                padding: const EdgeInsets.all(28),
                child: Column(children: [
                  Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Brand.goldSoft, shape: BoxShape.circle), child: const Icon(LucideIcons.clipboardCheck, size: 30, color: Brand.gold300)),
                  const SizedBox(height: 12),
                  Text(_tab == 'today' ? 'Nothing to run today' : _tab == 'upcoming' ? 'Nothing coming up' : 'No earlier tasks', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Muted('New machines appear here when your owner assigns them.', size: 13),
                ]),
              ),
            for (final (i, a) in shown.indexed) Padding(padding: const EdgeInsets.only(bottom: 12), child: TaskCard(a, showDate: _tab != 'today')).reveal(i),
            if (requests.isNotEmpty) ...[
              const SectionTitle(LucideIcons.wrench, 'Service requests'),
              for (final k in requests) TicketCard(k, actions: true),
            ],
          ]),
        );
      },
      onRetry: () => ref.invalidate(myTasksProvider),
    );
  }
}

/// One task: machine, stage stepper, the next action, and the history.
class TaskCard extends ConsumerWidget {
  const TaskCard(this.a, {super.key, this.showDate = false});
  final Assignment a;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = nextStage(a.status);
    return GlassCard(
      alpha: 0.92,
      blur: 8,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/machine/${a.machineId}'),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              if (a.machine.isNotEmpty) Text(a.machine, style: const TextStyle(fontSize: 13, color: Brand.inkSoft)),
              if (showDate) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(LucideIcons.calendar, size: 12, color: Brand.inkSoft), const SizedBox(width: 4), Muted(_nice(a.date), size: 12)])),
            ])),
            StagePill(a.status),
          ]),
        ),
        if (a.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(LucideIcons.messageSquare, size: 13, color: Brand.gold300), const SizedBox(width: 6), Expanded(child: Text(a.note, style: const TextStyle(fontSize: 13, color: Brand.gold300)))])),
        const SizedBox(height: 16),
        StageStepper(a.status),
        const SizedBox(height: 16),
        if (next != null)
          FilledButton.icon(onPressed: () => advanceAssignment(context, ref, a), icon: Icon(stageIcon(next), size: 18), label: Text(nextAction(a.status)))
        else
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.circleCheck, size: 18, color: Brand.running), SizedBox(width: 6), Text('Completed', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.running))]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: () => showAssignmentHistory(context, ref, a), icon: const Icon(LucideIcons.history, size: 16), label: Text('History (${a.history.length})')),
        ),
      ]),
    );
  }
}
