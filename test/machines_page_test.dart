import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/features/machines/machines_screen.dart';
import 'package:skylyf_machine/features/machines/store_grid.dart';

Machine machine(String code, String status, String type, {String name = '', num prod = 1000, num eff = 80}) => Machine.fromJson({
      'id': code, 'code': code, 'name': name, 'model': 'SKY-X', 'typeKey': type, 'typeName': type == 'paper_cup' ? 'Paper Cup' : 'Tissue', 'status': status,
      'speed': 180, 'speedUnit': 'Cups/min', 'outputUnit': 'Cups', 'todayProduction': prod, 'todayTarget': 5000, 'efficiency': eff,
      'lastSeenAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    });

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  final machines = [
    machine('PC-01', 'running', 'paper_cup', name: 'Cup Maker', prod: 4000, eff: 90),
    machine('PC-02', 'stopped', 'paper_cup', prod: 200, eff: 30),
    machine('T-01', 'running', 'tissue', prod: 2500, eff: 70),
    machine('T-02', 'idle', 'tissue', prod: 900, eff: 55),
  ];

  Future<void> openMine(WidgetTester t) async {
    tall(t);
    await t.pumpWidget(ProviderScope(
      overrides: [machinesProvider.overrideWith((ref) async => machines), registrationsProvider.overrideWith((ref) async => <Registration>[])],
      child: const MaterialApp(home: Scaffold(body: MachinesScreen())),
    ));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('My machines: search, status chips with counts, type filter, clear', (t) async {
    await openMine(t);
    for (final l in ['All (4)', 'Running (2)', 'Stopped (1)', 'Idle (1)']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(find.text('PC-01'), findsOneWidget);
    expect(find.text('T-02'), findsOneWidget);

    await t.tap(find.text('Stopped (1)'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('PC-02'), findsOneWidget);
    expect(find.text('PC-01'), findsNothing);
    expect(find.text('Clear'), findsOneWidget);

    await t.tap(find.text('Clear'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('PC-01'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 't-0'); // search is case-insensitive over code / name / model
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('T-01'), findsOneWidget);
    expect(find.text('PC-01'), findsNothing);
    expect(find.text('Running (1)'), findsOneWidget); // counts follow the search

    await t.enterText(find.byType(TextField).first, 'zzz');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('No machines match your filters'), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('PC-01'), findsOneWidget);
    await t.pump(const Duration(seconds: 1)); // let the row animations start and finish
    await t.pumpWidget(const SizedBox()); // dispose: stops the page's refresh timer
  });

  testWidgets('machine card shows the small details, with no backdrop card behind the picture', (t) async {
    await openMine(t);
    expect(find.text('Cup Maker · SKY-X'), findsOneWidget); // name + model
    expect(find.text('90% efficiency'), findsOneWidget);
    expect(find.text('180 Cups/min'), findsWidgets);
    expect(find.text('4,000 / 5,000 Cups'), findsOneWidget); // production / target
    expect(find.textContaining('Updated 5 min ago'), findsWidgets);
    // the picture sits directly on the card: no cream gradient box behind it
    final backdrop = find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.gradient is LinearGradient && (d.gradient as LinearGradient).colors.first == const Color(0xFFFFFFFF);
    });
    expect(backdrop, findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Register new: shop grid with search, type filter and a product page', (t) async {
    tall(t);
    final items = [
      StoreItem(id: 'a', name: 'Paper Cup Machine', model: 'SKY-PC 180', typeKey: 'paper_cup', typeName: 'Paper Cup', price: 450000, speed: '200 cups/min', cupSize: '3 oz – 16 oz', description: 'Fast and reliable'),
      StoreItem(id: 'b', name: 'Tissue Rewinder', model: 'SKY-TS 650', typeKey: 'tissue', typeName: 'Tissue', speed: '650 m/min'),
      StoreItem(id: 'c', name: 'Packaging Machine', model: 'SKY-PK 90', typeKey: 'other', typeName: 'Other'),
    ];
    await t.pumpWidget(ProviderScope(overrides: [storeProvider.overrideWith((ref) async => items)], child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StoreGrid())))));
    await t.pump();
    await t.pump();
    expect(find.text('3 machines'), findsOneWidget);
    expect(find.textContaining('in stock'), findsNothing); // owners never see stock
    expect(find.text('Register'), findsNWidgets(3));

    await t.tap(find.text('Tissue')); // type chip
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('1 machine'), findsOneWidget);
    expect(find.text('Tissue Rewinder'), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    await t.pump(const Duration(milliseconds: 400));

    await t.enterText(find.byType(TextField), 'packaging');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('1 machine'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'nothing like this');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('No machines match your search'), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.text('Paper Cup Machine')); // product page
    await t.pumpAndSettle();
    expect(find.text('Specifications'), findsOneWidget);
    expect(find.text('3 oz – 16 oz'), findsWidgets);
    expect(find.text('Register this machine'), findsOneWidget);
  });

  test('StoreItem builds the right registration body', () {
    expect(StoreItem(id: 'c1', name: 'x', model: '', typeKey: '', typeName: '').pick, {'catalogId': 'c1'});
    final fromCatalog = StoreItem.fromCatalog(CatalogItem(id: 'c', name: 'Cup', model: 'M', typeKey: 'paper_cup', tagline: 't', speed: '1', specs: []));
    expect(fromCatalog.typeName, 'Paper Cup');
  });
}
