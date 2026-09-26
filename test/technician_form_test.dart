import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/validators.dart';
import 'package:skylyf_machine/features/team/technician_form.dart';

void main() {
  test('date of birth: adults only', () {
    expect(V.dob(null), isNotNull);
    expect(V.dob(DateTime.now().subtract(const Duration(days: 365 * 17))), isNotNull);
    expect(V.dob(DateTime.now().subtract(const Duration(days: 365 * 30))), isNull);
    expect(V.zip('201301'), isNull);
    expect(V.zip('!!'), isNotNull);
    expect(V.text('City', 2, 60)(' '), isNotNull);
  });

  testWidgets('technician modal shows every field and validates before sending', (t) async {
    t.view.physicalSize = const Size(800, 5000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: TechnicianForm()))));
    for (final label in ['First name', 'Last name', 'Email', 'Phone number', 'Date of birth', 'Password', 'Street', 'City', 'State', 'Zip code', 'Starts', 'Ends']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Documents (optional)'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget); // India default
    expect(find.text('09:00'), findsOneWidget); // default shift

    await t.tap(find.text('Add technician').last); // the submit button
    await t.pump();
    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Zip code'), findsOneWidget);
  });
}
