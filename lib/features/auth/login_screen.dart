import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  Method _method = Method.email;
  bool _keep = false; // "keep me signed in": off = the server signs you out 12 hours after sign-in

  /// Every sign-in method goes through here so the choice is sent with it.
  Future<void> _go(Future<void> Function(Api api) method) => ref.read(authProvider.notifier).signIn((api) {
        api.remember = _keep;
        return method(api);
      });

  @override
  Widget build(BuildContext context) {
    final keep = KeepSignedIn(value: _keep, onChanged: (v) => setState(() => _keep = v));
    return AuthShell(
      brand: false,
      titleAbove: true,
      image: 'assets/login-vector.jpg',
      title: 'Login',
      subtitle: 'Sign in to monitor your plant.',
      footer: Column(children: [
        MethodIcons(value: _method, onChanged: (m) => setState(() => _method = m)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.push('/register'), child: const Text('New factory owner? Create an account', style: TextStyle(fontWeight: FontWeight.w700))),
        
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        switch (_method) {
          Method.email => _EmailLogin(extra: keep, onSubmit: (id, pw) => _go((api) => api.login(id, pw))),
          Method.phone => PhoneOtpPanel(
              verifyLabel: 'Verify & sign in',
              extra: keep,
              send: (c, phone) => ref.read(apiProvider).otpRequest(c.dial, phone, 'login'),
              onVerify: (c, phone, code) => _go((api) => api.otpLogin(c.dial, phone, code)),
            ),
          Method.passkey => PasskeyPanel(label: 'Sign in with passkey', extra: keep, onGo: () => _go((api) => api.passkeyLogin())),
          Method.authenticator => AuthenticatorPanel(verifyLabel: 'Verify & sign in', extra: keep, onVerify: (id, code) => _go((api) => api.totpLogin(id, code))),
        },
      ]),
    );
  }
}

class _EmailLogin extends ConsumerStatefulWidget {
  const _EmailLogin({required this.onSubmit, this.extra});
  final Future<void> Function(String email, String password) onSubmit;
  final Widget? extra;
  @override
  ConsumerState<_EmailLogin> createState() => _EmailLoginState();
}

class _EmailLoginState extends ConsumerState<_EmailLogin> with BusyError {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await run(() => widget.onSubmit(_email.text.trim(), _pw.text));
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EmailField(controller: _email),
        const SizedBox(height: 14),
        PasswordField(controller: _pw, validator: V.loginPassword, onSubmitted: _submit),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: widget.extra ?? const SizedBox.shrink()),
          TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w700, color: Brand.gold300))),
        ]),
        ErrorText(error),
        const SizedBox(height: 8),
        BusyButton(label: t('Login'), busy: busy, onPressed: _submit),
      ]),
    );
  }
}
