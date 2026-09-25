import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Demo credentials are prefilled in debug builds only.
  final _id = TextEditingController(text: (kDebugMode || demoMode) ? 'customer@abc.com' : '');
  final _pw = TextEditingController(text: (kDebugMode || demoMode) ? 'Skylyf@123' : '');
  bool _busy = false, _hide = true;
  Role _demoRole = Role.customer;
  String? _error;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(_id.text.trim(), _pw.text);
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _busy = false; });
    }
  }

  static const _demoLogins = {Role.customer: 'customer@abc.com', Role.technician: 'tech@skylyf.com', Role.admin: 'owner@skylyf.com'};

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const LogoBadge(width: 210),
                const SizedBox(height: 28),
                GlassCard(
                  padding: const EdgeInsets.all(22),
                  radius: 28,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Machine Monitoring', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Muted('Sign in to see your plant', size: 13),
                    const SizedBox(height: 18),
                    if (demoMode) ...[
                      const Muted('Sign in as', size: 12),
                      const SizedBox(height: 6),
                      Segments<Role>(
                        options: [for (final r in Role.values) (r, r.label)],
                        value: _demoRole,
                        onChanged: (r) => setState(() {
                          _demoRole = r;
                          _id.text = _demoLogins[r]!;
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(labelText: 'Email or phone', prefixIcon: Icon(LucideIcons.user)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pw,
                      obscureText: _hide,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(LucideIcons.lock),
                        suffixIcon: IconButton(icon: Icon(_hide ? LucideIcons.eyeOff : LucideIcons.eye), onPressed: () => setState(() => _hide = !_hide)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : Text(t('Login')),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                const Muted('EVERYTHING YOUR PRODUCTION NEEDS'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
