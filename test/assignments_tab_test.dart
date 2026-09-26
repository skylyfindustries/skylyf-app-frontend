import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/core/role.dart';
import 'package:skylyf_machine/features/team/assignments_screen.dart';

void main() {
  test('owner tabs: Daily assignments replaces Reports in the same slot', () {
    final labels = Role.customer.tabs.map((t) => t.label).toList();
    expect(labels[2], 'Assignments');
    expect(Role.customer.tabs[2].path, '/assignments');
    expect(labels, isNot(contains('Reports')));
  });

  testWidgets('as a tab it has its own title row and no back arrow', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [assignmentsProvider.overrideWith((ref, date) async => [])],
      child: const MaterialApp(home: Scaffold(body: AssignmentsScreen())),
    ));
    await t.pump();
    await t.pump();
    expect(find.text('Daily assignments'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Assign'), findsOneWidget);
    expect(find.text('Machines'), findsOneWidget); // summary tiles
    expect(find.text('Technicians'), findsOneWidget);
    expect(find.text('Nothing assigned'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Assign machines'), findsOneWidget);
  });
}
