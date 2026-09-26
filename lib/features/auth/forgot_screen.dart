import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import 'auth_widgets.dart';

/// Reset a password by proving who you are (email link, WhatsApp code, passkey or authenticator app).
/// Every method yields a one-time reset token; the second step sets the new password with it.
/// [resetToken] is preset when the user opens the link from the email.
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key, this.resetToken});
  final String? resetToken;

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  Method _method = Method.email;
  late String? _token = widget.resetToken;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return _Done(onLogin: () => context.go('/login'));
    if (_token != null) {
      return _NewPassword(token: _token!, onDone: () => setState(() => _done = true), onBack: () => setState(() => _token = null));
    }
    final api = ref.read(apiProvider);
    return AuthShell(
      back: true,
      brand: false,
      titleAbove: true,
      icon: LucideIcons.lock,
      title: 'Forgot password',
      subtitle: 'Verify it is you to set a new password.',
      footer: MethodIcons(value: _method, onChanged: (m) => setState(() => _method = m)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        switch (_method) {
          Method.email => const _EmailLink(),
          Method.phone => PhoneOtpPanel(
              verifyLabel: 'Verify code',
              send: (c, phone) => api.otpRequest(c.dial, phone, 'reset'),
              onVerify: (c, phone, code) async {
                final t = await api.otpReset(c.dial, phone, code);
                if (mounted) setState(() => _token = t);
              },
            ),
          Method.passkey => PasskeyPanel(
              label: 'Verify with passkey',
              onGo: () async {
                final t = await api.passkeyReset();
                if (mounted) setState(() => _token = t);
              },
            ),
          Method.authenticator => AuthenticatorPanel(
              verifyLabel: 'Verify code',
              onVerify: (id, code) async {
                final t = await api.totpReset(id, code);
                if (mounted) setState(() => _token = t);
              },
            ),
        },
      ]),
    );
  }
}

class _EmailLink extends ConsumerStatefulWidget {
  const _EmailLink();
  @override
  ConsumerState<_EmailLink> createState() => _EmailLinkState();
}

class _EmailLinkState extends ConsumerState<_EmailLink> with BusyError {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    await run(() async {
      await ref.read(apiProvider).forgotEmail(_email.text.trim());
      _sent = true;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EmailField(controller: _email),
          if (_sent) const Padding(padding: EdgeInsets.only(top: 12), child: Text('If an account exists for this email, a reset link is on its way. It works for 15 minutes.', style: TextStyle(color: Brand.running, fontWeight: FontWeight.w600))),
          ErrorText(error),
          const SizedBox(height: 18),
          BusyButton(label: _sent ? 'Send again' : 'Email me a reset link', busy: busy, onPressed: _send, icon: LucideIcons.mail),
        ]),
      );
}

class _NewPassword extends ConsumerStatefulWidget {
  const _NewPassword({required this.token, required this.onDone, required this.onBack});
  final String token;
  final VoidCallback onDone, onBack;
  @override
  ConsumerState<_NewPassword> createState() => _NewPasswordState();
}

class _NewPasswordState extends ConsumerState<_NewPassword> with BusyError {
  final _form = GlobalKey<FormState>();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await run(() async {
      await ref.read(apiProvider).resetPassword(widget.token, _pw.text);
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        back: true,
        brand: false,
        titleAbove: true,
        title: 'Set a new password',
        subtitle: 'Verified. Choose a strong password you have not used before.',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PasswordField(controller: _pw, newPassword: true, label: 'New password', validator: V.newPassword, action: TextInputAction.next),
            PasswordChecklist(controller: _pw),
            const SizedBox(height: 14),
            PasswordField(controller: _pw2, newPassword: true, label: 'Confirm new password', validator: V.confirm(() => _pw.text), onSubmitted: _save),
            ErrorText(error),
            const SizedBox(height: 20),
            BusyButton(label: 'Save password', busy: busy, onPressed: _save, icon: LucideIcons.check),
          ]),
        ),
      );
}

class _Done extends StatelessWidget {
  const _Done({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => AuthShell(
        brand: false,
        titleAbove: true,
        title: 'Password updated',
        subtitle: 'You can now sign in with your new password.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: SuccessAnimation(size: 110)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onLogin, child: const Text('Back to sign in')),
        ]),
      );
}
