import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_widgets.dart';
import 'stages.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _long(DateTime d) => '${_wdLong[d.weekday - 1]}, ${d.day} ${_mon[d.month - 1]} ${d.year}';
bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Solid white card so text stays readable on the cream background.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => GlassCard(radius: 22, padding: padding, child: child);
}

/// Owner: give technicians their machines for a day. Only machines registered to my company can be picked.
class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key, this.embedded = true});
  final bool embedded; // bottom-tab page (own title row, clears the floating nav bar) vs. a pushed page with a back arrow

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  DateTime _day = DateTime.now();

  String get _date => _ymd(_day);

  Future<void> _pickDay() async {
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => _day = d);
  }

  Future<void> _assign() async {
    final saved = await showFormSheet<bool>(context, _AssignSheet(_day));
    if (saved == true) ref.invalidate(assignmentsProvider(_date));
  }

  Future<void> _remove(Assignment a) async {
    await guarded(
      context,
      title: 'Remove ${a.code}',
      confirm: '${a.technician} will no longer see this machine for ${_long(_day)}.',
      action: 'Yes, remove',
      danger: true,
      success: '${a.code} was removed from the day.',
      run: () async {
        await ref.read(apiProvider).delete('/assignments/${a.id}');
        ref.invalidate(assignmentsProvider(_date));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(assignmentsProvider(_date));
    final content = Column(children: [
      if (widget.embedded)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daily assignments', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Muted(_long(_day), size: 13),
            ])),
            FilledButton.icon(
              onPressed: _assign,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Assign'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 18)),
            ),
          ]),
        ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: _DayStrip(day: _day, onPick: (d) => setState(() => _day = d), onCalendar: _pickDay)),
      Expanded(
        child: asyncView(
          list,
          (rows) => ListView(padding: widget.embedded ? navClearance : const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            _Stats(rows),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              _Empty(day: _day, onAssign: _assign)
            else
              for (final (i, e) in _byTechnician(rows).entries.indexed) Padding(padding: const EdgeInsets.only(bottom: 14), child: _TechnicianCard(name: e.key, rows: e.value, onHistory: (a) => showAssignmentHistory(context, ref, a, canSetStage: true), onRemove: _remove)).reveal(i),
          ]),
          onRetry: () => ref.invalidate(assignmentsProvider(_date)),
        ),
      ),
    ]);
    return widget.embedded
        ? content
        : GlassPage(title: 'Daily assignments', actions: [IconButton(tooltip: 'Assign machines', icon: const Icon(LucideIcons.plus), onPressed: _assign)], child: content);
  }

  Map<String, List<Assignment>> _byTechnician(List<Assignment> rows) {
    final m = <String, List<Assignment>>{};
    for (final a in rows) {
      m.putIfAbsent(a.technician, () => []).add(a);
    }
    return m;
  }
}

/// Week strip around the selected day; the calendar button jumps to any date.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.day, required this.onPick, required this.onCalendar});
  final DateTime day;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = -3; i <= 3; i++) day.add(Duration(days: i))];
    final today = DateTime.now();
    return Row(children: [
      Expanded(
        child: _Card(
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            for (final d in days)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: _same(d, day) ? navPill(16) : BoxDecoration(borderRadius: BorderRadius.circular(16)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_wd[d.weekday - 1], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _same(d, day) ? Brand.navy900 : Brand.inkSoft)),
                      const SizedBox(height: 2),
                      Text('${d.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _same(d, day) ? Brand.navy900 : Brand.ink)),
                      const SizedBox(height: 3),
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: _same(d, today) ? (_same(d, day) ? Brand.navy900 : Brand.gold500) : Colors.transparent)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      IconButton.filledTonal(
        tooltip: 'Pick a date',
        onPressed: onCalendar,
        icon: const Icon(LucideIcons.calendarDays, size: 22),
        style: IconButton.styleFrom(minimumSize: const Size(52, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))).copyWith(backgroundBuilder: glassButton(18)),
      ),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.rows);
  final List<Assignment> rows;

  Widget _tile(IconData icon, String label, String value, Color color) => Expanded(
        child: _Card(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(7), decoration: glassTint(color, 10), child: Icon(icon, size: 16, color: color)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final done = rows.where((a) => a.done).length;
    return Row(children: [
      _tile(LucideIcons.factory, 'Machines', '${rows.length}', Brand.navy500),
      const SizedBox(width: 10),
      _tile(LucideIcons.circleCheck, 'Done', '$done', Brand.running),
      const SizedBox(width: 10),
      _tile(LucideIcons.hardHat, 'Technicians', '${rows.map((a) => a.technician).toSet().length}', Brand.gold300),
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.day, required this.onAssign});
  final DateTime day;
  final VoidCallback onAssign;
  @override
  Widget build(BuildContext context) => _Card(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: Brand.goldSoft, shape: BoxShape.circle), child: const Icon(LucideIcons.calendarCheck, size: 34, color: Brand.gold300)),
          const SizedBox(height: 16),
          const Text('Nothing assigned', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted('Give your technicians their machines for ${_wdLong[day.weekday - 1]}, ${day.day} ${_mon[day.month - 1]}.', size: 13),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: onAssign, icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Assign machines')),
        ]),
      );
}

