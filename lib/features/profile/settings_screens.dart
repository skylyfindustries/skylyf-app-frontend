import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

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
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: color));
}

// =====================================================================
// Security
// =====================================================================
class DeviceSession {
  const DeviceSession(this.id, this.name, this.place, this.when, this.icon, {this.current = false});
  final String id, name, place, when;
  final IconData icon;
  final bool current;
}

class SecurityState {
  const SecurityState({this.twoStep = false, this.appLock = false, this.biometric = false, this.sessions = _defaultSessions});
  final bool twoStep, appLock, biometric;
  final List<DeviceSession> sessions;

  /// 0–100, shown as the account protection meter.
  int get score => 40 + (twoStep ? 30 : 0) + (appLock ? 20 : 0) + (biometric ? 10 : 0);

  SecurityState copyWith({bool? twoStep, bool? appLock, bool? biometric, List<DeviceSession>? sessions}) =>
      SecurityState(twoStep: twoStep ?? this.twoStep, appLock: appLock ?? this.appLock, biometric: biometric ?? this.biometric, sessions: sessions ?? this.sessions);
}

const _defaultSessions = [
  DeviceSession('s1', 'This device • Pixel (Android)', 'Noida, India', 'Active now', LucideIcons.smartphone, current: true),
  DeviceSession('s2', 'Chrome on Windows', 'Noida, India', '2 days ago', LucideIcons.monitor),
  DeviceSession('s3', 'Samsung Galaxy (Android)', 'Delhi, India', '9 days ago', LucideIcons.smartphone),
];

class SecurityNotifier extends Notifier<SecurityState> {
  @override
  SecurityState build() => const SecurityState();
  void setTwoStep(bool v) => state = state.copyWith(twoStep: v);
  void setAppLock(bool v) => state = state.copyWith(appLock: v, biometric: v ? state.biometric : false);
  void setBiometric(bool v) => state = state.copyWith(biometric: v);
  void signOut(String id) => state = state.copyWith(sessions: [for (final s in state.sessions) if (s.id != id) s]);
  void signOutOthers() => state = state.copyWith(sessions: [for (final s in state.sessions) if (s.current) s]);
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(SecurityNotifier.new);

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sec = ref.watch(securityProvider);
    final n = ref.read(securityProvider.notifier);
    Widget sw(bool value, ValueChanged<bool>? on, IconData icon, String title, String sub) => SwitchListTile.adaptive(
          value: value,
          onChanged: on,
          secondary: _IconBox(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        );

    return GlassPage(
      title: 'Security',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        _Score(sec.score).reveal(0),
        const SectionTitle(LucideIcons.keyRound, 'Change password').reveal(1),
        const _PasswordForm().reveal(1),
        const SectionTitle(LucideIcons.shieldCheck, 'Sign-in protection').reveal(2),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            sw(sec.twoStep, n.setTwoStep, LucideIcons.smartphoneNfc, 'Two-step verification', 'Ask for an SMS code when signing in on a new device'),
            const Divider(height: 1, color: Brand.line),
            sw(sec.appLock, n.setAppLock, LucideIcons.lockKeyhole, 'App lock', 'Require a PIN when the app is opened'),
            const Divider(height: 1, color: Brand.line),
            sw(sec.biometric, sec.appLock ? n.setBiometric : null, LucideIcons.fingerprint, 'Fingerprint / face unlock', sec.appLock ? 'Unlock faster with your biometrics' : 'Turn on App lock first'),
          ]),
        ).reveal(2),
        SectionTitle(LucideIcons.monitorSmartphone, 'Where you are signed in').reveal(3),
        for (final s in sec.sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(children: [
                _IconBox(s.icon, color: s.current ? Brand.running : Brand.navy500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Muted('${s.place} • ${s.when}', size: 12),
                  ]),
                ),
                if (!s.current) TextButton(onPressed: () => n.signOut(s.id), child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          ).reveal(3),
        if (sec.sessions.length > 1)
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
              if (ok == true) n.signOutOthers();
            },
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Sign out all other devices'),
          ),
        const SectionTitle(LucideIcons.history, 'Recent sign-ins').reveal(4),
        const GlassCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            _LoginRow('Today, 10:02', 'Pixel • Noida', true),
            Divider(height: 1, color: Brand.line),
            _LoginRow('Yesterday, 18:40', 'Chrome • Noida', true),
            Divider(height: 1, color: Brand.line),
            _LoginRow('22 Sep, 02:13', 'Unknown device • Mumbai', false),
            Divider(height: 1, color: Brand.line),
            _LoginRow('20 Sep, 09:31', 'Samsung • Delhi', true),
          ]),
        ).reveal(4),
        const SizedBox(height: 12),
        const Muted('You only ever see machines that belong to your company. Sign-in attempts are logged and suspicious ones are blocked.', size: 12),
      ]),
    );
  }
}

class _LoginRow extends StatelessWidget {
  const _LoginRow(this.when, this.where, this.ok);
  final String when, where;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleX, size: 18, color: ok ? Brand.running : Brand.stopped),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(where, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Muted(when, size: 11)])),
          Text(ok ? 'Success' : 'Blocked', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ok ? Brand.running : Brand.stopped)),
        ]),
      );
}

class _Score extends StatelessWidget {
  const _Score(this.score);
  final int score;

  @override
  Widget build(BuildContext context) {
    final (label, color) = score >= 90 ? ('Excellent', Brand.running) : score >= 70 ? ('Good', Brand.gold300) : ('Basic', Brand.idle);
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
            Muted(score >= 90 ? 'All protections are on.' : 'Turn on two-step verification and app lock to be fully protected.', size: 12),
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
          TextFormField(
            controller: _cur,
            obscureText: _hide,
            decoration: InputDecoration(labelText: 'Current password', prefixIcon: const Icon(LucideIcons.lock), suffixIcon: IconButton(icon: Icon(_hide ? LucideIcons.eyeOff : LucideIcons.eye, size: 20), onPressed: () => setState(() => _hide = !_hide))),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _new,
            obscureText: _hide,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(LucideIcons.keyRound)),
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
          ),
          if (_new.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: AnimatedBar(strength / 4, color: color, height: 6)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
            ]),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: _hide,
            decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(LucideIcons.shieldCheck)),
            validator: (v) => v != _new.text ? 'Passwords do not match' : null,
          ),
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
