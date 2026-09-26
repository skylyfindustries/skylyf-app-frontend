import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/feedback.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'cart.dart';

/// Machine → Parts → cart → order. The catalog (photos, prices, stock) is managed in the dashboard.
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
    final cart = ref.watch(cartProvider);
    final count = cart.values.fold(0, (s, e) => s + e.n);

    return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t('Parts'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              _JumpOnIncrease(
                value: count,
                child: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: Brand.gold500,
                textColor: Brand.navy900,
                child: IconButton(tooltip: 'Cart', icon: const Icon(LucideIcons.shoppingCart), onPressed: () => context.push('/cart')),
                ),
              ),
            ]),
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
            const SizedBox(height: 10),
          ]),
        ),
        Expanded(
          child: asyncView(
            parts,
            (list) => list.isEmpty
                ? const Center(child: Muted('No parts found', size: 14))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.66),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _PartCard(list[i], qty: cart[list[i].id]?.n ?? 0, onQty: (n) => ref.read(cartProvider.notifier).set(list[i], n)),
                  ),
            onRetry: () => ref.invalidate(partsProvider(key)),
          ),
        ),
    ]);
  }
}

/// Hops twice (getting smaller) every time [value] goes up, e.g. the cart icon when a part is added. Going down does nothing.
class _JumpOnIncrease extends StatefulWidget {
  const _JumpOnIncrease({required this.value, required this.child});
  final int value;
  final Widget child;
  @override
  State<_JumpOnIncrease> createState() => _JumpOnIncreaseState();
}

class _JumpOnIncreaseState extends State<_JumpOnIncrease> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(_JumpOnIncrease old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    return super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, -16 * math.sin(_c.value * 2 * math.pi).abs() * (1 - _c.value)), child: child),
      );
}

class _PartCard extends StatelessWidget {
  const _PartCard(this.p, {required this.qty, required this.onQty});
  final Part p;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: Brand.gold500.withValues(alpha: 0.14), child: const Center(child: Icon(LucideIcons.settings, size: 36, color: Brand.gold300)));
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(fit: StackFit.expand, children: [
              p.image == null ? placeholder : Image.network(photoUrl(p.image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
              if (!p.inStock) Container(color: Colors.white70, alignment: Alignment.center, child: const Text('Out of stock', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.stopped))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2)),
            const SizedBox(height: 2),
            Muted(p.sku, size: 11),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('₹${fmt(p.price)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              if (p.inStock) qty == 0 ? _AddButton(onTap: () => onQty(1)) : QtyStepper(qty: qty, onQty: onQty),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: glassTint(Brand.gold500, 20, true),
          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Brand.navy900)),
        ),
      );
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({required this.qty, required this.onQty});
  final int qty;
  final ValueChanged<int> onQty;
  @override
  Widget build(BuildContext context) => Container(
        decoration: glassTint(Brand.gold500, 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: () => onQty(qty - 1), borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.all(6), child: Icon(LucideIcons.minus, size: 14))),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          InkWell(onTap: () => onQty(qty + 1), borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.all(6), child: Icon(LucideIcons.plus, size: 14))),
        ]),
      );
}
