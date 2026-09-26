import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/features/team/my_tasks_screen.dart';
import 'package:skylyf_machine/features/team/stages.dart';

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Assignment task(String id, String code, String status, {DateTime? day, List<AssignmentEvent> history = const []}) => Assignment(
      id: id, date: ymd(day ?? DateTime.now()), machineId: 'm$id', code: code, machine: 'Cup Maker', technicianId: 't', technician: 'Ravi Kumar', status: status, note: 'Run the morning batch', history: history,
    );

void main() {
  test('stages go assigned -> started -> running -> done, one at a time', () {
    expect(stages, ['assigned', 'started', 'running', 'done']);
    expect(nextStage('assigned'), 'started');
    expect(nextStage('started'), 'running');
    expect(nextStage('running'), 'done');
    expect(nextStage('done'), isNull);
    expect(nextAction('assigned'), 'Start work');
    expect(stageLabel('done'), 'Completed');
  });

  test('assignment parses its history (who, when, note)', () {
    final a = Assignment.fromJson({
      'id': '1', 'date': '2030-01-01', 'machineId': 'm', 'code': 'X-1', 'machine': '', 'technicianId': 't', 'technician': 'Ravi', 'status': 'started',
      'history': [
        {'status': 'assigned', 'from': null, 'byName': 'Rahul', 'role': 'customer', 'at': '2030-01-01T04:00:00.000Z', 'note': ''},
        {'status': 'started', 'from': 'assigned', 'byName': 'Ravi', 'role': 'technician', 'at': '2030-01-01T05:30:00.000Z', 'note': 'Checking oil'},
      ],
    });
    expect(a.history.length, 2);
    expect(a.history.last.byName, 'Ravi');
    expect(a.history.last.from, 'assigned');
    expect(a.history.last.note, 'Checking oil');
    expect(a.working, isTrue);
    expect(a.done, isFalse);
  });

  Future<void> open(WidgetTester t, List<Assignment> rows) async {
    t.view.physicalSize = const Size(800, 3500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        myTasksProvider.overrideWith((ref) async => rows),
        staffTicketsProvider.overrideWith((ref) async => <StaffTicket>[]),
      ],
      child: const MaterialApp(home: Scaffold(body: MyTasksScreen())),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('My tasks: today / upcoming / earlier, each task shows its stage and next action', (t) async {
    final now = DateTime.now();
    await open(t, [
      task('1', 'SKYLYF-001', 'assigned'),
      task('2', 'SKYLYF-002', 'running'),
      task('3', 'PC-09', 'assigned', day: now.add(const Duration(days: 2))),
      task('4', 'PC-01', 'done', day: now.subtract(const Duration(days: 3))),
    ]);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Today (2)'), findsOneWidget);
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.text('Earlier (1)'), findsOneWidget);
    expect(find.text('SKYLYF-001'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget); // assigned -> started
    expect(find.text('Mark completed'), findsOneWidget); // running -> done
    for (final l in ['Assigned', 'Started', 'Running', 'Completed']) {
      expect(find.text(l), findsWidgets, reason: l); // the stepper labels
    }
    expect(find.text('PC-09'), findsNothing); // not on the Today tab

    await t.tap(find.text('Upcoming (1)'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('PC-09'), findsOneWidget);
    await t.tap(find.text('Earlier (1)'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('PC-01'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('history sheet lists who changed the stage and when', (t) async {
    final h = [
      AssignmentEvent(status: 'assigned', at: DateTime(2030, 1, 1, 9, 0), byName: 'Rahul Sharma', role: 'customer'),
      AssignmentEvent(status: 'started', from: 'assigned', at: DateTime(2030, 1, 1, 9, 30), byName: 'Ravi Kumar', role: 'technician', note: 'Checking oil'),
    ];
    await open(t, [task('1', 'SKYLYF-001', 'started', history: h)]);
    await t.tap(find.text('History (2)'));
    await t.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Assigned  →  Started'), findsOneWidget);
    expect(find.textContaining('Ravi Kumar (Technician)'), findsOneWidget);
    expect(find.textContaining('Rahul Sharma (Owner)'), findsOneWidget);
    expect(find.text('“Checking oil”'), findsOneWidget);
    expect(find.text('Set stage'), findsNothing); // only the owner can reopen / set a stage
  });
}
