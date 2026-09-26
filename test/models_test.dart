import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/api.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/theme.dart';

Map<String, dynamic> machineJson(String status, {num speed = 0}) => {
      'id': 'm1', 'code': 'PC-01', 'typeKey': 'paper_cup', 'typeName': 'Paper Cup', 'model': 'SKY-PC 180',
      'status': status, 'speed': speed, 'speedUnit': 'Cups/min', 'outputUnit': 'Cups',
      'todayProduction': 4350, 'todayTarget': 5000, 'efficiency': 87,
    };

void main() {
  machineDetailsTest();
  test('Machine parses API json and labels each status', () {
    final m = Machine.fromJson(machineJson('running', speed: 180));
    expect(m.speedUnit, 'Cups/min');
    expect(m.statusLabel, 'Running');
    expect(Machine.fromJson(machineJson('stopped')).statusLabel, 'Stopped');
    expect(Machine.fromJson(machineJson('idle')).statusLabel, 'Idle');
    expect(m.shifts, isNull);
  });

  test('Machine detail carries shift totals', () {
    final m = Machine.fromJson({...machineJson('running'), 'shifts': {'A': 9200, 'B': 9700, 'C': 5600}});
    expect(m.shifts!['B'], 9700);
  });

  test('Dashboard parses counts, production and attention list', () {
    final d = Dashboard.fromJson({
      'counts': {'running': 15, 'stopped': 3, 'idle': 2},
      'production': {'today': 87500, 'target': 100000},
      'attention': [{'machineId': 'x', 'code': 'PC-02', 'status': 'stopped'}],
    });
    expect((d.running, d.stopped, d.idle), (15, 3, 2));
    expect(d.progress, 0.875);
    expect(d.attention.single.code, 'PC-02');
  });

  test('Dashboard progress is safe with zero target and capped at 1', () {
    Dashboard mk(num today, num target) => Dashboard(running: 0, stopped: 0, idle: 0, today: today, target: target, attention: const []);
    expect(mk(10, 0).progress, 0);
    expect(mk(150, 100).progress, 1);
  });

  test('status colours and number formatting', () {
    expect(statusColor('running'), Brand.running);
    expect(statusColor('stopped'), Brand.stopped);
    expect(statusColor('idle'), Brand.idle);
    expect(fmt(87500), '87,500');
    expect(fmt(999), '999');
    expect(fmt(1234567.4), '1,234,567');
  });
}

void machineDetailsTest() {
  test('machine parses the details and photos entered in the dashboard', () {
    final m = Machine.fromJson({
      'id': '1', 'code': 'SKYLYF-001', 'typeKey': 'paper_cup', 'typeName': 'Paper Cup', 'status': 'idle', 'speed': 0, 'speedUnit': 'Cups/min', 'outputUnit': 'Cups',
      'todayProduction': 0, 'todayTarget': 0, 'efficiency': 0,
      'name': 'Cup Maker', 'productionSpeed': '200 cups/min', 'cupSize': '3 oz – 16 oz', 'paperRequired': '140–350 GSM', 'photos': ['/api/v1/uploads/a.jpg'],
    });
    expect(m.name, 'Cup Maker');
    expect(m.cupSize, '3 oz – 16 oz');
    expect(photoUrl(m.photos.first), endsWith('/api/v1/uploads/a.jpg'));
    expect(Machine.fromJson({...{'id': '2', 'code': 'X', 'typeKey': 't', 'typeName': 't', 'status': 'idle', 'speed': 0, 'speedUnit': '', 'outputUnit': '', 'todayProduction': 0, 'todayTarget': 0, 'efficiency': 0}}).photos, isEmpty);
  });
}
