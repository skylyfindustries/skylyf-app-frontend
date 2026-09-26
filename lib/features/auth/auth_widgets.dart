import 'dart:ui';
import 'dart:async';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/countries.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';

/// Same theme with fully rounded (pill) inputs and buttons.
ThemeData _pill(ThemeData t) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: c, width: w));
  return t.copyWith(
    inputDecorationTheme: t.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      border: b(Brand.line),
      enabledBorder: b(Brand.line),
      focusedBorder: b(Brand.gold500, 1.6),
      errorBorder: b(Brand.stopped),
      focusedErrorBorder: b(Brand.stopped, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(style: t.filledButtonTheme.style?.merge(FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(56), backgroundBuilder: glassButton(999, active: true)))),
  );
}

/// Shared frame for sign-in, register and forgot-password: glass background, animated gears, logo, card.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.title, required this.subtitle, required this.child, this.back = false, this.footer, this.brand = true, this.titleAbove = false, this.image, this.icon});
  final String title, subtitle;
  final String? image; // asset shown above the heading
  final IconData? icon; // badge above the heading; also pins the content to the top of the screen
  final Widget child;
  final bool back, brand, titleAbove; // brand: gears animation + logo above the card; titleAbove: heading top-left, outside the card
  final Widget? footer;

  /// Full-bleed picture behind the status bar, heading + form in a rounded sheet overlapping its bottom edge.
  Widget _withHero(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: Brand.cream,
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: h * 0.42, child: Image.asset(image!, fit: BoxFit.cover)),
        SingleChildScrollView(
          child: Column(children: [
            SizedBox(height: h * 0.36),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: h * 0.64),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.72), Brand.cream.withValues(alpha: 0.86)]),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.9))),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(title, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Muted(subtitle, size: 16),
                    const SizedBox(height: 20),
                    Theme(data: _pill(Theme.of(context)), child: child),
                    if (footer != null) ...[const SizedBox(height: 16), footer!],
                  ]),
                ),
              ),
            ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => image != null ? _withHero(context) : GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: back ? AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/login'))) : null,
          body: SafeArea(
            child: Column(children: [
              Expanded(child: Align(
              alignment: icon != null ? Alignment.topCenter : Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: titleAbove ? 520 : 460),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (brand) ...[const GearsAnimation(size: 96), const LogoBadge(width: 170), const SizedBox(height: 22)],
                    if (titleAbove) // heading sits right above the inputs, whole block centred
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (icon != null) Container(
                            width: 64, height: 64, margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(color: Brand.gold500.withValues(alpha: 0.18), shape: BoxShape.circle),
                            child: Icon(icon, size: 30, color: Brand.gold300),
                          ),
                          Text(title, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Muted(subtitle, size: 16),
                        ])),
                      ),
                    if (titleAbove)
                      Theme(data: _pill(Theme.of(context)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [child])) // login/register: no card, full-width pill inputs
                    else
                      GlassCard(
                        padding: const EdgeInsets.all(22),
                        radius: 28,
                        alpha: titleAbove ? 0.22 : 0.78, // login: frosted-glass look
                        blur: titleAbove ? 28 : 14,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (!titleAbove) ...[
                            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Muted(subtitle, size: 13),
                            const SizedBox(height: 18),
                          ],
                          child,
                        ]),
                      ),
                      if (footer != null) ...[const SizedBox(height: 16), footer!],
                  ]),
                ),
              ),
            )),
            ]),
          ),
        ),
      );
}

class GearsAnimation extends StatelessWidget {
  const GearsAnimation({super.key, this.size = 96});
  final double size;
  @override
  Widget build(BuildContext context) => Lottie.asset('assets/lottie/gears.json', width: size, height: size, repeat: true);
}

/// Plays once (e.g. after a password reset).
class SuccessAnimation extends StatelessWidget {
  const SuccessAnimation({super.key, this.size = 96});
  final double size;
  @override
  Widget build(BuildContext context) => Lottie.asset('assets/lottie/success.json', width: size, height: size, repeat: false);
}

enum Method {
  email(LucideIcons.mail, 'Email'),
  phone(LucideIcons.messageCircle, 'WhatsApp'),
  passkey(LucideIcons.fingerprint, 'Passkey'),
  authenticator(LucideIcons.smartphoneNfc, 'Authenticator');

