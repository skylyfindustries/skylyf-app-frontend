import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Refresh everything an owner change can affect.
void refreshFleet(WidgetRef ref, {String? customerId}) {
  ref.invalidate(machinesProvider);
  ref.invalidate(customersProvider);
  ref.invalidate(overviewProvider);
  ref.invalidate(registrationsProvider);
  if (customerId != null) ref.invalidate(customerDetailProvider(customerId));
}

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => child,
    );

// =====================================================================
// Assign a machine to a customer (or back to the unassigned pool)
// =====================================================================
Future<void> showAssignMachine(BuildContext context, WidgetRef ref, Machine m) async {
  final done = await _sheet<bool>(context, _AssignSheet(m));
  if (done == true && context.mounted) {
    refreshFleet(ref);
    ref.invalidate(machineProvider(m.id));
  }
}

class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet(this.m);
  final Machine m;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  late String? _cid = widget.m.companyId;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).patch('/machines/${widget.m.id}', {'companyId': _cid});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <CustomerSummary>[];
    Widget option(String? id, String title, String sub, IconData icon) {
      final sel = _cid == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(color: sel ? Brand.goldSoft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? Brand.gold500 : Brand.line, width: sel ? 1.8 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _cid = id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(icon, color: Brand.gold300),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Muted(sub, size: 12)])),
                Icon(sel ? LucideIcons.circleCheck : LucideIcons.circle, color: sel ? Brand.gold300 : Brand.inkSoft),
              ]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Assign ${widget.m.code}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Muted('The customer will see this machine in their app. Only their own machines are ever shown to them.', size: 13),
          const SizedBox(height: 14),
          option(null, 'Unassigned', 'Keep in Skylyf stock, visible only to the owner', LucideIcons.warehouse),
          for (final c in customers) option(c.id, c.name, '${c.city} • ${c.machines} machines now', LucideIcons.building2),
          const SizedBox(height: 10),
          FilledButton(onPressed: _busy || _cid == widget.m.companyId ? null : _save, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : const Text('Save assignment')),
        ]),
      ),
    );
  }
}

// =====================================================================
// Add a machine to the fleet
// =====================================================================
Future<void> showAddMachine(BuildContext context, WidgetRef ref, {String? presetCustomerId}) async {
  final done = await _sheet<bool>(context, _AddSheet(presetCustomerId));
  if (done == true && context.mounted) {
    refreshFleet(ref, customerId: presetCustomerId);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Machine added')));
  }
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet(this.presetCustomerId);
  final String? presetCustomerId;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  final _form = GlobalKey<FormState>();
  final _serial = TextEditingController();
  final _code = TextEditingController();
  CatalogItem? _model;
  late String? _cid = widget.presetCustomerId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serial.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(apiProvider).post('/machines', {'catalogId': _model!.id, 'typeKey': _model!.typeKey, 'code': _code.text.trim(), 'serial': _serial.text.trim().toUpperCase(), 'companyId': _cid});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).valueOrNull ?? const <CatalogItem>[];
    final customers = ref.watch(customersProvider).valueOrNull ?? const <CustomerSummary>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add machine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            DropdownButtonFormField<CatalogItem>(
              initialValue: _model,
              isExpanded: true,
              dropdownColor: Brand.surface,
              decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(LucideIcons.factory)),
              items: [for (final c in catalog) DropdownMenuItem(value: c, child: Text('${c.model} • ${c.name}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _model = v),
              validator: (v) => v == null ? 'Choose a model' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Serial number', prefixIcon: Icon(LucideIcons.hash)),
              validator: (v) => (v == null || v.trim().length < 8) ? 'Enter the full serial number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Machine name (e.g. PC-12)', prefixIcon: Icon(LucideIcons.tag)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a short name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _cid,
              isExpanded: true,
              dropdownColor: Brand.surface,
              decoration: const InputDecoration(labelText: 'Assign to customer', prefixIcon: Icon(LucideIcons.building2)),
              items: [const DropdownMenuItem(value: null, child: Text('Unassigned (Skylyf stock)')), for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _cid = v),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
            const SizedBox(height: 18),
            FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : const Text('Add machine')),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Owner card on the machine detail screen
// =====================================================================
class ManageMachineCard extends ConsumerWidget {
  const ManageMachineCard(this.m, {super.key});
  final Machine m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = m.companyId != null;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (assigned ? Brand.running : Brand.idle).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(assigned ? LucideIcons.building2 : LucideIcons.warehouse, size: 20, color: assigned ? Brand.running : Brand.idle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Muted('Assigned to', size: 12), Text(m.company ?? 'Unassigned (Skylyf stock)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))])),
        ]),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: () => showAssignMachine(context, ref, m), icon: const Icon(LucideIcons.arrowRightLeft, size: 18), label: Text(assigned ? 'Change customer' : 'Assign to a customer')),
      ]),
    );
  }
}
