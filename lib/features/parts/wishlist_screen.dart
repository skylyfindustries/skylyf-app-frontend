import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'like_button.dart';

/// Parts the user liked (heart on a part). Tap one to open its details.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(wishlistProvider); // removing a heart drops the row at once
    return GlassPage(
      title: 'Wishlist',
      child: asyncView(
        ref.watch(wishlistPartsProvider),
        (all) {
          final list = all.where((p) => liked.contains(p.id)).toList();
          if (list.isEmpty) return const Center(child: Muted('No liked parts yet. Tap the heart on a part.', size: 14));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = list[i];
              return GlassCard(
                padding: const EdgeInsets.all(12),
                onTap: () => context.push('/part/${p.id}'),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: p.image == null
                          ? ColoredBox(color: Brand.gold500.withValues(alpha: 0.14), child: const Icon(LucideIcons.settings, color: Brand.gold300))
                          : Image.network(photoUrl(p.image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(LucideIcons.settings, color: Brand.gold300)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Muted('${p.sku} • ${p.inStock ? 'In stock' : 'Out of stock'}', size: 12),
                      const SizedBox(height: 4),
                      Text('₹${fmt(p.price)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  LikeButton(p.id, size: 24),
                ]),
              );
            },
          );
        },
        onRetry: () => ref.invalidate(wishlistPartsProvider),
      ),
    );
  }
}