  const Method(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Icon-only method switcher. Tapping the selected icon goes back to the default (email + password).
class MethodIcons extends StatelessWidget {
  const MethodIcons({super.key, required this.value, required this.onChanged});
  final Method value;
  final ValueChanged<Method> onChanged;

  // WhatsApp brand logo supplied as assets/whatsapp.png; falls back to a generic icon until the file exists.
  Widget _icon(Method m, bool on) => m == Method.phone
      ? Image.asset('assets/whatsapp.png', width: 34, height: 34, errorBuilder: (_, __, ___) => Icon(m.icon, size: 24, color: on ? Brand.navy900 : Brand.inkSoft))
      : Icon(m.icon, size: 24, color: on ? Brand.navy900 : Brand.inkSoft);

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final m in Method.values.where((m) => m != Method.email))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: m.label,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onChanged(m == value ? Method.email : m),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: m == value ? [Brand.gold300.withValues(alpha: 0.95), Brand.gold500.withValues(alpha: 0.75)] : [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0.22)]),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                    boxShadow: m == value ? [BoxShadow(color: Brand.gold500.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))] : null,
                  ),
                  child: _icon(m, m == value),
                ),
              ),
            ),
          ),
      ]);
}

class MethodPicker extends StatelessWidget {
  const MethodPicker({super.key, required this.value, required this.onChanged, this.labels = const {}});
  final Method value;
  final ValueChanged<Method> onChanged;
  final Map<Method, String> labels; // per-screen wording, e.g. "Email link" when resetting

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in Method.values)
          ChoiceChip(
            avatar: Icon(m.icon, size: 16, color: m == value ? Brand.navy900 : Brand.inkSoft),
            label: Text(labels[m] ?? m.label),
            selected: m == value,
            showCheckmark: false,
            selectedColor: Brand.gold500,
            backgroundColor: Colors.white.withValues(alpha: 0.8),
            side: const BorderSide(color: Brand.line),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: m == value ? Brand.navy900 : Brand.ink),
            onSelected: (_) => onChanged(m),
          ),
      ]);
}

/// busy flag + inline error for any async action; keeps every form's error handling identical.
mixin BusyError<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() f) async {
    setState(() { busy = true; error = null; });
    try {
      await f();
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) setState(() { error = e is ApiException ? e.message : 'Something went wrong. Try again.'; busy = false; });
    }
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});
  final String? text;
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 12), child: Text(text!, style: const TextStyle(color: Brand.stopped, fontWeight: FontWeight.w600)));
}

class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed, this.icon});
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.navy900))
            : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ]),
      );
}

const _validate = AutovalidateMode.onUserInteraction;

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.label = 'Email'});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => above(label, TextFormField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autovalidateMode: _validate,
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(254), FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        validator: V.email,
        decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.mail, size: 18), counterText: ''),
      ));
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.validator, this.label = 'Password', this.onSubmitted, this.action = TextInputAction.done, this.newPassword = false});
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String label;
  final VoidCallback? onSubmitted;
  final TextInputAction action;
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) => above(widget.label, TextFormField(
        controller: widget.controller,
        obscureText: _hide,
        autovalidateMode: _validate,
        textInputAction: widget.action,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        inputFormatters: [LengthLimitingTextInputFormatter(widget.newPassword ? 64 : 128)],
        validator: widget.validator,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        decoration: InputDecoration(
          prefixIcon: const Icon(LucideIcons.lock, size: 18),
          suffixIcon: IconButton(iconSize: 18, icon: Icon(_hide ? LucideIcons.eyeOff : LucideIcons.eye), onPressed: () => setState(() => _hide = !_hide)),
        ),
      ));
}

class OtpField extends StatefulWidget {
  const OtpField({super.key, required this.controller, this.label = '6-digit code', this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final VoidCallback? onSubmitted;
  @override
  State<OtpField> createState() => _OtpFieldState();
}

/// Six boxes drawn from the controller; a transparent TextField on top takes the typing.
class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
    _focus.addListener(_tick);
  }

