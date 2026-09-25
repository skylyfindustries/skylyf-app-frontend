import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/mock_data.dart';

List<String> codes(dynamic rows) => [for (final m in rows as List) '${m['company']}/${m['code']}'];
dynamic get(String path, [Map<String, dynamic>? q]) => mockRequest('GET', path, query: q);
dynamic send(String method, String path, Map<String, dynamic> body) => mockRequest(method, path, body: body);

void main() {
  test('customer sees only their own 2–3 machines and cannot open another tenant\'s', () {
    mockLogin('customer@abc.com');
    final mine = get('machines') as List;
    expect(mine.length, inInclusiveRange(2, 3));
    expect(mine.every((m) => m['companyId'] == 'c1'), isTrue);
    expect(() => get('machines/c2-T-01'), throwsA(isA<ApiExceptionDemo>()));
    expect(() => get('machines/u-PC-07'), throwsA(isA<ApiExceptionDemo>())); // unassigned stock
    // another customer gets a different set
    mockLogin('meera@greencup.in');
    expect((get('machines') as List).map((m) => m['companyId']).toSet(), {'c3'});
  });

  test('owner sees every machine, including the unassigned pool', () {
    mockLogin('owner@skylyf.com');
    expect((get('machines') as List).length, 12);
    expect((get('machines', {'companyId': 'unassigned'}) as List).length, 4);
  });

  test('technician only sees the customers they are assigned to', () {
    mockLogin('tech@skylyf.com'); // Amit → ABC + Delta
    final companies = (get('machines') as List).map((m) => m['companyId']).toSet();
    expect(companies, {'c1', 'c2'});
    expect(() => get('machines/c3-PC-01'), throwsA(isA<ApiExceptionDemo>()));
    expect(() => get('customers/c3'), throwsA(isA<ApiExceptionDemo>()));
  });

  test('a task must be given to a technician assigned to the customer, and only that technician sees it', () {
    mockLogin('customer@abc.com'); // ABC has Amit (tech1) and Ravi (tech2), not Sana (tech3)
    final techs = (get('technicians') as List).map((t) => t['id']).toSet();
    expect(techs, {'tech1', 'tech2'});
    expect(() => send('POST', 'machines/PC-01/maintenance', {'note': 'x', 'technicianId': 'tech3'}), throwsA(isA<ApiExceptionDemo>()));
    expect(() => send('POST', 'machines/PC-01/maintenance', {'note': 'x'}), throwsA(isA<ApiExceptionDemo>()));

    final t = send('POST', 'machines/PC-01/maintenance', {'note': 'Belt slipping', 'technicianId': 'tech2', 'priority': 'high'});
    expect(t['technician'], 'Ravi Kumar');
    expect((get('tasks') as List).any((x) => x['id'] == t['id']), isTrue);

    mockLogin('tech2@skylyf.com');
    expect((get('tickets') as List).any((x) => x['id'] == t['id']), isTrue);
    mockLogin('tech@skylyf.com'); // Amit was not chosen
    expect((get('tickets') as List).any((x) => x['id'] == t['id']), isFalse);
  });

  test('only the owner can manage machines; assigning gives the customer access', () {
    mockLogin('customer@abc.com');
    expect(() => send('PATCH', 'machines/u-PC-07', {'companyId': 'c1'}), throwsA(isA<ApiExceptionDemo>()));
    expect(() => send('POST', 'machines', {'typeKey': 'tissue', 'code': 'T-99', 'serial': 'SKY-TS-0000-0001'}), throwsA(isA<ApiExceptionDemo>()));
    final before = (get('machines') as List).length;

    mockLogin('owner@skylyf.com');
    send('PATCH', 'machines/u-PC-07', {'companyId': 'c1'});
    mockLogin('customer@abc.com');
    expect((get('machines') as List).length, before + 1);
    expect(codes(get('machines')), contains('ABC INDUSTRIES/PC-07'));

    mockLogin('owner@skylyf.com'); // unassign again
    send('PATCH', 'machines/u-PC-07', {'companyId': null});
    mockLogin('customer@abc.com');
    expect((get('machines') as List).length, before);
  });

  test('owner approves a registration and the machine appears for that customer', () {
    mockLogin('customer@abc.com');
    final before = (get('machines') as List).length;
    mockLogin('owner@skylyf.com');
    send('PATCH', 'registrations/r1', {'status': 'approved'}); // ABC's pending PC-03
    mockLogin('customer@abc.com');
    expect((get('machines') as List).length, before + 1);
    expect(codes(get('machines')), contains('ABC INDUSTRIES/PC-03'));
  });
}
