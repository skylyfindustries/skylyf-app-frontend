import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'sign_in_methods.dart';

// =====================================================================
// Settings
// =====================================================================
class PrefsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {'stopped': true, 'target': true, 'service': true, 'daily': false};
  void toggle(String key, bool v) => state = {...state, key: v};
}

final prefsProvider = NotifierProvider<PrefsNotifier, Map<String, bool>>(PrefsNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final lang = ref.watch(langProvider);
    Widget sw(String key, IconData icon, String title, String sub) => SwitchListTile.adaptive(
          value: prefs[key]!,
          onChanged: (v) => ref.read(prefsProvider.notifier).toggle(key, v),
          secondary: _IconBox(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        );

    return GlassPage(
      title: 'Settings',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const SectionTitle(LucideIcons.bellRing, 'Notifications').reveal(0),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            sw('stopped', LucideIcons.octagonAlert, 'Machine stopped', 'Instant alert when a machine goes down'),
            const Divider(height: 1, color: Brand.line),
            sw('target', LucideIcons.target, 'Target missed', 'When a shift finishes below target'),
            const Divider(height: 1, color: Brand.line),
            sw('service', LucideIcons.wrench, 'Service reminders', 'Before scheduled maintenance is due'),
            const Divider(height: 1, color: Brand.line),
            sw('daily', LucideIcons.fileText, 'Daily summary', 'A production report every evening'),
          ]),
        ).reveal(1),
        const SectionTitle(LucideIcons.languages, 'Language').reveal(2),
        Segments<String>(options: const [('en', 'English'), ('hi', 'हिन्दी')], value: lang, onChanged: (v) => ref.read(langProvider.notifier).set(v)).reveal(2),
        const SectionTitle(LucideIcons.slidersHorizontal, 'Display').reveal(3),
        const GlassCard(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(children: [
            InfoRow('Live data refresh', 'Every 15 seconds'),
            Divider(height: 1, color: Brand.line),
            InfoRow('Time zone', 'India Standard Time (IST)'),
            Divider(height: 1, color: Brand.line),
            InfoRow('Shifts', 'A 06–14 · B 14–22 · C 22–06'),
            Divider(height: 1, color: Brand.line),
            InfoRow('Speed units', 'Set by machine type'),
          ]),
        ).reveal(3),
        const SectionTitle(LucideIcons.info, 'About').reveal(4),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(children: [
            const InfoRow('App version', '1.0.0 (demo)'),
            const Divider(height: 1, color: Brand.line),
            _LinkRow('Terms of service', () => _soon(context)),
            const Divider(height: 1, color: Brand.line),
            _LinkRow('Privacy policy', () => _soon(context)),
          ]),
        ).reveal(4),
      ]),
    );
  }

  void _soon(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Available on skylyf.com')));
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(LucideIcons.externalLink, size: 16, color: Brand.inkSoft)])),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.color = Brand.gold300});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: glassTint(color, 12), child: Icon(icon, size: 20, color: color));
}

// =====================================================================
// Security
// =====================================================================
typedef DeviceSession = ({String id, String device, String ip, String place, DateTime lastSeenAt, bool current});
typedef LoginEntry = ({bool ok, String method, String reason, String device, String ip, String place, DateTime at});

final sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/me/sessions') as List;
  return [for (final r in rows) (id: '${r['id']}', device: '${r['device'] ?? 'Unknown device'}', ip: '${r['ip'] ?? ''}', place: '${r['place'] ?? ''}', lastSeenAt: DateTime.parse(r['lastSeenAt']).toLocal(), current: r['current'] == true)];
});

final loginsProvider = FutureProvider.autoDispose<List<LoginEntry>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/me/logins') as List;
  return [for (final r in rows) (ok: r['ok'] == true, method: '${r['method'] ?? ''}', reason: '${r['reason'] ?? ''}', device: '${r['device'] ?? 'Unknown device'}', ip: '${r['ip'] ?? ''}', place: '${r['place'] ?? ''}', at: DateTime.parse(r['at']).toLocal())];
});

