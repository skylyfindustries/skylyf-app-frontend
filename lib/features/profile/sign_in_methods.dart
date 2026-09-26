import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api.dart';
import '../../core/passkey.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../auth/auth_widgets.dart';

typedef SignInMethodsInfo = ({String? email, bool hasPassword, String? phone, bool totp, List<({String id, String name})> passkeys});

final signInMethodsProvider = FutureProvider.autoDispose<SignInMethodsInfo>((ref) async {
  final d = await ref.watch(apiProvider).get('/me/security') as Map;
  return (
    email: d['email'] as String?,
    hasPassword: d['hasPassword'] == true,
    phone: d['phone'] as String?,
    totp: d['totpEnabled'] == true,
    passkeys: [for (final p in d['passkeys'] as List) (id: '${p['id']}', name: '${p['name'] ?? 'Passkey'}')],
  );
});

/// Enrol / remove the extra ways to sign in (authenticator app, passkeys). Turning one off needs the password.
class SignInMethods extends ConsumerWidget {
  const SignInMethods({super.key});

  Future<String?> _askPassword(BuildContext context, String why) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(why),
        content: above('Your password', TextField(controller: c, obscureText: true, autofocus: true, decoration: const InputDecoration())),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Confirm'))],
      ),
    );
  }

  void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guard(BuildContext context, WidgetRef ref, Future<void> Function() f) async {
    try {
      await f();
      ref.invalidate(signInMethodsProvider);
    } catch (e) {
      if (context.mounted) _toast(context, e is ApiException ? e.message : 'Something went wrong');
    }
  }

  // buttons inside a Row: the theme's full-width minimum size would make the Row's width infinite
  Widget _small(VoidCallback onTap, String label) => FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(72, 40)), onPressed: onTap, child: Text(label));

  Widget _row(IconData icon, String title, bool on, String detail, {Widget? action}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: on ? Brand.running : Brand.navy500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: glassTint(on ? Brand.running : Brand.inkSoft, 20),
                  child: Text(on ? 'On' : 'Not set up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? Brand.running : Brand.inkSoft)),
                ),
              ]),
              Muted(detail, size: 12),
            ]),
          ),
          if (action != null) action,
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle(LucideIcons.keyRound, 'Sign-in methods'),
      GlassCard(
        child: asyncView<SignInMethodsInfo>(
          ref.watch(signInMethodsProvider),
          (m) {
            final hasEmail = m.email != null && m.email!.isNotEmpty, hasPhone = m.phone != null && m.phone!.isNotEmpty;
            final on = [hasEmail && m.hasPassword, hasPhone, m.totp, m.passkeys.isNotEmpty].where((x) => x).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Muted('$on of 4 methods set up. Every method that is on can be used to sign in or to reset your password.', size: 12),
              const SizedBox(height: 10),
              _row(LucideIcons.mail, 'Email & password', hasEmail && m.hasPassword, hasEmail ? m.email! : 'Sign in with your email and a password',
                  action: hasEmail ? null : _small(() => _addEmail(context, ref, m.hasPassword), 'Add')),
              const Divider(height: 24, color: Brand.line),
              _row(LucideIcons.messageCircle, 'WhatsApp code', hasPhone, hasPhone ? m.phone! : 'Get a 6-digit code on WhatsApp to sign in',
                  action: hasPhone ? null : _small(() => _addPhone(context, ref), 'Add')),
              const Divider(height: 24, color: Brand.line),
              _row(LucideIcons.smartphoneNfc, 'Authenticator app', m.totp, m.totp ? 'Sign in or reset your password with a code' : 'Use Google Authenticator, Authy or Microsoft Authenticator',
                  action: m.totp
                      ? TextButton(
                          onPressed: () async {
                            final pw = await _askPassword(context, 'Turn off authenticator app');
                            if (pw == null || !context.mounted) return;
                            await _guard(context, ref, () => api.post('/me/totp/disable', {'password': pw}));
                          },
                          child: const Text('Turn off'))
                      : _small(() => _setupTotp(context, ref), 'Set up')),
              const Divider(height: 24, color: Brand.line),
              _row(LucideIcons.fingerprint, 'Passkeys', m.passkeys.isNotEmpty, m.passkeys.isEmpty ? 'Sign in with your fingerprint, face or screen lock' : '${m.passkeys.length} saved on your account'),
              for (final p in m.passkeys)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 36),
                  dense: true,
                  title: Text(p.name),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 18, color: Brand.stopped),
                    onPressed: () async {
                      final pw = await _askPassword(context, 'Remove this passkey');
                      if (pw == null || !context.mounted) return;
                      await _guard(context, ref, () => api.post('/me/passkeys/${Uri.encodeComponent(p.id)}/remove', {'password': pw}));
                    },
                  ),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _guard(context, ref, () => passkeyEnrol(api, 'Passkey ${m.passkeys.length + 1}')),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add a passkey on this device'),
              ),
            ]);
          },
          onRetry: () => ref.invalidate(signInMethodsProvider),
        ),
      ),
    ]);
  }

  Future<void> _addPhone(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final done = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add phone number'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: PhoneOtpPanel(
              verifyLabel: 'Verify & add',
              send: (c, phone) async => (await api.post('/me/phone/request', {'countryCode': c.dial, 'phone': phone}))['devCode'] as String?,
              onVerify: (c, phone, code) async {
                await api.post('/me/phone/verify', {'countryCode': c.dial, 'phone': phone, 'code': code});
                if (d.mounted) Navigator.pop(d, true);
              },
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel'))],
      ),
    );
    if (done == true) {
      ref.invalidate(signInMethodsProvider);
      ref.invalidate(meProvider);
      if (context.mounted) _toast(context, 'Phone number added');
    }
  }

  Future<void> _addEmail(BuildContext context, WidgetRef ref, bool hasPassword) async {
    final done = await showDialog<bool>(context: context, builder: (_) => _EmailDialog(api: ref.read(apiProvider), hasPassword: hasPassword));
    if (done == true) {
      ref.invalidate(signInMethodsProvider);
      ref.invalidate(meProvider);
      if (context.mounted) _toast(context, 'Email added');
    }
  }

  Future<void> _setupTotp(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    try {
      final s = await api.post('/me/totp/setup', {}) as Map;
      if (!context.mounted) return;
      final done = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _TotpDialog(secret: '${s['secret']}', uri: '${s['uri']}', api: api));
      if (done == true) ref.invalidate(signInMethodsProvider);
    } catch (e) {
      if (context.mounted) _toast(context, e is ApiException ? e.message : 'Something went wrong');
    }
  }
}

