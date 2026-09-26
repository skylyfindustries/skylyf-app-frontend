import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:skylyf_machine/core/countries.dart';
import 'package:skylyf_machine/core/validators.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skylyf_machine/features/auth/auth_widgets.dart';
import 'package:skylyf_machine/features/auth/login_screen.dart';

void main() {
  checklistTest();
  test('email limits', () {
    expect(V.email(''), isNotNull);
    expect(V.email('a@b'), isNotNull);
    expect(V.email('${'a' * 250}@b.co'), isNotNull); // > 254
    expect(V.email(' name@company.com '), isNull);
  });

  test('password rules: strict for new passwords, presence-only for sign-in', () {
    expect(V.newPassword('short1A!'), isNull);
    for (final bad in ['Sh0rt!', 'alllowercase1!', 'ALLUPPERCASE1!', 'NoDigits!!', 'NoSymbol123A', 'Has Space1!a', 'Aa1!${'x' * 61}']) {
      expect(V.newPassword(bad), isNotNull, reason: bad);
    }
    expect(V.loginPassword('anything'), isNull);
    expect(V.loginPassword(''), isNotNull);
    expect(V.confirm(() => 'abc')('abd'), isNotNull);
  });

  test('phone length depends on the country; India starts 6-9', () {
    final in_ = V.phone(() => india);
    expect(in_('9876543210'), isNull);
    expect(in_('5876543210'), isNotNull);
    expect(in_('98765'), isNotNull);
    expect(in_('98765432101'), isNotNull);
    final ae = V.phone(() => countries.firstWhere((c) => c.iso == 'AE'));
    expect(ae('501234567'), isNull);
    expect(ae('5012345678'), isNotNull);
  });

  test('every country has a sane dial code and length', () {
    for (final c in countries) {
      expect(c.dial, matches(RegExp(r'^\+[1-9]\d{0,3}$')));
      expect(c.dial.length - 1 + c.max, lessThanOrEqualTo(15), reason: c.name); // E.164
      expect(c.min, lessThanOrEqualTo(c.max));
    }
    expect(countries.first.iso, 'IN'); // India is the default
  });

  test('lottie files parse', () async {
    for (final f in ['gears', 'success']) {
      final c = await LottieComposition.fromBytes(File('assets/lottie/$f.json').readAsBytesSync());
      expect(c.duration, greaterThan(Duration.zero), reason: f);
    }
  });

  testWidgets('login: email form by default, other methods as icons at the bottom', (t) async {
    t.view.physicalSize = const Size(800, 2400); // the login screen has a header image now
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Email'), findsOneWidget); // the email field is the default form
    expect(find.text('WhatsApp'), findsNothing); // icons carry no visible names
    expect(find.text('customer@abc.com'), findsNothing);
    await t.tap(find.byTooltip('WhatsApp'));
    await t.pump();
    expect(find.text('+91'), findsOneWidget); // India default
    await t.tap(find.text('Send code on WhatsApp'));
    await t.pump();
    expect(find.text('Phone number is required'), findsOneWidget);
    await t.tap(find.byTooltip('WhatsApp')); // tap again → back to email
    await t.pump();
    expect(find.text('Email'), findsOneWidget);
  });
}

void checklistTest() {
  testWidgets('password checklist ticks rules as they are typed', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: PasswordChecklist(controller: c))));
    expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
    c.text = 'abc';
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(LucideIcons.circleCheck), findsNWidgets(2)); // lowercase + no spaces
    c.text = 'Abcdef1!';
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(LucideIcons.circleCheck), findsNWidgets(6));
  });
}