IconData _deviceIcon(String device) => RegExp('app|Android|iOS', caseSensitive: false).hasMatch(device) ? LucideIcons.smartphone : LucideIcons.monitor;
/// "Noida, Uttar Pradesh, India • 203.0.113.7" (the place appears a moment after sign-in; the IP is always there)
String _where(String place, String ip) => [place, ip.replaceFirst('::ffff:', '')].where((x) => x.isNotEmpty).join(' • ');

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<void> _revoke(BuildContext context, WidgetRef ref, Future<dynamic> Function() call) async {
    try {
      await call();
      ref.invalidate(sessionsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Something went wrong')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final methods = ref.watch(signInMethodsProvider).valueOrNull;
    final sessions = ref.watch(sessionsProvider);
    final logins = ref.watch(loginsProvider);

    return GlassPage(
      title: 'Security',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(signInMethodsProvider);
          ref.invalidate(sessionsProvider);
          ref.invalidate(loginsProvider);
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          _Score(methods).reveal(0),
          const SectionTitle(LucideIcons.keyRound, 'Change password').reveal(1),
          const _PasswordForm().reveal(1),
          const SignInMethods().reveal(2),
          SectionTitle(LucideIcons.monitorSmartphone, 'Where you are signed in').reveal(3),
          asyncView<List<DeviceSession>>(
            sessions,
            (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(children: [
                      _IconBox(_deviceIcon(s.device), color: s.current ? Brand.running : Brand.navy500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.current ? 'This device • ${s.device}' : s.device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Muted(s.current ? 'Active now' : 'Active ${timeAgo(s.lastSeenAt)}', size: 12),
                          if (_where(s.place, s.ip).isNotEmpty) Muted(_where(s.place, s.ip), size: 12),
                        ]),
                      ),
                      if (!s.current) TextButton(onPressed: () => _revoke(context, ref, () => api.delete('/me/sessions/${s.id}')), child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
              if (list.length > 1)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Sign out other devices?'),
                        content: const Text('You will stay signed in on this device only.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out'))],
                      ),
                    );
                    if (ok == true && context.mounted) _revoke(context, ref, () => api.post('/me/sessions/revoke-others', {}));
                  },
                  icon: const Icon(LucideIcons.logOut, size: 18),
                  label: const Text('Sign out all other devices'),
                ),
            ]),
            onRetry: () => ref.invalidate(sessionsProvider),
          ).reveal(3),
          const SectionTitle(LucideIcons.history, 'Recent sign-ins').reveal(4),
          asyncView<List<LoginEntry>>(
            logins,
            (list) => GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: list.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Muted('No sign-ins recorded yet.', size: 13))
                  : Column(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Brand.line),
                        _LoginRow(timeAgo(list[i].at), '${list[i].device}${_where(list[i].place, list[i].ip).isEmpty ? '' : '\n${_where(list[i].place, list[i].ip)}'}', list[i].ok, list[i].ok ? list[i].method : list[i].reason),
                      ],
                    ]),
            ),
            onRetry: () => ref.invalidate(loginsProvider),
          ).reveal(4),
          const SizedBox(height: 12),
          const Muted('You only ever see machines that belong to your company. Every sign-in attempt on your account is logged here.', size: 12),
        ]),
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  const _LoginRow(this.when, this.where, this.ok, this.note);
  final String when, where, note;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleX, size: 18, color: ok ? Brand.running : Brand.stopped),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(where, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Muted(when, size: 11)])),
          Text(ok ? (note.isEmpty ? 'Success' : note) : (note.isEmpty ? 'Failed' : note), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ok ? Brand.running : Brand.stopped)),
        ]),
      );
}

class _Score extends StatelessWidget {
  const _Score(this.methods);
  final SignInMethodsInfo? methods;

