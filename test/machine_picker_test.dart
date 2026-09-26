import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/features/auth/register_screen.dart';

void main() {
  testWidgets('owner picks machines from the dashboard catalog with a counter', (t) async {
    final counts = <String, int>{};
    final items = [
      CatalogItem.fromJson({'id': 'a', 'name': 'Paper Cup Machine', 'model': 'SKY-PC 180', 'typeKey': 'paper_cup', 'tagline': '', 'speed': 'Up to 180 cups/min', 'specs': <String>[]}),
      CatalogItem.fromJson({'id': 'b', 'name': 'Tissue Rewinder', 'model': 'SKY-TS 650', 'typeKey': 'tissue', 'tagline': '', 'speed': '', 'specs': <String>[]}),
    ];
    await t.pumpWidget(ProviderScope(
      overrides: [catalogProvider.overrideWith((ref) async => items)],
      child: MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (_, set) => MachinePicker(counts: counts, onChanged: () => set(() {}))))),
    ));
    await t.pump();
    expect(find.text('SKY-PC 180'), findsOneWidget);
    expect(find.text('SKY-TS 650'), findsOneWidget);

    await t.tap(find.byIcon(LucideIcons.plus).first);
    await t.pump();
    await t.tap(find.byIcon(LucideIcons.plus).first);
    await t.pump();
    expect(counts, {'a': 2});
    expect(find.text('2'), findsOneWidget);

    await t.tap(find.byIcon(LucideIcons.minus));
    await t.pump();
    await t.tap(find.byIcon(LucideIcons.minus));
    await t.pump();
    expect(counts, isEmpty);
  });
}
