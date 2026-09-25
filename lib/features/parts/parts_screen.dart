import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Machine → Parts → Buy. The shop itself (catalog, checkout) is WooCommerce behind the backend.
class PartsScreen extends ConsumerStatefulWidget {
  const PartsScreen({super.key, this.machineId});
  final String? machineId;

  @override
  ConsumerState<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends ConsumerState<PartsScreen> {
  String? _machineId;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _machineId = widget.machineId;
  }

  @override
  void didUpdateWidget(PartsScreen old) {
    super.didUpdateWidget(old);
    if (widget.machineId != old.machineId) _machineId = widget.machineId;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final machines = ref.watch(machinesProvider).valueOrNull ?? const <Machine>[];
    final key = (machineId: _machineId, q: _q);
    final parts = ref.watch(partsProvider(key));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Parts'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            radius: 16,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: machines.any((m) => m.id == _machineId) ? _machineId : null,
                isExpanded: true,
                dropdownColor: Brand.surface,
                icon: const Icon(LucideIcons.chevronDown, color: Brand.gold300),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All machines')),
                  for (final m in machines) DropdownMenuItem(value: m.id, child: Text('${m.code} • ${m.typeName}')),
                ],
                onChanged: (v) => setState(() => _machineId = v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onSubmitted: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Search parts', prefixIcon: Icon(LucideIcons.search)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
      Expanded(
        child: asyncView(
          parts,
          (list) => list.isEmpty
              ? const Center(child: Muted('No parts found', size: 14))
              : ListView(padding: navClearance, children: [for (final p in list) _PartRow(p, t)]),
          onRetry: () => ref.invalidate(partsProvider(key)),
        ),
      ),
    ]);
  }
}

class _PartRow extends ConsumerWidget {
  const _PartRow(this.p, this.t);
  final Part p;
  final String Function(String) t;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Brand.gold500.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.settings, color: Brand.gold300)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Muted('${p.sku}  •  ₹${fmt(num.tryParse(p.price) ?? 0)}', size: 13),
              ]),
            ),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(84, 44)), onPressed: () => _buy(context, ref), child: Text(t('Buy'))),
          ]),
        ),
      );

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final qty = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Brand.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _QtySheet(p),
    );
    if (qty == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final o = await ref.read(apiProvider).post('/orders', {'items': [{'productId': p.id, 'quantity': qty}]});
      final url = o['checkoutUrl'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Order placed • ${o['orderId']}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _QtySheet extends StatefulWidget {
  const _QtySheet(this.p);
  final Part p;

  @override
  State<_QtySheet> createState() => _QtySheetState();
}

class _QtySheetState extends State<_QtySheet> {
  int _n = 1;

  @override
  Widget build(BuildContext context) {
    final unit = num.tryParse(widget.p.price) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Muted(widget.p.sku),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(onPressed: _n > 1 ? () => setState(() => _n--) : null, icon: const Icon(LucideIcons.minus)),
          SizedBox(width: 72, child: Text('$_n', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
          IconButton.filledTonal(onPressed: _n < 100 ? () => setState(() => _n++) : null, icon: const Icon(LucideIcons.plus)),
        ]),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context, _n), child: Text('Place order • ₹${fmt(unit * _n)}')),
      ]),
    );
  }
}