  @override
  Widget build(BuildContext context) {
    // password = 40, authenticator app = +30, at least one passkey = +30
    final totp = methods?.totp ?? false, passkey = methods?.passkeys.isNotEmpty ?? false;
    final score = 40 + (totp ? 30 : 0) + (passkey ? 30 : 0);
    final (label, color) = score >= 100 ? ('Excellent', Brand.running) : score >= 70 ? ('Good', Brand.gold300) : ('Basic', Brand.idle);
    final todo = [if (!totp) 'an authenticator app', if (!passkey) 'a passkey'];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Ring(value: score, label: '', color: color, size: 78),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Muted('Account protection', size: 13),
            Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Muted(methods == null ? 'Checking…' : todo.isEmpty ? 'All protections are on.' : 'Add ${todo.join(' and ')} to be fully protected.', size: 12),
          ]),
        ),
      ]),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 0..4 — length, upper+lower, digit, symbol
  int get _strength {
    final p = _new.text;
    return [p.length >= 8, RegExp('[a-z]').hasMatch(p) && RegExp('[A-Z]').hasMatch(p), RegExp('[0-9]').hasMatch(p), RegExp(r'[^A-Za-z0-9]').hasMatch(p)].where((b) => b).length;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(apiProvider).post('/auth/password', {'currentPassword': _cur.text, 'newPassword': _new.text});
      if (!mounted) return;
      _cur.clear();
      _new.clear();
      _confirm.clear();
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final (label, color) = switch (strength) { 0 || 1 => ('Weak', Brand.stopped), 2 => ('Fair', Brand.idle), 3 => ('Good', Brand.gold300), _ => ('Strong', Brand.running) };
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          above('Current password', TextFormField(
            controller: _cur,
            obscureText: _hide,
            decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.lock), suffixIcon: IconButton(icon: Icon(_hide ? LucideIcons.eyeOff : LucideIcons.eye, size: 20), onPressed: () => setState(() => _hide = !_hide))),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
          )),
          const SizedBox(height: 12),
          above('New password', TextFormField(
            controller: _new,
            obscureText: _hide,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.keyRound)),
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
          )),
          if (_new.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: AnimatedBar(strength / 4, color: color, height: 6)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
            ]),
          ],
          const SizedBox(height: 12),
          above('Confirm new password', TextFormField(
            controller: _confirm,
            obscureText: _hide,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.shieldCheck)),
            validator: (v) => v != _new.text ? 'Passwords do not match' : null,
          )),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900)) : const Text('Update password')),
        ]),
      ),
    );
  }
}

// =====================================================================
// Help & support
// =====================================================================
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) throw 'no app';
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open that on this device')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const faqs = [
      ('Why does my machine show Idle?', 'Idle means the machine is powered and connected but not producing, for example while waiting for material or during a break.'),
      ('How do I register a new machine?', 'Open Machines → Register new, choose your model, and enter the serial number from the nameplate. Skylyf verifies it within 24 hours.'),
      ('How is efficiency calculated?', 'Efficiency is today\'s production divided by today\'s target. OEE combines availability, performance and quality.'),
      ('How do I order spare parts?', 'Open a machine and tap Parts, or use the Parts tab. Choose the machine, pick the part and tap Buy.'),
      ('Who can see my machine data?', 'Only users of your company. Skylyf service engineers can view machines only when they are working on a service request.'),
    ];
    Widget contact(IconData icon, String title, String sub, String url) => GlassCard(
          onTap: () => _open(context, url),
          child: Row(children: [_IconBox(icon), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Muted(sub, size: 12)])), const Icon(LucideIcons.chevronRight, size: 18, color: Brand.inkSoft)]),
        );

    return GlassPage(
      title: 'Help & support',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const SectionTitle(LucideIcons.lifeBuoy, 'Talk to Skylyf').reveal(0),
        contact(LucideIcons.phone, 'Call support', '+91 98765 43210 • 9 am – 7 pm', 'tel:+919876543210').reveal(1),
        const SizedBox(height: 10),
        contact(LucideIcons.mail, 'Email us', 'support@skylyf.com', 'mailto:support@skylyf.com').reveal(2),
        const SizedBox(height: 10),
        contact(LucideIcons.messageCircle, 'WhatsApp', 'Chat with a service engineer', 'https://wa.me/919876543210').reveal(3),
        const SectionTitle(LucideIcons.circleHelp, 'Common questions').reveal(4),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(children: [
            for (final (i, f) in faqs.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: Brand.gold300,
                    collapsedIconColor: Brand.inkSoft,
                    title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [Text(f.$2, style: const TextStyle(color: Brand.inkSoft, height: 1.4, fontSize: 13))],
                  ),
                ).reveal(4 + i),
              ),
          ]),
        ),
      ]),
    );
  }
}
