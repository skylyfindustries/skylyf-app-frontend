import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';

class Analytics {
  Analytics(this._api);
  final Api _api;
  String? _sessionId;

  String _newSession() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> event(
    String type,
    String name, {
    String? screen,
    String? sessionId,
    String? productId,
    String? productName,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) async {
    _sessionId ??= _newSession();
    try {
      await _api.post('/analytics/events', {
        'events': [
          {
            'type': type,
            'name': name,
            'screen': screen,
            'sessionId': sessionId ?? _sessionId,
            'productId': productId,
            'productName': productName,
            'durationMs': durationMs,
            'metadata': metadata,
          }..removeWhere((_, value) => value == null),
        ],
      });
    } catch (_) {
      // Analytics must never interrupt the customer flow.
    }
  }

}

class AnalyticsObserver extends NavigatorObserver {
  AnalyticsObserver(this.analytics);
  final Analytics analytics;
  final Map<Route<dynamic>, DateTime> _started = {};

  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    _started[route!] = DateTime.now();
    unawaited(analytics.event('screen_view', name, screen: name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final started = _started.remove(route);
    final name = route.settings.name;
    if (started != null && name != null) {
      unawaited(analytics.event(
        'session',
        name,
        screen: name,
        durationMs: DateTime.now().difference(started).inMilliseconds,
      ));
    }
    super.didPop(route, previousRoute);
  }
}
