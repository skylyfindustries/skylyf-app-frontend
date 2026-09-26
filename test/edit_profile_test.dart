import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/features/profile/edit_profile_form.dart';

Me me(String role) => Me.fromJson({
      'user': {'name': 'Rahul Sharma', 'email': 'rahul@abc.com', 'phone': '+919999900000', 'role': role},
      'company': {'name': 'ABC INDUSTRIES', 'location': {'street': 'Plot 5, Noida', 'city': 'Noida', 'state': 'UP', 'zip': '201301'}, 'gstin': '09AABCU9603R1ZX'},
    });

Future<void> open(WidgetTester t, String role) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [meProvider.overrideWith((ref) async => me(role))],
    child: const MaterialApp(home: Scaffold(body: EditProfileForm())),
  ));
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('edit profile modal is prefilled; owners also see company details', (t) async {
    await open(t, 'customer');
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('rahul@abc.com'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget); // country picked from the stored number
    expect(find.text('9999900000'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('ABC INDUSTRIES'), findsOneWidget);
    expect(find.text('Plot 5, Noida'), findsOneWidget); // structured address
    expect(find.text('09AABCU9603R1ZX'), findsOneWidget); // government ID
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('technicians do not get the company section', (t) async {
    await open(t, 'technician');
    expect(find.text('Company'), findsNothing);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
