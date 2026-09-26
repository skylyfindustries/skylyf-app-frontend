import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/spec.dart';
import 'package:skylyf_machine/features/machines/spec_view.dart';

Map<String, dynamic> tissueJson() => {
      'size': {'min': 10, 'max': 30, 'unit': 'cm'},
      'speed': {'min': 500, 'max': 800, 'per': 'hr'},
    };

Map<String, dynamic> cupJson() => {
      'size': {'min': 2.5, 'max': 16, 'unit': 'oz'},
      'maxHeightMm': 137,
      'speed': {'min': 150, 'max': 200, 'per': 'min'},
      'gsm': {'min': 140, 'max': 350},
      'coating': 'either',
    };

void main() {
  test('ranges are written as min – max, one number when they are equal', () {
    final s = Spec.fromJson(cupJson())!;
    expect(s.sizeText, '2.5 – 16 oz');
    expect(s.speedText('paper_cup'), '150 – 200 cups/min');
    expect(s.gsmText, '140 – 350 GSM');
    final t = Spec.fromJson(tissueJson())!;
    expect(t.sizeText, '10 – 30 cm');
    expect(t.speedText('tissue'), '500 – 800 tissues/hr');
    expect(Spec.fromJson({'speed': {'min': 6000, 'max': 6000, 'per': 'day'}})!.speedText('paper_cup'), '6,000 cups/day');
    expect(Spec.fromJson(null), isNull);
    expect(Spec.fromJson({}), isNull);
  });

  test('speed converts between per minute, per hour and per day', () {
    final perMin = Spec.fromJson({'speed': {'min': 150, 'max': 200, 'per': 'min'}})!;
    expect(perMin.speedIn('min'), (150, 200));
    expect(perMin.speedIn('hr'), (9000, 12000));
    expect(perMin.speedIn('day'), (216000, 288000));
    final perHr = Spec.fromJson({'speed': {'min': 600, 'max': 1200, 'per': 'hr'}})!;
    expect(perHr.speedIn('min'), (10, 20));
    expect(perHr.speedIn('day'), (14400, 28800));
    expect(Spec.fromJson({'size': {'min': 1, 'max': 2, 'unit': 'oz'}})!.speedIn('min'), isNull); // no speed entered
  });

  test('labels follow the machine type', () {
    expect(sizeLabelFor('paper_cup'), 'Cup size');
    expect(sizeLabelFor('tissue'), 'Tissue size');
    expect(nounFor('tissue'), 'tissues');
    expect(nounFor('other'), 'units');
  });

  test('Machine and CatalogItem parse the structured spec', () {
    final c = CatalogItem.fromJson({'id': '1', 'name': 'x', 'model': 'm', 'typeKey': 'tissue', 'spec': tissueJson()});
    expect(c.spec!.sizeUnit, 'cm');
    expect(StoreItem.fromCatalog(c).spec!.speedPer, 'hr');
    final m = Machine.fromJson({
      'id': '1', 'code': 'X', 'typeKey': 'tissue', 'typeName': 'Tissue', 'status': 'idle', 'speed': 0, 'speedUnit': '', 'outputUnit': '', 'todayProduction': 0, 'todayTarget': 0, 'efficiency': 0,
      'spec': tissueJson(),
    });
    expect(m.spec!.speedMin, 500);
  });

  Future<void> show(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w))));
  }

  testWidgets('tissue machine: Tissue size, speed range and the per minute / hour / day tiles', (t) async {
    await show(t, SpecView(typeKey: 'tissue', spec: Spec.fromJson(tissueJson())));
    expect(find.text('Tissue size'), findsOneWidget);
    expect(find.text('10 – 30 cm'), findsOneWidget);
    expect(find.text('500 – 800 tissues/hr'), findsOneWidget);
    expect(find.text('8 – 13'), findsOneWidget); // per minute
    expect(find.text('500 – 800'), findsOneWidget); // per hour (the unit it was entered in)
    expect(find.text('12,000 – 19,200'), findsOneWidget); // per day
    for (final l in ['per minute', 'per hour', 'per day']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Cup size'), findsNothing);
  });

  testWidgets('cup machine: size, max height, speed, GSM and coating', (t) async {
    await show(t, SpecView(typeKey: 'paper_cup', spec: Spec.fromJson(cupJson())));
    expect(find.text('Cup size'), findsOneWidget);
    expect(find.text('2.5 – 16 oz'), findsOneWidget);
    expect(find.text('137 mm'), findsOneWidget);
    expect(find.text('150 – 200 cups/min'), findsOneWidget);
    expect(find.text('140 – 350 GSM · Single or double PE coated'), findsOneWidget);
  });

  testWidgets('older machines without a spec still show their text', (t) async {
    await show(t, const SpecView(typeKey: 'paper_cup', speedText: '200 cups/min', sizeText: '3 oz – 16 oz', paperText: '140–350 GSM'));
    expect(find.text('Cup size'), findsOneWidget);
    expect(find.text('3 oz – 16 oz'), findsOneWidget);
    expect(find.text('200 cups/min'), findsOneWidget);
    expect(find.text('140–350 GSM'), findsOneWidget);
    expect(find.text('per minute'), findsNothing); // no tiles without structured data
  });
}
