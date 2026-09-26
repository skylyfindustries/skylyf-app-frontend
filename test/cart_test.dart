import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/features/parts/cart.dart';

void main() {
  test('cart: add, cap at stock, remove at zero, clear', () {
    final c = ProviderContainer();
    final n = c.read(cartProvider.notifier);
    final die = Part(id: 'a', name: 'Die', sku: 'D-1', price: 100, stock: 3);
    n.set(die, 1);
    n.set(die, 9); // only 3 in stock
    expect(c.read(cartProvider)['a']!.n, 3);
    n.set(die, 0);
    expect(c.read(cartProvider), isEmpty);
    n.set(die, 2);
    n.clear();
    expect(c.read(cartProvider), isEmpty);
  });
}