  void _tick() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return above(widget.label, FormField<String>(
      autovalidateMode: _validate,
      validator: (_) => V.otp(widget.controller.text),
      builder: (f) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 54,
          child: Stack(children: [
            Row(children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: f.hasError ? Brand.stopped : (_focus.hasFocus && i == text.length.clamp(0, 5)) ? Brand.gold500 : Brand.line, width: _focus.hasFocus && i == text.length.clamp(0, 5) ? 1.6 : 1),
                    ),
                    child: Text(i < text.length ? text[i] : '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                ),
              ],
            ]),
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, counterText: ''),
                onChanged: f.didChange,
                onSubmitted: (_) => widget.onSubmitted?.call(),
              ),
            ),
          ]),
        ),
        if (f.hasError) Padding(padding: const EdgeInsets.only(left: 4, top: 6), child: Text(f.errorText!, style: const TextStyle(color: Brand.stopped, fontSize: 12))),
      ]),
    ));
  }
}

// ---------------- phone with country code ----------------

class PhoneInput {
  Country country = india;
  final text = TextEditingController();
  String get national => text.text.replaceAll(RegExp(r'\D'), '');
  void dispose() => text.dispose();
}

class FlagIcon extends StatelessWidget {
  const FlagIcon(this.iso, {super.key});
  final String iso;
  @override
  Widget build(BuildContext context) => CountryFlag.fromCountryCode(iso, theme: const ImageTheme(width: 28, height: 20, shape: RoundedRectangle(4)));
}

class PhoneField extends StatefulWidget {
  const PhoneField({super.key, required this.input, this.enabled = true});
  final PhoneInput input;
  final bool enabled;
  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  PhoneInput get i => widget.input;

  Future<void> _pick() async {
    final c = await showModalBottomSheet<Country>(context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: Brand.cream, builder: (_) => _CountrySheet(selected: i.country));
    if (c == null) return;
    setState(() {
      i.country = c;
      // a longer number pasted for another country is trimmed to what that country allows
      final d = i.national;
      if (d.length > c.max) i.text.text = d.substring(0, c.max);
    });
  }

  @override
  Widget build(BuildContext context) => above('Phone number', TextFormField(
        controller: i.text,
        enabled: widget.enabled,
        keyboardType: TextInputType.phone,
        autovalidateMode: _validate,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(i.country.max)],
        validator: V.phone(() => i.country),
        decoration: InputDecoration(
          counterText: '',
          prefixIcon: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.enabled ? _pick : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                FlagIcon(i.country.iso),
                const SizedBox(width: 8),
                Text(i.country.dial, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink)),
                const Icon(LucideIcons.chevronDown, size: 16),
                const SizedBox(width: 6),
                Container(width: 1, height: 24, color: Brand.line),
              ]),
            ),
          ),
        ),
      ));
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});
  final Country selected;
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().replaceAll('+', '');
    final list = [for (final c in countries) if (c.name.toLowerCase().contains(q) || c.dial.contains(q) || c.iso.toLowerCase() == q) c];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(autofocus: false, onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search country or code', prefixIcon: Icon(LucideIcons.search))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, k) {
                final c = list[k];
                return ListTile(
                  leading: FlagIcon(c.iso),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(c.dial, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.inkSoft)),
                  selected: c.iso == widget.selected.iso,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- method panels shared by sign-in and forgot-password ----------------

/// Phone → WhatsApp code → [onVerify]. Same UI for signing in and for resetting.
class PhoneOtpPanel extends StatefulWidget {
  const PhoneOtpPanel({super.key, required this.send, required this.onVerify, required this.verifyLabel, this.extra});
  final Widget? extra; // e.g. the "keep me signed in" row
  final Future<String?> Function(Country country, String phone) send; // returns the dev code when the server could not use WhatsApp
  final Future<void> Function(Country country, String phone, String code) onVerify;
  final String verifyLabel;
  @override
  State<PhoneOtpPanel> createState() => _PhoneOtpPanelState();
}

class _PhoneOtpPanelState extends State<PhoneOtpPanel> with BusyError {
  final _form = GlobalKey<FormState>();
  final _phone = PhoneInput();
  final _code = TextEditingController();
  bool _sent = false;
  String? _devCode;
  int _wait = 0;
  Timer? _timer;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    await run(() async {
      _devCode = await widget.send(_phone.country, _phone.national);
      _sent = true;
      _wait = 30;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => --_wait);
        if (_wait <= 0) t.cancel();
      });
    });
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    await run(() => widget.onVerify(_phone.country, _phone.national, _code.text));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PhoneField(input: _phone, enabled: !_sent),
          if (_sent) ...[
            const SizedBox(height: 14),
            OtpField(controller: _code, onSubmitted: _verify),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Muted('Code sent on WhatsApp to ${_phone.country.dial} ${_phone.national}', size: 12)),
              TextButton(onPressed: _wait > 0 || busy ? null : _send, child: Text(_wait > 0 ? 'Resend in ${_wait}s' : 'Resend')),
            ]),
            if (_devCode != null) Muted('Dev server (WhatsApp not configured): code is $_devCode', size: 12),
            TextButton(onPressed: () => setState(() { _sent = false; _code.clear(); _devCode = null; error = null; }), child: const Text('Change number')),
          ],
          if (widget.extra != null) ...[const SizedBox(height: 10), widget.extra!],
          ErrorText(error),
          const SizedBox(height: 18),
          BusyButton(label: _sent ? widget.verifyLabel : 'Send code on WhatsApp', busy: busy, onPressed: _sent ? _verify : _send, icon: _sent ? null : LucideIcons.send),
        ]),
      );
}

