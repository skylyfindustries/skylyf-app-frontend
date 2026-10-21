import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const _reasons = {
  'defective': 'Defective / not working',
  'wrong_part': 'Wrong part received',
  'damaged': 'Damaged in transit',
  'not_as_described': 'Not as described',
  'no_longer_needed': 'No longer needed',
  'other': 'Other',
};

Color _statusColor(String s) => switch (s) {
      'delivered' || 'approved' || 'received' || 'refunded' || 'exchanged' => Brand.running,
      'cancelled' || 'rejected' => Brand.stopped,
      _ => Brand.idle,
    };

String _label(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: glassTint(color, 20),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      );
}

/// The owner's spare-part orders: status, items, total, and Return / Exchange for delivered ones.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(myReturnsProvider).valueOrNull ?? const <ReturnRequest>[];
    Future<void> refresh() async {
      ref.invalidate(myOrdersProvider);
      ref.invalidate(myReturnsProvider);
      await ref.read(myOrdersProvider.future);
    }

    return GlassPage(
      title: 'My orders',
      child: asyncView(
        ref.watch(myOrdersProvider),
        (orders) => orders.isEmpty
            ? const Center(child: Muted('You have not ordered any parts yet', size: 14))
            : RefreshIndicator(
                onRefresh: refresh,
                color: Brand.gold500,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _OrderCard(orders[i], [for (final r in returns) if (r.orderId == orders[i].id) r]),
                ),
              ),
        onRetry: () => ref.invalidate(myOrdersProvider),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard(this.o, this.returns);
  final PartOrder o;
  final List<ReturnRequest> returns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = o.deliveredAt == null ? 0 : PartOrder.returnDays - DateTime.now().difference(o.deliveredAt!).inDays;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          _Pill(_label(o.status), _statusColor(o.status)),
        ]),
        const SizedBox(height: 2),
        Muted('${_day(o.createdAt)}  |  ${o.invoiceNo}  |  ${o.paid ? 'Paid' : 'Payment pending'}', size: 12),
        const Divider(height: 22, color: Brand.line),
        for (final i in o.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: i.photo == null
                      ? ColoredBox(color: Brand.gold500.withValues(alpha: 0.14), child: const Icon(LucideIcons.settings, size: 18, color: Brand.gold300))
                      : Image.network(photoUrl(i.photo!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(LucideIcons.settings, color: Brand.gold300)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
              const SizedBox(width: 8),
              Text('x${i.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        const Divider(height: 22, color: Brand.line),
        Row(children: [
          const Text('Total (incl. GST)', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('₹${fmt(o.total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        for (final r in returns) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(r.type == 'exchange' ? LucideIcons.repeat : LucideIcons.undo2, size: 16, color: Brand.gold300),
                const SizedBox(width: 8),
                Expanded(child: Text('${r.type == 'exchange' ? 'Exchange' : 'Return'} ${r.number}', style: const TextStyle(fontWeight: FontWeight.w800))),
                _Pill(_label(r.status), _statusColor(r.status)),
              ]),
              const SizedBox(height: 6),
              Text(r.items.map((i) => '${i.name} x${i.qty}').join(', '), style: const TextStyle(fontSize: 12.5)),
              Muted('${_reasons[r.reason] ?? r.reason}  |  ${_day(r.createdAt)}', size: 11.5),
              if (r.adminNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Skylyf: ${r.adminNote}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        if (o.canReturn) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.undo2, size: 18),
            label: Text('Return or exchange  ($left day${left == 1 ? '' : 's'} left)'),
            onPressed: () => _openSheet(context, ref),
          ),
        ],
      ]),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (_) => _ReturnSheet(o, returns),
    );
    if (done == true) {
      ref.invalidate(myReturnsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Request sent. We will review it shortly.')));
      }
    }
  }
}

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet(this.o, this.existing);
  final PartOrder o;
  final List<ReturnRequest> existing;
  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  String _type = 'return';
  String _reason = 'defective';
  final _note = TextEditingController();
  late final Map<String, int> _qty = {};
  bool _busy = false;
  String? _error;

  /// How many of a line can still be sent back (open requests already hold some).
  int _left(OrderLine l) {
    final used = widget.existing.where((r) => r.status != 'rejected').fold<int>(0, (s, r) => s + r.items.where((i) => i.partId == l.partId).fold<int>(0, (a, i) => a + i.qty));
    return l.qty - used;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final items = [for (final e in _qty.entries) if (e.value > 0) {'partId': e.key, 'qty': e.value}];
    if (items.isEmpty) return setState(() => _error = 'Choose at least one part');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).post('/orders/${widget.o.id}/returns', {
        'type': _type,
        'reason': _reason,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'items': items,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException ? e.message : 'Could not send the request. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.o.items.where((l) => _left(l) > 0).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Return or exchange ${widget.o.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Segments<String>(options: const [('return', 'Return for refund'), ('exchange', 'Exchange')], value: _type, onChanged: (v) => setState(() => _type = v)),
          const SizedBox(height: 6),
          Muted(_type == 'return' ? 'We take the parts back and refund you after inspection.' : 'We take the parts back and send a replacement.', size: 12),
          const SectionTitle(LucideIcons.packageOpen, 'Which parts?'),
          if (lines.isEmpty) const Muted('Everything in this order is already in a request.', size: 13),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Muted('${l.sku}  |  up to ${_left(l)}', size: 11.5),
                  ])),
                  IconButton(icon: const Icon(LucideIcons.minus, size: 18), onPressed: () => setState(() => _qty[l.partId] = ((_qty[l.partId] ?? 0) - 1).clamp(0, _left(l)))),
                  Text('${_qty[l.partId] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  IconButton(icon: const Icon(LucideIcons.plus, size: 18), onPressed: () => setState(() => _qty[l.partId] = ((_qty[l.partId] ?? 0) + 1).clamp(0, _left(l)))),
                ]),
              ),
            ),
          const SectionTitle(LucideIcons.messageSquare, 'Reason'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            radius: 16,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reason,
                isExpanded: true,
                dropdownColor: Brand.surface,
                items: [for (final e in _reasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _note, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'Add details (optional)')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || lines.isEmpty ? null : _send,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : Text(_type == 'return' ? 'Request return' : 'Request exchange'),
          ),
        ]),
      ),
    );
  }
}
