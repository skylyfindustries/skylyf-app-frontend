import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/validators.dart';
import 'package:skylyf_machine/features/auth/company_details.dart';

Me me({String street = '', String gstin = '', String pan = ''}) => Me.fromJson({
      'user': {'name': 'R', 'email': 'r@x.in'},
      'company': {'name': 'ABC', 'location': street.isEmpty ? null : {'street': street, 'city': 'Noida', 'state': 'UP', 'zip': '201301'}, 'gstin': gstin, 'pan': pan},
    });

void main() {
  test('government IDs are optional but validated when entered', () {
    for (final f in [V.gstin, V.pan, V.cin, V.udyam]) {
      expect(f(''), isNull);
      expect(f(null), isNull);
    }
    expect(V.gstin('27aabcu9603r1zm'), isNull); // lowercase is fine, it is upper-cased
    expect(V.gstin('27AABCU9603R1Z'), isNotNull);
    expect(V.gstin('99AABCU9603R1ZM'), isNotNull); // no such state code
    expect(V.pan('AABCU9603R'), isNull);
    expect(V.pan('ABC123'), isNotNull);
    expect(V.cin('U12345MH2020PTC123456'), isNull);
    expect(V.cin('X123'), isNotNull);
    expect(V.udyam('UDYAM-MH-12-1234567'), isNull);
    expect(V.udyam('UDYAM-XX'), isNotNull);
    expect(V.panMatchesGstin('AABCU9603R', '27AABCU9603R1ZM'), isNull);
    expect(V.panMatchesGstin('ZZZZZ9999Z', '27AABCU9603R1ZM'), isNotNull);
    expect(V.panMatchesGstin('ZZZZZ9999Z', ''), isNull); // nothing to compare with yet
  });

  test('registering sends only what was filled in; address parts always travel together', () {
    final i = CompanyDetailsInput();
    expect(i.toFields(), isEmpty);
    i.gstin.text = '27aabcu9603r1zm';
    i.street.text = '12 MG Road';
    i.city.text = 'Pune';
    expect(i.toFields(), {'street': '12 MG Road', 'city': 'Pune', 'state': '', 'zip': '', 'gstin': '27AABCU9603R1ZM'});
    i.dispose();
  });

  test('editing sends only what changed; blank clears', () {
    final i = CompanyDetailsInput(me(street: '5 Sector 62', gstin: '27AABCU9603R1ZM', pan: 'AABCU9603R'));
    expect(i.toFields(), isEmpty); // untouched
    i.pan.text = '';
    i.city.text = 'Delhi';
    expect(i.toFields(), {'street': '5 Sector 62', 'city': 'Delhi', 'state': 'UP', 'zip': '201301', 'pan': ''});
    i.dispose();
  });

  testWidgets('section: address is all-or-nothing, IDs are validated', (t) async {
    final i = CompanyDetailsInput();
    final key = GlobalKey<FormState>();
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Form(key: key, child: CompanyDetailsSection(input: i))))));
    expect(find.text('Company address (optional)'), findsOneWidget);
    expect(find.text('Government details (optional)'), findsOneWidget);
    for (final l in ['GSTIN', 'PAN', 'CIN (company registration)', 'Udyam (MSME) number']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(key.currentState!.validate(), isTrue); // all empty: fine

    i.street.text = '12 MG Road'; // started the address but nothing else
    expect(key.currentState!.validate(), isFalse);
    await t.pump();
    expect(find.text('City is required'), findsOneWidget);
    i.city.text = 'Pune';
    i.state.text = 'Maharashtra';
    i.zip.text = '411001';
    expect(key.currentState!.validate(), isTrue);

    i.gstin.text = 'BAD';
    expect(key.currentState!.validate(), isFalse);
    i.gstin.text = '27AABCU9603R1ZM';
    i.pan.text = 'ZZZZZ9999Z';
    expect(key.currentState!.validate(), isFalse); // PAN not inside the GSTIN
    i.pan.text = 'AABCU9603R';
    expect(key.currentState!.validate(), isTrue);
    i.dispose();
  });
}