/// Email-or-phone + 6-digit code from the authenticator app.
class AuthenticatorPanel extends StatefulWidget {
  const AuthenticatorPanel({super.key, required this.onVerify, required this.verifyLabel, this.extra});
  final Widget? extra;
  final Future<void> Function(String identifier, String code) onVerify;
  final String verifyLabel;
  @override
  State<AuthenticatorPanel> createState() => _AuthenticatorPanelState();
}

class _AuthenticatorPanelState extends State<AuthenticatorPanel> with BusyError {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _code = TextEditingController();

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    await run(() => widget.onVerify(_id.text.trim(), _code.text));
  }

  @override
  void dispose() {
    _id.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          above('Email or phone (+country code)', TextFormField(
            controller: _id,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: _validate,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(254)],
            validator: V.emailOrPhone,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.user, size: 18), counterText: ''),
          )),
          const SizedBox(height: 14),
          OtpField(controller: _code, label: 'Code from your app', onSubmitted: _go),
          const SizedBox(height: 6),
          const Muted('Open Google Authenticator, Authy or Microsoft Authenticator and enter the current 6-digit code. Set it up first under Profile → Security.', size: 12),
          if (widget.extra != null) ...[const SizedBox(height: 10), widget.extra!],
          ErrorText(error),
          const SizedBox(height: 18),
          BusyButton(label: widget.verifyLabel, busy: busy, onPressed: _go, icon: LucideIcons.shieldCheck),
        ]),
      );
}

class PasskeyPanel extends StatefulWidget {
  const PasskeyPanel({super.key, required this.onGo, required this.label, this.extra});
  final Widget? extra;
  final Future<void> Function() onGo;
  final String label;
  @override
  State<PasskeyPanel> createState() => _PasskeyPanelState();
}

class _PasskeyPanelState extends State<PasskeyPanel> with BusyError {
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Muted('Use your fingerprint, face or screen lock. No password needed. Add a passkey first under Profile → Security.', size: 12),
        if (widget.extra != null) ...[const SizedBox(height: 10), widget.extra!],
        ErrorText(error),
        const SizedBox(height: 18),
        BusyButton(label: widget.label, busy: busy, onPressed: () => run(widget.onGo), icon: LucideIcons.fingerprint),
      ]);
}

