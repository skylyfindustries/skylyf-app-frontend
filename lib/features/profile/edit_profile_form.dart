import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/api.dart';
import '../../core/countries.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/company_details.dart';

/// Full-height modal, same design as "Add technician": photo, personal details, and (owners) company details.
Future<bool?> showEditProfile(BuildContext context) => showFormSheet<bool>(context, const EditProfileForm());

class EditProfileForm extends ConsumerWidget {
  const EditProfileForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncView(ref.watch(meProvider), (me) => _Form(me), onRetry: () => ref.invalidate(meProvider));
}

class _Form extends ConsumerStatefulWidget {
  const _Form(this.me);
  final Me me;
  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> with BusyError {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.name);
  late final _email = TextEditingController(text: widget.me.loginEmail);
  late final _company = TextEditingController(text: widget.me.company);
  late final _details = CompanyDetailsInput(widget.me);
  final _phone = PhoneInput();
  late final String _oldPhone; // dial + digits as stored, to send the phone only when it changed
  XFile? _photo;
  Uint8List? _photoBytes;

  bool get _owner => Role.parse(widget.me.role) == Role.customer;

  @override
  void initState() {
    super.initState();
    // stored phones look like +919999900000 -> country (longest dial code that matches) + national number
    final p = widget.me.phone;
    final match = ([...countries]..sort((a, b) => b.dial.length.compareTo(a.dial.length))).where((c) => p.startsWith(c.dial));
    if (match.isNotEmpty) {
      _phone.country = match.first;
      _phone.text.text = p.substring(match.first.dial.length);
    } else {
      _phone.text.text = p.replaceAll(RegExp(r'\D'), '');
    }
    _oldPhone = '${_phone.country.dial}${_phone.national}';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _company]) {
      c.dispose();
    }
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (x == null) return;
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(x.name.split('.').last.toLowerCase())) return setState(() => error = 'Photo must be JPG, PNG or WebP');
    if (await x.length() > 2 * 1024 * 1024) return setState(() => error = 'Photo must be 2 MB or smaller');
    final bytes = await x.readAsBytes();
    setState(() { _photo = x; _photoBytes = bytes; error = null; });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final me = widget.me;
    final email = _email.text.trim();
    final ok = await guarded(context, title: 'Edit profile', confirm: 'Save these changes to your profile?', action: 'Yes, save', success: 'Your profile was updated.', busy: (b) => setState(() => busy = b), run: () async {
      await ref.read(apiProvider).patchForm('/me/profile', {
        if (_name.text.trim() != me.name) 'name': _name.text.trim(),
        if (email.isNotEmpty && email != me.loginEmail) 'email': email,
        if ('${_phone.country.dial}${_phone.national}' != _oldPhone) ...{'countryCode': _phone.country.dial, 'phone': _phone.national},
        if (_owner && _company.text.trim() != me.company) 'companyName': _company.text.trim(),
        if (_owner) ..._details.toFields(),
      }, photoPath: _photo?.path);
      ref.invalidate(meProvider);
    });
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            SheetHeader('Edit profile', _owner ? 'Update your photo, contact and company details.' : 'Update your photo and contact details.'),
            PhotoPickerRow(bytes: _photoBytes, url: widget.me.photo == null ? null : photoUrl(widget.me.photo!), initial: widget.me.name, onPick: _pickPhoto),
            const SheetTitle('Personal details'),
            SheetField(controller: _name, label: 'Full name', icon: LucideIcons.user, validator: (v) => V.name(v), max: 60),
            const SizedBox(height: 12),
            SheetField(controller: _email, label: 'Email', icon: LucideIcons.mail, validator: (v) => (v ?? '').trim().isEmpty ? null : V.email(v), max: 254, cap: TextCapitalization.none, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            PhoneField(input: _phone),
            if (_owner) ...[
              const SheetTitle('Company'),
              SheetField(controller: _company, label: 'Company name', icon: LucideIcons.building2, validator: (v) => V.text('Company name', 2, 80)(v), max: 80),
              CompanyDetailsSection(input: _details),
            ],
            ErrorText(error),
            const SizedBox(height: 20),
            BusyButton(label: 'Save changes', busy: busy, onPressed: _save, icon: LucideIcons.check),
          ]),
        ),
      );
}
