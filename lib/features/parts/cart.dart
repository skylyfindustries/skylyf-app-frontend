import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';

typedef CartLine = ({Part part, int n});

/// The parts cart, shared by the Parts grid (add / stepper / badge) and the Cart page (checkout).
class CartNotifier extends Notifier<Map<String, CartLine>> {
  @override
  Map<String, CartLine> build() => {};

  int qty(Part p) => state[p.id]?.n ?? 0;

  /// n <= 0 removes the line; the most you can hold is the stock (max 100).
  void set(Part p, int n) {
    final next = {...state};
    if (n <= 0) {
      next.remove(p.id);
    } else {
      next[p.id] = (part: p, n: n.clamp(1, p.stock < 100 ? p.stock : 100));
    }
    state = next;
  }

  void clear() => state = {};
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, CartLine>>(CartNotifier.new);

/// Shown prices are before GST; the server adds it and is the source of truth (see GST_RATE in the backend).
const gstRate = 0.18;
