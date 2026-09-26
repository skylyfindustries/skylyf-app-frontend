import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skylyf_machine/core/api.dart';
import 'package:skylyf_machine/core/models.dart';
import 'package:skylyf_machine/core/providers.dart';
import 'package:skylyf_machine/features/machines/store_grid.dart';

class _Capture implements HttpClientAdapter {
  _Capture({this.status = 201, this.body});
  final int status;
  final Map<String, dynamic>? body;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body ?? {'success': true, 'data': {'ok': true}}), status, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('raising the quantity asks for that many serial numbers, all different, and sends them', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cap = _Capture();
    final api = Api(onLoggedOut: () {}, dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = cap);
    final items = [StoreItem(id: 'cat1', name: 'Paper Cup Machine', model: 'SKY-PC 180', typeKey: 'paper_cup', typeName: 'Paper Cup')];

    await t.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWith((ref) async => items), apiProvider.overrideWithValue(api), registrationsProvider.overrideWith((ref) async => <Registration>[])],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StoreGrid()))),
    ));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Register'));
    await t.pumpAndSettle();

    // one machine: one serial field
    expect(find.text('Serial number'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2)); // serial + machine name

    // + + -> three machines, three serial fields
    await t.tap(find.byIcon(LucideIcons.plus).last);
    await t.pump();
    await t.tap(find.byIcon(LucideIcons.plus).last);
    await t.pump();
    expect(find.text('Serial numbers (3)'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.text('Serial number $i of 3'), findsOneWidget);
    }
    expect(find.byType(TextFormField), findsNWidgets(4));

    // the same serial twice is refused, right on the field
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'sky-1001-aaa');
    await t.enterText(fields.at(1), 'SKY-1002-BBB');
    await t.enterText(fields.at(2), 'SKY-1001-AAA');
    await t.enterText(fields.at(3), 'PC');
    await t.tap(find.text('Submit registration'));
    await t.pump();
    expect(find.text('Same as serial number 1'), findsOneWidget);
    expect(cap.requests, isEmpty);

    await t.enterText(fields.at(2), 'SKY-1003-CCC');
    await t.tap(find.text('Submit registration'));
    await t.pumpAndSettle();
    expect(cap.requests, isEmpty); // nothing is sent before the user confirms
    await t.tap(find.text('Yes, register'));
    await t.pump();
    expect(find.text('Connecting your 3 machines'), findsOneWidget); // the processing modal, like a payment
    expect(find.text('Checking 3 serial numbers'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2500));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Registration successful'), findsOneWidget); // then the success screen, with the serials
    expect(find.text('SKY-1002-BBB'), findsWidgets);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('Serial numbers (3)'), findsNothing); // the form closed
    final sent = cap.requests.single;
    expect(sent.path, '/registrations');
    expect(sent.data['qty'], 3);
    expect(sent.data['catalogId'], 'cat1');
    expect(sent.data['serials'], ['SKY-1001-AAA', 'SKY-1002-BBB', 'SKY-1003-CCC']); // upper-cased, one per piece
  });

  testWidgets('a rejected registration shows a failure screen with the reason, and the form stays for another try', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cap = _Capture(status: 409, body: {'success': false, 'error': {'code': 'EXISTS', 'message': 'Serial number SKY-1001-AAA is already registered'}});
    final api = Api(onLoggedOut: () {}, dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = cap);
    await t.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWith((ref) async => [StoreItem(id: 'c', name: 'X', model: 'M', typeKey: 'tissue', typeName: 'Tissue')]),
        apiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StoreGrid()))),
    ));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Register'));
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'SKY-1001-AAA');
    await t.enterText(fields.at(1), 'PC-1');
    await t.tap(find.text('Submit registration'));
    await t.pumpAndSettle();
    await t.tap(find.text('Yes, register'));
    await t.pump();
    expect(find.text('Connecting your machine'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2500));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Could not connect'), findsOneWidget);
    expect(find.text('Serial number SKY-1001-AAA is already registered'), findsOneWidget); // the server's reason, shown to the client
    expect(find.text('Registration successful'), findsNothing);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Submit registration'), findsOneWidget); // back on the form, entries kept
    expect(find.text('SKY-1001-AAA'), findsOneWidget);
  });

  testWidgets('lowering the quantity drops the extra serial fields', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = Api(onLoggedOut: () {}, dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = _Capture());
    await t.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWith((ref) async => [StoreItem(id: 'c', name: 'X', model: 'M', typeKey: 'tissue', typeName: 'Tissue')]),
        apiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StoreGrid()))),
    ));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Register'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(LucideIcons.plus).last);
    await t.pump();
    expect(find.byType(TextFormField), findsNWidgets(3));
    await t.tap(find.byIcon(LucideIcons.minus));
    await t.pump();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Serial number 2 of 2'), findsNothing);
  });
}