/// Live checklist under a new-password field: each rule turns green (with a pop) as it is met, and a bar fills up.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});
  final TextEditingController controller;

  static final _rules = <(String, bool Function(String))>[
    ('8–64 characters', (s) => s.length >= 8 && s.length <= 64),
    ('Lowercase letter', (s) => s.contains(RegExp('[a-z]'))),
    ('Uppercase letter', (s) => s.contains(RegExp('[A-Z]'))),
    ('Number', (s) => s.contains(RegExp(r'\d'))),
    ('Symbol like @ # \$ !', (s) => s.contains(RegExp(r'[^A-Za-z0-9]'))),
    ('No spaces', (s) => s.isNotEmpty && !s.contains(RegExp(r'\s'))),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final s = controller.text;
          final met = [for (final r in _rules) r.$2(s)];
          final done = met.where((m) => m).length;
          final color = done == _rules.length ? Brand.running : done >= 3 ? Brand.idle : Brand.stopped;
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: s.isEmpty ? 0 : done / _rules.length),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 6, color: color, backgroundColor: Brand.track)),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _rules.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [for (final j in [i, i + 1]) Expanded(child: j < _rules.length ? _rule(_rules[j].$1, met[j]) : const SizedBox())]), // two per row
                ),
            ]),
          );
        },
      );

  Widget _rule(String text, bool ok) => Row(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
          child: Icon(ok ? LucideIcons.circleCheck : LucideIcons.circle, key: ValueKey(ok), size: 16, color: ok ? Brand.running : Brand.inkSoft),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(fontSize: 13, fontWeight: ok ? FontWeight.w700 : FontWeight.w500, color: ok ? Brand.running : Brand.inkSoft),
            child: Text(text),
          ),
        ),
      ]);
}

// ---------------- full-height form modal (technician + edit profile share this design) ----------------

Future<T?> showFormSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true, // cover the floating tab bar (the sheet is opened from tab pages)
      showDragHandle: true,
      backgroundColor: Brand.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: child),
    );

/// "Keep me signed in" row for the login screen.
class KeepSignedIn extends StatelessWidget {
  const KeepSignedIn({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), activeColor: Brand.gold500, checkColor: Brand.navy900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), side: const BorderSide(color: Brand.inkSoft, width: 1.6)),
            const SizedBox(width: 4),
            const Flexible(child: Text('Keep me signed in', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          ]),
        ),
      );
}

/// Modal heading: bold title + short description.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Muted(subtitle, size: 13),
        const SizedBox(height: 16),
      ]);
}

/// Section title inside the modal ("Personal details", "Address", ...).
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)));
}

/// Round photo with Gallery / Camera buttons.
class PhotoPickerRow extends StatelessWidget {
  const PhotoPickerRow({super.key, required this.onPick, this.bytes, this.url, this.initial});
  final ValueChanged<ImageSource> onPick;
  final Uint8List? bytes; // just picked
  final String? url; // already saved photo
  final String? initial; // letter shown when there is no photo
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Brand.goldSoft,
            backgroundImage: bytes != null ? MemoryImage(bytes!) : (url != null ? NetworkImage(url!) : null) as ImageProvider?,
            child: bytes == null && url == null
                ? (initial == null || initial!.isEmpty
                    ? const Icon(LucideIcons.user, size: 34, color: Brand.gold300)
                    : Text(initial![0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Brand.gold300)))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: () => onPick(ImageSource.gallery), icon: const Icon(LucideIcons.image, size: 18), label: const Text('Gallery'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44))),
              OutlinedButton.icon(onPressed: () => onPick(ImageSource.camera), icon: const Icon(LucideIcons.camera, size: 18), label: const Text('Camera'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44))),
            ]),
          ),
        ]),
        const Padding(padding: EdgeInsets.only(top: 6), child: Muted('Photo: JPG, PNG or WebP, up to 2 MB', size: 12)),
      ]);
}

/// Text field with the modal's look: leading icon, live validation, length limit. [onTap] makes it a picker (date, time).
class SheetField extends StatelessWidget {
  const SheetField({super.key, required this.controller, required this.label, required this.icon, this.validator, this.max = 60, this.cap = TextCapitalization.words, this.action = TextInputAction.next, this.onTap, this.lines = 1, this.keyboard});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final int max, lines;
  final TextCapitalization cap;
  final TextInputAction action;
  final VoidCallback? onTap;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => above(label, TextFormField(
        controller: controller,
        readOnly: onTap != null,
        onTap: onTap,
        maxLines: lines,
        keyboardType: keyboard,
        textCapitalization: cap,
        textInputAction: lines > 1 ? TextInputAction.newline : action,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: onTap == null ? [LengthLimitingTextInputFormatter(max)] : null,
        validator: validator,
        decoration: InputDecoration(prefixIcon: Icon(icon), counterText: ''),
      ));
}
