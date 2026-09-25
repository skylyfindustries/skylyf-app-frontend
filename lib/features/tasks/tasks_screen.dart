import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const _statusLabel = {'open': 'Requested', 'in_progress': 'In progress', 'done': 'Resolved'};

Color statusTint(String s) => switch (s) { 'open' => Brand.idle, 'in_progress' => Brand.navy500, _ => Brand.running };

/// Create a task for a machine. The customer must choose one of the technicians the owner assigned to their company.
Future<bool> showServiceRequest(BuildContext context, {required String machineId}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _RequestSheet(machineId),
  );
  return ok == true;
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet(this.machineId);
  final String machineId;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _note = TextEditingController();
  String? _techId;
  String _priority = 'medium';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _techId != null && _note.text.trim().length >= 3;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(apiProvider).post('/machines/${widget.machineId}/maintenance', {'note': _note.text.trim(), 'technicianId': _techId!, 'priority': _priority});
      ref.invalidate(ticketsProvider(widget.machineId));
      ref.invalidate(tasksProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(techniciansProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Request service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Muted('Choose the technician who should handle this task.', size: 13),
          const SizedBox(height: 16),
          techs.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Brand.gold500))),
            error: (e, _) => Text('$e', style: const TextStyle(color: Brand.stopped)),
            data: (list) => list.isEmpty
                ? const GlassCard(child: Row(children: [Icon(LucideIcons.info, color: Brand.gold300), SizedBox(width: 12), Expanded(child: Text('No technician is assigned to your company yet. Please contact Skylyf.'))]))
                : Column(children: [for (final t in list) _TechTile(t, selected: _techId == t.id, onTap: () => setState(() => _techId = t.id))]),
          ),
          const SizedBox(height: 14),
          const Muted('Priority', size: 12),
          const SizedBox(height: 6),
          Segments<String>(options: const [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')], value: _priority, onChanged: (v) => setState(() => _priority = v)),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'What is the problem?', alignLabelWithHint: true),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _valid && !_busy ? _submit : null,
            icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : const Icon(LucideIcons.send, size: 18),
            label: const Text('Send request'),
          ),
        ]),
      ),
    );
  }
}

class _TechTile extends StatelessWidget {
  const _TechTile(this.t, {required this.selected, required this.onTap});
  final Technician t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Brand.goldSoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Brand.gold500 : Brand.line, width: selected ? 1.8 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(backgroundColor: Brand.gold500, child: Text(t.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.navy900))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)), Muted(t.phone, size: 12)])),
                Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, color: selected ? Brand.gold300 : Brand.inkSoft),
              ]),
            ),
          ),
        ),
      );
}

/// Every task my company raised, who it was given to, and how far along it is.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassPage(
        title: 'Service requests',
        child: asyncView(
          ref.watch(tasksProvider),
          (list) => RefreshIndicator(
            color: Brand.gold500,
            onRefresh: () async {
              ref.invalidate(tasksProvider);
              await ref.read(tasksProvider.future);
            },
            child: list.isEmpty
                ? ListView(children: const [SizedBox(height: 200), Center(child: Muted('No service requests yet', size: 14))])
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final (i, k) in list.indexed) _TaskCard(k).reveal(i)]),
          ),
          onRetry: () => ref.invalidate(tasksProvider),
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard(this.k);
  final StaffTicket k;

  @override
  Widget build(BuildContext context) {
    final step = switch (k.status) { 'open' => 0, 'in_progress' => 1, _ => 2 };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => context.push('/machine/${k.machineId}'),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(k.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusTint(k.status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel[k.status]!.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: statusTint(k.status))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(k.note, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(LucideIcons.hardHat, size: 15, color: Brand.gold300),
            const SizedBox(width: 6),
            Text(k.technician ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 10),
            Muted('${k.priority[0].toUpperCase()}${k.priority.substring(1)} priority • ${timeAgo(k.createdAt)}', size: 12),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: i <= step ? Brand.gold500 : Brand.track)),
              if (i < 2) Expanded(child: Container(height: 3, color: i < step ? Brand.gold500 : Brand.track)),
            ],
          ]),
          const SizedBox(height: 6),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Muted('Requested', size: 10), Muted('In progress', size: 10), Muted('Resolved', size: 10)]),
        ]),
      ),
    );
  }
}
