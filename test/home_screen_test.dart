import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/core/theme.dart';
import 'package:skylyf_machine/features/home/home_screen.dart';

void main() {
  testWidgets('Home shows company, status counts, production and attention list', (tester) async {
    tester.view.physicalSize = const Size(900, 3200); // tall enough that the lazy list builds every section
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        meProvider.overrideWith((_) async => Me(name: 'Rahul', email: 'r@abc.com', company: 'ABC INDUSTRIES', language: 'en')),
        plantsProvider.overrideWith((_) async => [Plant('p1', 'Noida Plant')]),
        alertsProvider.overrideWith((_) async => <AlertItem>[]),
        dashboardProvider.overrideWith((_) async => Dashboard(
              running: 15, stopped: 3, idle: 2, today: 87500, target: 100000,
              attention: [Attention('a', 'PC-02', 'stopped'), Attention('b', 'T-04', 'stopped')],
            )),
      ],
      child: MaterialApp(theme: buildTheme(), home: const GlassBackground(child: Scaffold(backgroundColor: Colors.transparent, body: HomeScreen()))),
    ));
    // running dots pulse forever, so pump fixed durations instead of settling
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('ABC INDUSTRIES'), findsOneWidget);
    expect(find.text('Noida Plant'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('87,500'), findsOneWidget);
    expect(find.textContaining('100,000'), findsOneWidget);
    expect(find.text('PC-02'), findsOneWidget);
    expect(find.text('T-04'), findsOneWidget);
  });
}