/// One technician: header with progress, then a table of their machines (machine / status / actions).
class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.name, required this.rows, required this.onHistory, required this.onRemove});
  final String name;
  final List<Assignment> rows;
  final void Function(Assignment) onHistory;
  final Future<void> Function(Assignment) onRemove;

  static const _head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Brand.inkSoft);

  @override
  Widget build(BuildContext context) {
    final done = rows.where((a) => a.done).length;
    final all = done == rows.length;
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: Brand.goldSoft, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.gold300))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Muted('$done of ${rows.length} done', size: 12),
            ])),
            SizedBox(
              width: 88,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: rows.isEmpty ? 0 : done / rows.length),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: v, minHeight: 7, color: all ? Brand.running : Brand.gold500, backgroundColor: Brand.track)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Brand.line),
        const Padding(padding: EdgeInsets.fromLTRB(0, 8, 8, 6), child: Row(children: [Expanded(child: Text('MACHINE', style: _head)), SizedBox(width: 92, child: Text('STATUS', style: _head)), SizedBox(width: 36)])),
        for (final (i, a) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, color: Brand.line),
          _Row(a, onHistory: () => onHistory(a), onRemove: () => onRemove(a)),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.a, {required this.onHistory, required this.onRemove});
  final Assignment a;
  final VoidCallback onHistory, onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.code, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, decoration: a.done ? TextDecoration.lineThrough : null, color: a.done ? Brand.inkSoft : Brand.ink)),
          if (a.machine.isNotEmpty) Text(a.machine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
          if (a.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [const Icon(LucideIcons.messageSquare, size: 12, color: Brand.gold300), const SizedBox(width: 4), Expanded(child: Text(a.note, style: const TextStyle(fontSize: 12, color: Brand.gold300)))])),
        ])),
        InkWell(
          onTap: onHistory,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(2), child: Row(mainAxisSize: MainAxisSize.min, children: [StagePill(a.status), const SizedBox(width: 2), const Icon(LucideIcons.chevronRight, size: 16, color: Brand.inkSoft)])),
        ),
        IconButton(tooltip: 'Remove', visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.trash2, size: 18, color: Brand.stopped), onPressed: onRemove),
      ]),
    );
  }
}

/// Full-height modal (same design as Add technician / Edit profile): technician, machines, note.
class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet(this.day);
  final DateTime day;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> with BusyError {
  final _note = TextEditingController();
  final _machines = <String>{};
  String? _techId;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await guarded(
      context,
      title: 'Assign machines',
      confirm: 'Assign ${_machines.length} machine${_machines.length == 1 ? '' : 's'} for ${_long(widget.day)}?',
      action: 'Yes, assign',
      success: 'The machines were assigned.',
      busy: (b) => setState(() => busy = b),
      run: () => ref.read(apiProvider).post('/assignments', {'date': _ymd(widget.day), 'technicianId': _techId!, 'machineIds': _machines.toList(), if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()}),
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  Widget _machineRow(Machine m) {
    final on = _machines.contains(m.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => on ? _machines.remove(m.id) : _machines.add(m.id)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: glassTint(on ? Brand.gold500 : Colors.white, 18, on),
          child: Row(children: [
            StatusDot(m.status, size: 10, pulse: false),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(m.name.isEmpty ? m.typeName : m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
            ])),
            Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, color: on ? Brand.gold500 : Brand.inkSoft),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(techniciansProvider);
    final machines = ref.watch(machinesProvider);
    final n = _machines.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom),
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        SheetHeader('Assign machines', 'For ${_long(widget.day)}'),
        const SheetTitle('Technician'),
        techs.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Brand.gold500))),
          error: (e, _) => Text('$e', style: const TextStyle(color: Brand.stopped)),
          data: (list) => list.isEmpty
              ? const Muted('Add a technician first (Profile → My technicians).', size: 13)
              : Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in list)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: Brand.goldSoft, child: Text(t.name.isEmpty ? '?' : t.name[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Brand.gold300))),
                      label: Text(t.name),
                      selected: _techId == t.id,
                      onSelected: (_) => setState(() => _techId = t.id),
                      showCheckmark: false,
                      selectedColor: Brand.gold500,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Brand.line),
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _techId == t.id ? Brand.navy900 : Brand.ink),
                    ),
                ]),
        ),
        SheetTitle('Machines${n > 0 ? '  ($n selected)' : ''}'),
        machines.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Brand.gold500))),
          error: (e, _) => Text('$e', style: const TextStyle(color: Brand.stopped)),
          data: (list) => list.isEmpty
              ? const Muted('No registered machines yet.', size: 13)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => setState(() => n == list.length ? _machines.clear() : _machines.addAll(list.map((m) => m.id))), child: Text(n == list.length ? 'Clear all' : 'Select all')),
                  ),
                  for (final m in list) _machineRow(m),
                ]),
        ),
        const SheetTitle('Note (optional)'),
        SheetField(controller: _note, label: 'Instructions for the technician', icon: LucideIcons.messageSquare, max: 300, lines: 2, cap: TextCapitalization.sentences),
        ErrorText(error),
        const SizedBox(height: 20),
        BusyButton(label: n == 0 ? 'Select machines' : 'Assign $n machine${n == 1 ? '' : 's'}', busy: busy, onPressed: _techId != null && n > 0 ? _save : null, icon: LucideIcons.check),
      ]),
    );
  }
}
