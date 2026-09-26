import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'api.dart';

// The server hands out standard WebAuthn options; the OS shows the fingerprint / face / screen-lock prompt.
Future<Map<String, dynamic>> passkeyAssertion(Api api) async {
  final o = await api.post('/auth/passkey/options', {});
  try {
    final r = await PasskeyAuthenticator().authenticate(AuthenticateRequestType.fromJson(
      Map<String, dynamic>.from(o['options']),
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: false,
    ));
    return {'state': o['state'], 'response': r.toJson()};
  } catch (e) {
    throw ApiException(passkeyMessage(e));
  }
}

/// Enrol a passkey for the signed-in user.
Future<void> passkeyEnrol(Api api, String name) async {
  final o = await api.post('/me/passkeys/options', {});
  try {
    final r = await PasskeyAuthenticator().register(RegisterRequestType.fromJson(Map<String, dynamic>.from(o['options'])));
    await api.post('/me/passkeys', {'state': o['state'], 'response': r.toJson(), 'name': name});
  } on ApiException {
    rethrow;
  } catch (e) {
    throw ApiException(passkeyMessage(e));
  }
}

String passkeyMessage(Object e) {
  final s = '$e';
  if (s.contains('Cancelled') || s.contains('cancel')) return 'Passkey request cancelled';
  if (s.contains('NoCredential') || s.contains('No credentials')) return 'No passkey found on this device. Sign in another way and add one under Security.';
  if (s.contains('Unsupported') || s.contains('NotSupported')) return 'This device does not support passkeys';
  return 'Passkey failed. Try again or use another method.';
}
