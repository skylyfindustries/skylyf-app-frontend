import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'cart.dart';
import 'parts_screen.dart' show QtyStepper;

/// Checkout. The order is placed for the signed-in owner's company: the server takes the company from the login token
/// (nothing about it is sent from here), stamps the invoice with it and takes the stock.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _placed; // the order the server created

  Future<void> _place() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final lines = ref.read(cartProvider).values;
      final o = await ref.read(apiProvider).post('/orders', {
        'items': [for (final e in lines) {'productId': e.part.id, 'quantity': e.n}]
      }) as Map<String, dynamic>;
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(partsProvider); // stock changed
      if (mounted) setState(() => _placed = o);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not place the order. Try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_placed != null) return _Done(_placed!);
    final cart = ref.watch(cartProvider);
    final lines = cart.values.toList();
    final me = ref.watch(meProvider).valueOrNull;
    final sub = lines.fold<num>(0, (s, e) => s + e.part.price * e.n);
    final gst = sub * gstRate;

    return GlassPage(
      title: 'Cart',
      child: lines.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(20), decoration: glassTint(Brand.gold500, 60), child: const Icon(LucideIcons.shoppingCart, size: 34, color: Brand.gold300)),
                const SizedBox(height: 14),
                const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Muted('Add parts from the Parts page.', size: 13),
                const SizedBox(height: 16),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(180, 46)), onPressed: () => context.pop(), child: const Text('Browse parts')),
              ]),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              for (final e in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: e.part.image == null
                              ? ColoredBox(color: Brand.gold500.withValues(alpha: 0.14), child: const Icon(LucideIcons.settings, color: Brand.gold300))
                              : Image.network(photoUrl(e.part.image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(LucideIcons.settings, color: Brand.gold300)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.part.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Muted('${e.part.sku} • ₹${fmt(e.part.price)} each', size: 12),
                          const SizedBox(height: 6),
                          QtyStepper(qty: e.n, onQty: (n) => ref.read(cartProvider.notifier).set(e.part, n)),
                        ]),
                      ),
                      Text('₹${fmt(e.part.price * e.n)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                  ),
                ),
              const SectionTitle(LucideIcons.building2, 'Billed to'),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me?.company ?? '…', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if ((me?.address ?? '').isNotEmpty) Muted(me!.address, size: 12),
                  if ((me?.gstin ?? '').isNotEmpty) Muted('GSTIN ${me!.gstin}', size: 12),
                ]),
              ),
              const SectionTitle(LucideIcons.receipt, 'Summary'),
              GlassCard(
                child: Column(children: [
                  _sum('Subtotal', sub),
                  const SizedBox(height: 6),
                  _sum('GST (${(gstRate * 100).round()}%)', gst),
                  const Divider(height: 22, color: Brand.line),
                  _sum('Total', sub + gst, bold: true),
                ]),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _place,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : Text('Place order • ₹${fmt(sub + gst)}'),
              ),
              const SizedBox(height: 8),
              const Center(child: Muted('An invoice is created with your order. You will be contacted for payment and delivery.', size: 11)),
            ]),
    );
  }

  Widget _sum(String label, num v, {bool bold = false}) => Row(children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 14)),
        const Spacer(),
        Text('₹${fmt(v)}', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 14)),
      ]);
}

class _Done extends StatelessWidget {
  const _Done(this.order);
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) => GlassPage(
        title: 'Order placed',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(22), decoration: glassTint(Brand.running, 60), child: const Icon(LucideIcons.check, size: 40, color: Brand.running)),
              const SizedBox(height: 16),
              const Text('Thank you!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Order ${order['number']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Muted('Invoice ${order['invoiceNo']} • ₹${fmt(order['total'])} incl. GST', size: 13),
              const SizedBox(height: 22),
              FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(220, 48)), onPressed: () => context.go('/parts'), child: const Text('Continue shopping')),
            ]),
          ),
        ),
      );
}
