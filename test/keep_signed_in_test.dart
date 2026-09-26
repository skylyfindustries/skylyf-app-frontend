import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/api.dart';
import 'package:skylyf_machine/features/auth/login_screen.dart';

class _Capture implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': {'accessToken': 'a', 'refreshToken': 'r', 'sent': true}}), 200, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the choice is sent with every sign-in method (default: off = 12 hour session)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final cap = _Capture();
    final api = Api(onLoggedOut: () {}, dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = cap);

    expect(api.remember, isFalse);
    await api.login('a@b.co', 'pw');
    expect(cap.requests.last.data['remember'], false);

    api.remember = true;
    await api.login('a@b.co', 'pw');
    expect(cap.requests.last.data['remember'], true);
    await api.otpLogin('+91', '9876543210', '123456');
    expect(cap.requests.last.data, containsPair('remember', true));
    await api.totpLogin('a@b.co', '123456');
    expect(cap.requests.last.data, containsPair('remember', true));

    api.remember = false;
    await api.otpLogin('+91', '9876543210', '123456');
    expect(cap.requests.last.data, containsPair('remember', false));
    await api.register({'name': 'X'});
    expect(cap.requests.last.data['remember'], true); // a brand-new owner stays signed in
  });

  testWidgets('login shows "Keep me signed in", off by default, on every method', (t) async {
    t.view.physicalSize = const Size(800, 2400); // the login screen has a header image now
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Keep me signed in'), findsOneWidget);
    expect(tester(t).value, isFalse);

    await t.tap(find.text('Keep me signed in'));
    await t.pump();
    expect(tester(t).value, isTrue);

    for (final tip in ['WhatsApp', 'Passkey', 'Authenticator']) {
      await t.tap(find.byTooltip(tip));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Keep me signed in'), findsOneWidget, reason: tip); // still there, and the choice is kept
      expect(tester(t).value, isTrue, reason: tip);
    }
  });
}

Checkbox tester(WidgetTester t) => t.widget<Checkbox>(find.byType(Checkbox));