class _TotpDialog extends StatefulWidget {
  const _TotpDialog({required this.secret, required this.uri, required this.api});
  final String secret, uri;
  final Api api;
  @override
  State<_TotpDialog> createState() => _TotpDialogState();
}

class _TotpDialogState extends State<_TotpDialog> with BusyError {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Set up authenticator'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Scan this QR code with Google Authenticator, Authy or Microsoft Authenticator, then enter the 6-digit code it shows.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Center(child: QrImageView(data: widget.uri, size: 180, backgroundColor: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SelectableText(widget.secret, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              IconButton(icon: const Icon(LucideIcons.copy, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: widget.secret))),
            ]),
            const SizedBox(height: 8),
            OtpField(controller: _code),
            ErrorText(error),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) return setState(() => error = 'Enter the 6-digit code');
                    await run(() => widget.api.post('/me/totp/enable', {'code': _code.text}));
                    if (error == null && context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Turn on'),
          ),
        ],
      );
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.api, required this.hasPassword});
  final Api api;
  final bool hasPassword; // true: confirm the current password; false (phone-only account): this becomes the first password
  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> with BusyError {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add email'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              EmailField(controller: _email),
              const SizedBox(height: 14),
              PasswordField(
                controller: _pw,
                label: widget.hasPassword ? 'Your current password' : 'Create a password',
                validator: widget.hasPassword ? V.loginPassword : V.newPassword,
                newPassword: !widget.hasPassword,
              ),
              ErrorText(error),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    await run(() => widget.api.post('/me/email', {'email': _email.text.trim(), 'password': _pw.text}));
                    if (error == null && context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Add email'),
          ),
        ],
      );
}
