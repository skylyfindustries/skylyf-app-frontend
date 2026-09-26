import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'device.dart';
import 'passkey.dart';

/// Android emulator reaches the host machine at 10.0.2.2. Override: --dart-define=API_URL=https://...
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000/api/v1');

/// Full URL of an uploaded machine photo (the API returns paths like /api/v1/uploads/x.jpg).
String photoUrl(String path) => Uri.parse(apiUrl).resolve(path).toString();

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
        o.headers['x-device'] = deviceLabel;
        h.next(o);
      },
      onError: _onError,
    ));
  }

  final void Function() onLoggedOut;
  final FlutterSecureStorage _store;
  final Dio _dio;
  String? _access, _refresh;

  /// "Keep me signed in" (set by the login screen before signing in). Off: the server ends the session 12 hours after sign-in.
  bool remember = false;
  Future<bool>? _refreshing;

  Future<bool> loadSession() async {
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
    await _save(await post('/auth/login', {'identifier': identifier, 'password': password, 'remember': remember}));
  }

  // ---- other sign-in methods: every one ends with a session (login) or a one-time reset token (reset) ----
  Future<void> register(Map<String, dynamic> body) async {
    await _save(await post('/auth/register', {...body, 'remember': true})); // a brand-new owner stays signed in
  }

  /// Returns the code only when the server could not deliver it by WhatsApp (dev servers).
  Future<String?> otpRequest(String countryCode, String phone, String purpose) async {
    return (await post('/auth/otp/request', {'countryCode': countryCode, 'phone': phone, 'purpose': purpose}))['devCode'] as String?;
  }

  Future<void> otpLogin(String countryCode, String phone, String code) async {
    await _save(await post('/auth/otp/verify', {'countryCode': countryCode, 'phone': phone, 'code': code, 'purpose': 'login', 'remember': remember}));
  }

  Future<String> otpReset(String countryCode, String phone, String code) async {
    return (await post('/auth/otp/verify', {'countryCode': countryCode, 'phone': phone, 'code': code, 'purpose': 'reset'}))['resetToken'];
  }

  Future<void> totpLogin(String identifier, String code) async {
    await _save(await post('/auth/totp/verify', {'identifier': identifier, 'code': code, 'purpose': 'login', 'remember': remember}));
  }

  Future<String> totpReset(String identifier, String code) async {
    return (await post('/auth/totp/verify', {'identifier': identifier, 'code': code, 'purpose': 'reset'}))['resetToken'];
  }

  Future<void> passkeyLogin() async {
    await _save(await post('/auth/passkey/verify', {...await passkeyAssertion(this), 'purpose': 'login', 'remember': remember}));
  }

  Future<String> passkeyReset() async {
    return (await post('/auth/passkey/verify', {...await passkeyAssertion(this), 'purpose': 'reset'}))['resetToken'];
  }

  Future<void> forgotEmail(String email) async {
    await post('/auth/forgot/email', {'email': email});
  }

  Future<void> resetPassword(String resetToken, String password) async {
    await post('/auth/reset', {'resetToken': resetToken, 'password': password});
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

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _call(() => _dio.get(path, queryParameters: query));
  Future<dynamic> post(String path, Map<String, dynamic> data) => _call(() => _dio.post(path, data: data));
  /// multipart upload (photo, documents)
  Future<dynamic> postForm(String path, FormData form) => _call(() => _dio.post(path, data: form, options: Options(sendTimeout: const Duration(minutes: 2))));
  Future<dynamic> delete(String path) => _call(() => _dio.delete(path));
  Future<dynamic> patch(String path, Map<String, dynamic> data) => _call(() => _dio.patch(path, data: data));

  /// PATCH as a multipart form: text [fields] plus one optional image sent as `photos`.
  Future<dynamic> patchForm(String path, Map<String, String> fields, {String? photoPath}) async => _call(() async => _dio.patch(path, data: FormData.fromMap({
        ...fields,
        if (photoPath != null) 'photos': await MultipartFile.fromFile(photoPath, filename: photoPath.split(RegExp(r'[\/]')).last),
      })));
}
