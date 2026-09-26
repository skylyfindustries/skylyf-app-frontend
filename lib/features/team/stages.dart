import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Stages of a daily task, in order. The technician moves a task one stage forward at a time.
const stages = ['assigned', 'started', 'running', 'done'];

String stageLabel(String s) => switch (s) { 'assigned' => 'Assigned', 'started' => 'Started', 'running' => 'Running', _ => 'Completed' };

Color stageColor(String s) => switch (s) { 'assigned' => Brand.inkSoft, 'started' => Brand.idle, 'running' => Brand.navy500, _ => Brand.running };

IconData stageIcon(String s) => switch (s) { 'assigned' => LucideIcons.clock, 'started' => LucideIcons.play, 'running' => LucideIcons.cog, _ => LucideIcons.circleCheck };

/// The next stage, or null when the task is completed.
String? nextStage(String s) {
  final i = stages.indexOf(s);
  return i < 0 || i >= stages.length - 1 ? null : stages[i + 1];
}

String nextAction(String s) => switch (s) { 'assigned' => 'Start work', 'started' => 'Machine is running', _ => 'Mark completed' };

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String when(DateTime d) => '${d.day} ${_mon[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Four dots joined by a line: done stages filled, the current one highlighted.
class StageStepper extends StatelessWidget {
  const StageStepper(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final at = stages.indexOf(status);
    return Row(children: [
      for (final (i, s) in stages.indexed) ...[
        if (i > 0) Expanded(child: Container(height: 3, decoration: BoxDecoration(color: i <= at ? stageColor(status) : Brand.track, borderRadius: BorderRadius.circular(2)))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= at ? stageColor(status) : Colors.white,
              border: Border.all(color: i <= at ? stageColor(status) : Brand.line, width: 1.6),
            ),
            child: Icon(i < at ? LucideIcons.check : stageIcon(s), size: 14, color: i <= at ? Colors.white : Brand.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(stageLabel(s), style: TextStyle(fontSize: 10, fontWeight: i == at ? FontWeight.w800 : FontWeight.w500, color: i == at ? Brand.ink : Brand.inkSoft)),
        ]),
      ],
    ]);
  }
}

/// Small coloured pill with the current stage.
class StagePill extends StatelessWidget {
  const StagePill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = stageColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: glassTint(c, 20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(stageIcon(status), size: 13, color: c),
        const SizedBox(width: 5),
        Text(stageLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

void _refresh(WidgetRef ref, Assignment a) {
  ref.invalidate(assignmentsProvider(a.date));
  ref.invalidate(myTasksProvider);
}

/// Technician: confirm the next stage (with an optional note). The server records who did it and when.
Future<void> advanceAssignment(BuildContext context, WidgetRef ref, Assignment a) async {
  final next = nextStage(a.status);
  if (next == null) return;
  final note = TextEditingController();
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(nextAction(a.status)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.code}  ${a.machine}'.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Muted('${stageLabel(a.status)}  →  ${stageLabel(next)}', size: 13),
        const SizedBox(height: 14),
        above('Note (optional)', TextField(controller: note, maxLength: 300, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'e.g. Oil checked, heater replaced'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(stageLabel(next)))],
    ),
  );
  final text = note.text.trim();
  note.dispose();
  if (yes != true) return;
  if (!context.mounted) return;
  // the dialog above was the confirmation
  await guarded(
    context,
    title: nextAction(a.status),
    confirm: null,
    success: '${a.code} moved to ${stageLabel(next)}.',
    run: () async {
      await ref.read(apiProvider).patch('/assignments/${a.id}', {'status': next, if (text.isNotEmpty) 'note': text});
      _refresh(ref, a);
    },
  );
}

/// Everything that happened to a task: who moved it to which stage, and when. The owner can also reopen it here.
Future<void> showAssignmentHistory(BuildContext context, WidgetRef ref, Assignment a, {bool canSetStage = false}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _HistorySheet(a, canSetStage: canSetStage),
    );

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet(this.a, {required this.canSetStage});
  final Assignment a;
  final bool canSetStage;
  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  late Assignment a = widget.a;
  String? _error;

  Future<void> _set(String stage) async {
    final ok = await guarded(
      context,
      title: 'Change stage',
      confirm: 'Move ${a.code} to "${stageLabel(stage)}"?',
      action: 'Yes, move',
      success: '${a.code} moved to ${stageLabel(stage)}.',
      run: () async {
        await ref.read(apiProvider).patch('/assignments/${a.id}', {'status': stage});
        _refresh(ref, a);
      },
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final events = a.history;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), shrinkWrap: true, children: [
        Text('${a.code}  ${a.machine}'.trim(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Muted('${a.technician} · ${a.date}', size: 13),
        const SizedBox(height: 14),
        StageStepper(a.status),
        const SizedBox(height: 22),
        const Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        if (events.isEmpty) const Muted('No changes recorded yet.', size: 13),
        for (final (i, e) in events.reversed.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(width: 14, height: 14, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(shape: BoxShape.circle, color: stageColor(e.status))),
                if (i < events.length - 1) Expanded(child: Container(width: 2, color: Brand.line)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.from == null ? 'Assigned' : '${stageLabel(e.from!)}  →  ${stageLabel(e.status)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Muted('${e.byName.isEmpty ? 'Unknown' : e.byName}${e.role.isEmpty ? '' : ' (${e.role == 'technician' ? 'Technician' : 'Owner'})'} · ${when(e.at)}', size: 12),
                    if (e.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${e.note}”', style: const TextStyle(fontSize: 13, color: Brand.gold300))),
                  ]),
                ),
              ),
            ]),
          ),
        if (widget.canSetStage) ...[
          const Divider(color: Brand.line),
          const SizedBox(height: 6),
          const Text('Set stage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in stages)
              ChoiceChip(
                label: Text(stageLabel(s)),
                selected: a.status == s,
                onSelected: (_) => a.status == s ? null : _set(s),
                selectedColor: stageColor(s).withValues(alpha: 0.2),
                backgroundColor: Colors.white,
                side: BorderSide(color: a.status == s ? stageColor(s) : Brand.line),
              ),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
        ],
      ]),
    );
  }
}
