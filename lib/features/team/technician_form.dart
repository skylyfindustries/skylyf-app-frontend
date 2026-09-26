import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../auth/auth_widgets.dart';

const _maxPhotoBytes = 2 * 1024 * 1024;
const _maxDocBytes = 5 * 1024 * 1024;
const _maxDocs = 5;

const _mime = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'pdf': 'application/pdf'};

MultipartFile _part(Uint8List bytes, String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return MultipartFile.fromBytes(bytes, filename: name, contentType: DioMediaType.parse(_mime[ext] ?? 'application/octet-stream'));
}

/// Full-height modal: the owner adds a technician with the complete profile. Returns true when one was added.
Future<bool?> showTechnicianForm(BuildContext context) => showFormSheet<bool>(context, const TechnicianForm());

class TechnicianForm extends ConsumerStatefulWidget {
  const TechnicianForm({super.key});
  @override
  ConsumerState<TechnicianForm> createState() => _TechnicianFormState();
}

class _TechnicianFormState extends ConsumerState<TechnicianForm> with BusyError {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(), _last = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController();
  final _street = TextEditingController(), _city = TextEditingController(), _state = TextEditingController(), _zip = TextEditingController();
  final _dobText = TextEditingController(), _startText = TextEditingController(), _endText = TextEditingController();
  final _phone = PhoneInput();
  DateTime? _dob;
  TimeOfDay? _start = const TimeOfDay(hour: 9, minute: 0), _end = const TimeOfDay(hour: 18, minute: 0);
  XFile? _photo;
  Uint8List? _photoBytes;
  final _docs = <PlatformFile>[];

  @override
  void initState() {
    super.initState();
    _startText.text = _fmt(_start!);
    _endText.text = _fmt(_end!);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _pw, _street, _city, _state, _zip, _dobText, _startText, _endText]) {
      c.dispose();
    }
    _phone.dispose();
    super.dispose();
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (x == null) return;
    final ext = x.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return setState(() => error = 'Photo must be JPG, PNG or WebP');
    if (await x.length() > _maxPhotoBytes) return setState(() => error = 'Photo must be 2 MB or smaller');
    final bytes = await x.readAsBytes();
    setState(() { _photo = x; _photoBytes = bytes; error = null; });
  }

  Future<void> _pickDocs() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    for (final f in picked) {
      if (_docs.length >= _maxDocs) return setState(() => error = 'At most $_maxDocs documents');
      if ((await f.length() ?? 0) > _maxDocBytes) return setState(() => error = '${f.name} is larger than 5 MB');
      _docs.add(f);
    }
    setState(() => error = null);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _dob ?? DateTime(now.year - 30), firstDate: DateTime(now.year - 90), lastDate: now);
    if (d != null) setState(() { _dob = d; _dobText.text = '${d.year}-${_two(d.month)}-${_two(d.day)}'; });
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: (start ? _start : _end)!);
    if (t == null) return;
    setState(() {
      if (start) { _start = t; _startText.text = _fmt(t); } else { _end = t; _endText.text = _fmt(t); }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await guarded(context, title: 'Add technician', confirm: 'Add this technician? They will be able to sign in.', action: 'Yes, add', success: 'The technician was added.', busy: (b) => setState(() => busy = b), run: () async {
      final f = FormData.fromMap({
        'firstName': _first.text.trim(), 'lastName': _last.text.trim(), 'email': _email.text.trim(), 'password': _pw.text,
        'countryCode': _phone.country.dial, 'phone': _phone.national, 'dob': _dobText.text,
        'street': _street.text.trim(), 'city': _city.text.trim(), 'state': _state.text.trim(), 'zip': _zip.text.trim(),
        'shiftStart': _startText.text, 'shiftEnd': _endText.text,
      });
      if (_photo != null) f.files.add(MapEntry('photo', _part(_photoBytes!, _photo!.name)));
      for (final d in _docs) {
        f.files.add(MapEntry('documents', _part(await d.readAsBytes(), d.name)));
      }
      await ref.read(apiProvider).postForm('/technicians', f);
      ref.invalidate(techniciansProvider);
    });
    if (ok && mounted) Navigator.pop(context, true);
  }

  Widget _field(TextEditingController c, String label, IconData icon, String? Function(String?) v, {int max = 60, TextCapitalization cap = TextCapitalization.words}) => SheetField(controller: c, label: label, icon: icon, validator: v, max: max, cap: cap);

  Widget _tap(TextEditingController c, String label, IconData icon, VoidCallback onTap, String? Function(String?) v) => SheetField(controller: c, label: label, icon: icon, validator: v, onTap: onTap);

  Widget _title(String t) => SheetTitle(t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const SheetHeader('Add technician', 'They sign in with this email or phone and password, and only see your plant.'),
            PhotoPickerRow(bytes: _photoBytes, onPick: _pickPhoto),
            _title('Personal details'),
            _field(_first, 'First name', LucideIcons.user, V.text('First name', 1, 40), max: 40),
            const SizedBox(height: 12),
            _field(_last, 'Last name', LucideIcons.user, V.text('Last name', 1, 40), max: 40),
            const SizedBox(height: 12),
            EmailField(controller: _email),
            const SizedBox(height: 12),
            PhoneField(input: _phone),
            const SizedBox(height: 12),
            _tap(_dobText, 'Date of birth', LucideIcons.cake, _pickDob, (_) => V.dob(_dob)),
            _title('Sign-in password'),
            PasswordField(controller: _pw, newPassword: true, validator: V.newPassword, action: TextInputAction.next),
            PasswordChecklist(controller: _pw),
            _title('Address'),
            _field(_street, 'Street', LucideIcons.mapPin, V.text('Street', 3, 120), max: 120),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field(_city, 'City', LucideIcons.building2, V.text('City', 2, 60))),
              const SizedBox(width: 10),
              Expanded(child: _field(_state, 'State', LucideIcons.map, V.text('State', 2, 60))),
            ]),
            const SizedBox(height: 12),
            _field(_zip, 'Zip code', LucideIcons.hash, V.zip, max: 11, cap: TextCapitalization.characters),
            _title('Shift timing'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _tap(_startText, 'Starts', LucideIcons.clock, () => _pickTime(true), (v) => (v ?? '').isEmpty ? 'Required' : null)),
              const SizedBox(width: 10),
              Expanded(child: _tap(_endText, 'Ends', LucideIcons.clock, () => _pickTime(false), (v) => (v ?? '').isEmpty ? 'Required' : v == _startText.text ? 'Must differ from start' : null)),
            ]),
            _title('Documents (optional)'),
            const Muted('ID proof, licence, certificates. PDF, JPG or PNG, up to 5 files of 5 MB. Only you and Skylyf can see them.', size: 12),
            const SizedBox(height: 8),
            for (final (i, d) in _docs.indexed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.fileText, color: Brand.navy500),
                title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: const Icon(LucideIcons.x, size: 18), onPressed: () => setState(() => _docs.removeAt(i))),
              ),
            OutlinedButton.icon(onPressed: _docs.length >= _maxDocs ? null : _pickDocs, icon: const Icon(LucideIcons.paperclip, size: 18), label: Text('Add documents (${_docs.length}/$_maxDocs)')),
            ErrorText(error),
            const SizedBox(height: 20),
            BusyButton(label: 'Add technician', busy: busy, onPressed: _submit, icon: LucideIcons.userPlus),
          ]),
        ),
      );
}
