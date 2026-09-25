import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mock_data.dart';

/// Android emulator reaches the host machine at 10.0.2.2. Override: --dart-define=API_URL=https://...
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000/api/v1');

/// Default: static demo data (no backend). Real API: --dart-define=USE_API=true
const demoMode = !bool.fromEnvironment('USE_API');

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Dio wrapper: JWT bearer, one automatic refresh on 401, unwraps the `{success,data}` envelope.
class Api {
  Api({required this.onLoggedOut, FlutterSecureStorage? storage, Dio? dio})
      : _store = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: apiUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        if (_access != null) o.headers['Authorization'] = 'Bearer $_access';
        h.next(o);
      },
      onError: _onError,
    ));
  }

  final void Function() onLoggedOut;
  final FlutterSecureStorage _store;
  final Dio _dio;
  String? _access, _refresh;
  Future<bool>? _refreshing;

  Future<bool> loadSession() async {
    if (demoMode) return false;
    _access = await _store.read(key: 'access');
    _refresh = await _store.read(key: 'refresh');
    return _refresh != null;
  }

  Future<void> _save(Map data) async {
    _access = data['accessToken'];
    _refresh = data['refreshToken'];
    await _store.write(key: 'access', value: _access);
    await _store.write(key: 'refresh', value: _refresh);
  }

  Future<void> login(String identifier, String password) async {
    if (demoMode) return mockLogin(identifier);
    await _save(await post('/auth/login', {'identifier': identifier, 'password': password}));
  }

  Future<void> logout() async {
    _access = _refresh = null;
    await _store.deleteAll();
  }

  Future<bool> _refreshTokens() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    try {
      final r = await Dio(BaseOptions(baseUrl: apiUrl)).post('/auth/refresh', data: {'refreshToken': _refresh});
      await _save(r.data['data']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final req = e.requestOptions;
    final canRetry = e.response?.statusCode == 401 && !req.path.startsWith('/auth/') && _refresh != null && req.extra['retried'] != true;
    if (canRetry) {
      if (await _refreshTokens()) {
        req.extra['retried'] = true;
        req.headers['Authorization'] = 'Bearer $_access';
        try {
          return h.resolve(await _dio.fetch(req));
        } on DioException catch (e2) {
          return h.next(e2);
        }
      }
      await logout();
      onLoggedOut();
    }
    h.next(e);
  }

  Future<dynamic> _call(Future<Response> Function() f) async {
    try {
      return (await f()).data['data'];
    } on DioException catch (e) {
      final body = e.response?.data;
      final err = body is Map ? body['error'] : null;
      throw ApiException(err is Map && err['message'] is String ? err['message'] : 'Cannot reach server. Check your connection.');
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => demoMode ? _demo('GET', path, query: query) : _call(() => _dio.get(path, queryParameters: query));
  Future<dynamic> post(String path, Map<String, dynamic> data) => demoMode ? _demo('POST', path, body: data) : _call(() => _dio.post(path, data: data));
  Future<dynamic> delete(String path) => demoMode ? _demo('DELETE', path) : _call(() => _dio.delete(path));
  Future<dynamic> patch(String path, Map<String, dynamic> data) => demoMode ? _demo('PATCH', path, body: data) : _call(() => _dio.patch(path, data: data));

  Future<dynamic> _demo(String method, String path, {Map<String, dynamic>? query, Map<String, dynamic>? body}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250)); // feels like a network call
    try {
      return mockRequest(method, path, query: query, body: body);
    } on ApiExceptionDemo catch (e) {
      throw ApiException(e.message);
    }
  }
}
