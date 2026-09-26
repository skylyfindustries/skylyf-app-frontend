import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/core/role.dart';
import 'package:skylyf_machine/features/staff/staff_screens.dart';

Assignment a(String id, String code, String status) =>
    Assignment(id: id, date: '2030-01-01', machineId: 'm$id', code: code, machine: 'Cup Maker', technicianId: 't', technician: 'Ravi', status: status);

Future<void> open(WidgetTester t, List<Assignment> rows) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      roleProvider.overrideWith(_TechRole.new),
      overviewProvider.overrideWith((ref) async => Overview(customers: 1, machines: 20, users: 3, running: 15, stopped: 3, idle: 2, attention: [])),
      staffTicketsProvider.overrideWith((ref) async => <StaffTicket>[]),
      assignmentsProvider.overrideWith((ref, date) async => rows),
      meProvider.overrideWith((ref) async => Me.fromJson({
            'user': {'name': 'Ravi Kumar', 'email': 'r@x.in', 'role': 'technician', 'shift': {'start': '09:00', 'end': '18:00'}},
            'company': {'name': 'ABC'},
          })),
    ],
    child: const MaterialApp(home: Scaffold(body: TechHomeScreen())),
  ));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('technician sees how many machines to run today and the progress', (t) async {
    await open(t, [a('1', 'SKYLYF-001', 'done'), a('2', 'SKYLYF-002', 'assigned'), a('3', 'PC-03', 'running'), a('4', 'PC-04', 'done')]);
    expect(find.text("Today's plan"), findsOneWidget);
    expect(find.text('2 machines left to run'), findsOneWidget);
    expect(find.text('2 of 4 machines finished today · 1 working now'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Shift 09:00 – 18:00'), findsOneWidget); // from the technician's own profile
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('SKYLYF-002'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget); // next stage for the not-started machine
    expect(find.text('Mark completed'), findsOneWidget); // the running one
  });

  testWidgets('all done and nothing assigned states', (t) async {
    await open(t, [a('1', 'X-1', 'done')]);
    expect(find.text('All done. Great work!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('nothing assigned', (t) async {
    await open(t, []);
    expect(find.text('No machines assigned'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });
}

class _TechRole extends RoleNotifier {
  @override
  Role? build() => Role.technician;
}
