import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'cart.dart';
import 'like_button.dart';
import 'parts_screen.dart' show QtyStepper;

final _emoji = RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true);

/// Shop text sometimes carries emoji; the app uses icons instead.
String _clean(String s) => s.replaceAll(_emoji, '').trim();

/// Icon for a heading by what it is about (specifications, features, applications...).
IconData? _headIcon(String t) {
  final k = t.toLowerCase();
  if (k.contains('specification')) return LucideIcons.wrench;
  if (k.contains('feature')) return LucideIcons.listChecks;
  if (k.contains('application')) return LucideIcons.layers;
  if (k.contains('package')) return LucideIcons.package;
  if (k.contains('why')) return LucideIcons.badgeCheck;
  if (k.contains('description')) return LucideIcons.fileText;
  return null;
}

/// One spare part, laid out like the shop page: gallery, price + stock, short summary, then the description as
/// separate cards (Product Description, Key Features, Technical Specifications, Applications...). Add-to-cart is pinned.
class PartDetailScreen extends ConsumerWidget {
  const PartDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).values.fold(0, (s, e) => s + e.n);
    return GlassPage(
      title: 'Part details',
      actions: [
        LikeButton(id, size: 26),
        Badge(
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          backgroundColor: Brand.gold500,
          textColor: Brand.navy900,
          child: IconButton(icon: const Icon(LucideIcons.shoppingCart), onPressed: () => context.push('/cart')),
        ),
        const SizedBox(width: 8),
      ],
      child: asyncView(ref.watch(partProvider(id)), (p) => _Body(p), onRetry: () => ref.invalidate(partProvider(id))),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.p);
  final Part p;
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _pages = PageController();
  int _page = 0;
  bool _allTags = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Splits the description blocks into cards at every divider; the first heading of a card is its title.
  List<List<Map<String, dynamic>>> _sections(List<Map<String, dynamic>> blocks) {
    final out = <List<Map<String, dynamic>>>[[]];
    for (final b in blocks) {
      if (b['t'] == 'hr') {
        if (out.last.isNotEmpty) out.add([]);
      } else {
        out.last.add(b);
      }
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final qty = ref.watch(cartProvider)[p.id]?.n ?? 0;
    final images = p.images.isNotEmpty ? p.images : [if (p.image != null) p.image!];
    final off = p.onSale && p.regularPrice > p.price ? (100 - p.price / p.regularPrice * 100).round() : 0;
    final placeholder = ColoredBox(color: Brand.gold500.withValues(alpha: 0.14), child: const Center(child: Icon(LucideIcons.settings, size: 64, color: Brand.gold300)));
    final facts = <(IconData, String, String)>[
      (LucideIcons.barcode, 'SKU', p.sku),
      if (p.brands.isNotEmpty) (LucideIcons.badgeCheck, 'Brand', p.brands.join(', ')),
      if (p.categories.isNotEmpty) (LucideIcons.layoutGrid, 'Category', p.categories.join(', ')),
      for (final a in p.attributes) (LucideIcons.slidersHorizontal, a.name, a.value),
      if (p.weight.isNotEmpty) (LucideIcons.weight, 'Weight', p.weight),
      if (p.dimensions.isNotEmpty) (LucideIcons.ruler, 'Dimensions', p.dimensions),
    ].where((s) => s.$3.isNotEmpty).toList();
    final sections = _sections(p.content);
    final tags = _allTags ? p.tags : p.tags.take(10).toList();

    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          // gallery
          GlassCard(
            padding: EdgeInsets.zero,
            radius: 24,
            child: Column(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 300,
                  child: Stack(fit: StackFit.expand, children: [
                    images.isEmpty
                        ? placeholder
                        : PageView.builder(
                            controller: _pages,
                            itemCount: images.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (_, i) => ColoredBox(
                              color: Colors.white,
                              child: Hero(
                                tag: i == 0 ? 'part-${p.id}' : 'part-${p.id}-$i',
                                child: Image.network(photoUrl(images[i]), fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder),
                              ),
                            ),
                          ),
                    if (off > 0)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Brand.stopped, borderRadius: BorderRadius.circular(6)),
                          child: const Text('SALE!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ),
                  ]),
                ),
              ),
              if (images.length > 1)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: i == _page ? Brand.gold500 : Brand.line, width: i == _page ? 2 : 1),
                          ),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(photoUrl(images[i]), fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // title, price, stock
          Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${fmt(p.price)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            if (off > 0) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('₹${fmt(p.regularPrice)}', style: const TextStyle(fontSize: 15, color: Brand.inkSoft, decoration: TextDecoration.lineThrough))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: glassTint(Brand.running, 20), child: Text('$off% off', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.running))),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: glassTint(p.inStock ? Brand.running : Brand.stopped, 20),
              child: Text(p.inStock ? '${p.stock >= 999 ? 'In stock' : '${p.stock} in stock'}' : 'Out of stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.inStock ? Brand.running : Brand.stopped)),
            ),
          ]),
          const SizedBox(height: 2),
          const Muted('Price excludes GST (added at checkout)', size: 11),

          // short summary
          if (p.shortDescription.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(child: _Rich(p.shortDescription)),
          ],

          // quick facts
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: _Facts(facts)),
          ],

          // description, one card per section
          for (final sec in sections) _Section(sec),

          // tags
          if (p.tags.isNotEmpty) ...[
            const SectionTitle(LucideIcons.tag, 'Tags'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in tags) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: glassTint(Brand.gold500, 14), child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
              if (p.tags.length > 10)
                InkWell(
                  onTap: () => setState(() => _allTags = !_allTags),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: Text(_allTags ? 'Show less' : '+${p.tags.length - 10} more', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Brand.gold300))),
                ),
            ]),
          ],
        ]),
      ),

      // pinned buy bar
      if (p.inStock)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
          child: Row(children: [
            if (qty > 0) ...[
              QtyStepper(qty: qty, onQty: (n) => ref.read(cartProvider.notifier).set(p, n)),
              const SizedBox(width: 14),
              Expanded(child: FilledButton(onPressed: () => context.push('/cart'), child: Text('Go to cart • ₹${fmt(p.price * qty)}'))),
            ] else
              Expanded(child: FilledButton.icon(onPressed: () => ref.read(cartProvider.notifier).set(p, 1), icon: const Icon(LucideIcons.shoppingCart, size: 18), label: const Text('Add to cart'))),
          ]),
        ),
    ]);
  }
}

