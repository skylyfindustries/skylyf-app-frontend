import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import 'auth_widgets.dart';
import 'company_details.dart';

/// Owner (factory / account owner) self-registration. Technicians are added later by the owner; Skylyf staff are created by Skylyf.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with BusyError {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _company2 = CompanyDetailsInput(); // address + government IDs (optional)
  final _email = TextEditingController();
  final _phone = PhoneInput();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _owned = <String, int>{}; // catalogId → how many of that model the owner has

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await run(() => ref.read(authProvider.notifier).signIn((api) => api.register({
          'name': _name.text.trim(),
          'companyName': _company.text.trim(),
          ..._company2.toFields(),
          'email': _email.text.trim(),
          'countryCode': _phone.country.dial,
          'phone': _phone.national,
          'password': _pw.text,
          'machines': [
            for (final e in _owned.entries)
              for (var i = 0; i < e.value; i++) {'catalogId': e.key},
          ],
        })));
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _email, _pw, _pw2]) {
      c.dispose();
    }
    _phone.dispose();
    _company2.dispose();
    super.dispose();
  }

  Widget _text(TextEditingController c, String label, IconData icon, String? Function(String?) v, int max, {TextCapitalization cap = TextCapitalization.words, TextInputAction action = TextInputAction.next}) => above(label, TextFormField(
        controller: c,
        textCapitalization: cap,
        textInputAction: action,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: [LengthLimitingTextInputFormatter(max)],
        validator: v,
        decoration: InputDecoration(prefixIcon: Icon(icon), counterText: ''),
      ));

  @override
  Widget build(BuildContext context) => AuthShell(
        back: true,
        brand: false,
        titleAbove: true,
        title: 'Register',
        subtitle: 'For factory owners. You can add technicians after signing in.',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _text(_name, 'Your name', LucideIcons.user, (v) => V.name(v, 'Name'), 60),
            const SizedBox(height: 14),
            _text(_company, 'Company / factory name', LucideIcons.building2, (v) => V.name(v, 'Company name'), 80),
            const SizedBox(height: 14),
            EmailField(controller: _email),
            const SizedBox(height: 14),
            PhoneField(input: _phone),
            CompanyDetailsSection(input: _company2),
            const SizedBox(height: 22),
            MachinePicker(counts: _owned, onChanged: () => setState(() {})),
            const SizedBox(height: 14),
            PasswordField(controller: _pw, newPassword: true, validator: V.newPassword, action: TextInputAction.next),
            PasswordChecklist(controller: _pw),
            const SizedBox(height: 14),
            PasswordField(controller: _pw2, newPassword: true, label: 'Confirm password', validator: V.confirm(() => _pw.text), onSubmitted: _submit),
            ErrorText(error),
            const SizedBox(height: 20),
            BusyButton(label: 'Create account', busy: busy, onPressed: _submit, icon: LucideIcons.userPlus),
          ]),
        ),
      );
}

/// "Which machines do you have?": the models come from the dashboard (GET /catalog). Optional; the admin confirms them later.
class MachinePicker extends ConsumerWidget {
  const MachinePicker({super.key, required this.counts, required this.onChanged});
  final Map<String, int> counts;
  final VoidCallback onChanged;
  static const _max = 30;

  int get _total => counts.values.fold(0, (a, b) => a + b);

  void _set(String id, int n) {
    if (n <= 0) {
      counts.remove(id);
    } else {
      counts[id] = n;
    }
    onChanged();
  }

  Widget _row(CatalogItem c) {
    final n = counts[c.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
      decoration: glassTint(n > 0 ? Brand.gold500 : Colors.white, 40, n > 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text([c.name, if (c.speed.isNotEmpty) c.speed].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
          ]),
        ),
        if (n > 0) ...[
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.minus, size: 18), onPressed: () => _set(c.id, n - 1)),
          Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
        IconButton.filled(
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.plus, size: 18),
          onPressed: _total >= _max ? null : () => _set(c.id, n + 1),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Which machines do you have? (optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 4),
      const Muted('Tap + for each machine you own. Skylyf confirms them and they then appear in your app.', size: 12),
      const SizedBox(height: 10),
      catalog.when(
        loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: Brand.gold500))),
        error: (_, __) => Row(children: [
          const Expanded(child: Muted("Couldn't load the machine list.")),
          TextButton(onPressed: () => ref.invalidate(catalogProvider), child: const Text('Retry')),
        ]),
        data: (list) => list.isEmpty ? const Muted('No machines listed yet. You can add yours after signing in.') : Column(children: [for (final c in list) _row(c)]),
      ),
    ]);
  }
}
