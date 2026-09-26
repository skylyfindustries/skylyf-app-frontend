import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// What this phone is called on the Security page, e.g. "samsung SM-S911B (Android 14)". Set once at start-up.
String deviceLabel = 'Skylyf app';

Future<void> loadDeviceLabel() async {
  try {
    if (kIsWeb) return;
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      deviceLabel = '${a.manufacturer} ${a.model} (Android ${a.version.release})';
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      deviceLabel = '${i.name} (iOS ${i.systemVersion})';
    }
  } catch (_) {/* keep the generic label */}
}