/// One description card: title (first heading), then paragraphs, bullet lists and tables in order.
class _Section extends StatelessWidget {
  const _Section(this.blocks);
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    final title = blocks.first['t'] == 'h' ? _clean(blocks.first['text'] as String) : null;
    final body = title == null ? blocks : blocks.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              if (_headIcon(title) != null)
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(10)), child: Icon(_headIcon(title), size: 20, color: Brand.gold300))
              else
                Container(width: 4, height: 22, decoration: BoxDecoration(color: Brand.gold500, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
          ],
          for (final b in body) _block(b),
        ]),
      ),
    );
  }

  Widget _block(Map<String, dynamic> b) {
    switch (b['t']) {
      case 'h' || 'sub':
        final t = _clean(b['text'] as String);
        final icon = _headIcon(t);
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 20, color: Brand.gold300), const SizedBox(width: 8)],
            Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.gold300))),
          ]),
        );
      case 'p':
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: _Rich(b['text'], size: 16));
      case 'ul':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in (b['items'] as List))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(LucideIcons.circleCheck, size: 18, color: Brand.running)),
                  const SizedBox(width: 10),
                  Expanded(child: _Rich('$i', size: 16)),
                ]),
              ),
          ]),
        );
      case 'table':
        return _Rows([for (final r in (b['rows'] as List)) [for (final c in (r as List)) '$c']], head: true);
      default:
        return const SizedBox();
    }
  }
}

/// Key facts with an icon per row (SKU, Brand, Category...).
class _Facts extends StatelessWidget {
  const _Facts(this.rows);
  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, r) in rows.indexed)
          Container(
            decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Brand.line))),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(10)), child: Icon(r.$1, size: 17, color: Brand.gold300)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.$2, style: const TextStyle(fontSize: 14, color: Brand.inkSoft)))),
              Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(r.$3, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
            ]),
          ),
      ]);
}

/// Table rows. With [head] the first row is a header (Specification | Details); rows alternate in tint.
class _Rows extends StatelessWidget {
  const _Rows(this.rows, {required this.head});
  final List<List<String>> rows;
  final bool head;

  /// Only a row that reads like a header (Specification | Details) is styled as one.
  bool get _hasHead => head && rows.isNotEmpty && const {'specification', 'specifications', 'parameter', 'property', 'item', 'feature'}.contains(rows.first.first.toLowerCase());

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, r) in rows.indexed)
          Container(
            decoration: BoxDecoration(
              color: _hasHead && i == 0 ? Brand.goldSoft : (i.isOdd ? Brand.gold500.withValues(alpha: 0.06) : null),
              border: i == 0 ? null : const Border(top: BorderSide(color: Brand.line)),
              borderRadius: _hasHead && i == 0 ? BorderRadius.circular(8) : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text(r.isNotEmpty ? _clean(r[0]) : '', style: TextStyle(fontSize: 14.5, fontWeight: _hasHead && i == 0 ? FontWeight.w800 : FontWeight.w500, color: _hasHead && i == 0 ? null : Brand.inkSoft))),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: Text(r.length > 1 ? _clean(r.sublist(1).join('  ')) : '', style: TextStyle(fontSize: 15, fontWeight: _hasHead && i == 0 ? FontWeight.w800 : FontWeight.w700))),
            ]),
          ),
      ]);
}

/// Text with **bold** runs (the server keeps bold as double asterisks).
class _Rich extends StatelessWidget {
  const _Rich(this.text, {this.size = 14.5});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    // icons only: drop any emoji that came in with the shop text
    final clean = _clean(text);
    final parts = clean.split('**');
    return Text.rich(
      TextSpan(
        style: TextStyle(height: 1.5, fontSize: size),
        children: [for (final (i, s) in parts.indexed) TextSpan(text: s, style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null)],
      ),
    );
  }
}
