import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Heart that pops (scale up, settle) and cross-fades to red when a part is liked. Reads and toggles the wishlist.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton(this.partId, {super.key, this.size = 24, this.backdrop = false});
  final String partId;
  final double size;
  final bool backdrop; // white circle behind the icon (on photos)

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.9).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = ref.watch(wishlistProvider).contains(widget.partId);
    final icon = ScaleTransition(
      scale: _pop,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: child)),
        child: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(liked),
          size: widget.size,
          color: liked ? Brand.stopped : Brand.inkSoft,
        ),
      ),
    );
    return InkResponse(
      radius: widget.size,
      onTap: () {
        if (!liked) _c.forward(from: 0);
        ref.read(wishlistProvider.notifier).toggle(widget.partId);
        final router = GoRouter.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: Brand.navy900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(children: [
              Icon(liked ? Icons.favorite_border : Icons.favorite, size: 20, color: liked ? Colors.white70 : Brand.stopped),
              const SizedBox(width: 10),
              Text(liked ? 'Removed from wishlist' : 'Added to wishlist', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            action: liked ? null : SnackBarAction(label: 'VIEW', textColor: Brand.gold500, onPressed: () => router.push('/wishlist')),
          ));
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: widget.backdrop ? Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle), child: icon) : icon,
      ),
    );
  }
}
