import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import 'auth_widgets.dart';

/// Company address and government IDs. Everything is optional; the address is all-or-nothing (start it and every part is required).
class CompanyDetailsInput {
  CompanyDetailsInput([Me? me])
      : street = TextEditingController(text: me?.street ?? ''),
        city = TextEditingController(text: me?.city ?? ''),
        state = TextEditingController(text: me?.state ?? ''),
        zip = TextEditingController(text: me?.zip ?? ''),
        gstin = TextEditingController(text: me?.gstin ?? ''),
        pan = TextEditingController(text: me?.pan ?? ''),
        cin = TextEditingController(text: me?.cin ?? ''),
        udyam = TextEditingController(text: me?.udyam ?? ''),
        _orig = me;

  final TextEditingController street, city, state, zip, gstin, pan, cin, udyam;
  final Me? _orig;

  List<TextEditingController> get _address => [street, city, state, zip];
  bool get startedAddress => _address.any((c) => c.text.trim().isNotEmpty);

  /// Fields to send. Registering: only what was filled in. Editing: only what changed (a blank value clears it on the server).
  Map<String, String> toFields() {
    final o = _orig;
    final out = <String, String>{};
    final addressChanged = o == null
        ? startedAddress
        : street.text.trim() != o.street || city.text.trim() != o.city || state.text.trim() != o.state || zip.text.trim() != o.zip;
    if (addressChanged) {
      out.addAll({'street': street.text.trim(), 'city': city.text.trim(), 'state': state.text.trim(), 'zip': zip.text.trim()}); // all four together
    }
    void id(String key, TextEditingController c, String? old) {
      final v = c.text.trim().toUpperCase();
      if (o == null ? v.isNotEmpty : v != (old ?? '')) out[key] = v;
    }

    id('gstin', gstin, o?.gstin);
    id('pan', pan, o?.pan);
    id('cin', cin, o?.cin);
    id('udyam', udyam, o?.udyam);
    return out;
  }

  void dispose() {
    for (final c in [street, city, state, zip, gstin, pan, cin, udyam]) {
      c.dispose();
    }
  }
}

class CompanyDetailsSection extends StatelessWidget {
  const CompanyDetailsSection({super.key, required this.input});
  final CompanyDetailsInput input;

  // a part may stay empty only while the whole address is empty
  String? Function(String?) _part(String what, int min, int max) => (v) => (v ?? '').trim().isEmpty && !input.startedAddress ? null : V.text(what, min, max)(v);

  Widget _id(TextEditingController c, String label, IconData icon, int max, String? Function(String?) v) => above(label, TextFormField(
        controller: c,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: [LengthLimitingTextInputFormatter(max), UpperCaseFormatter()],
        validator: v,
        decoration: InputDecoration(prefixIcon: Icon(icon), counterText: ''),
      ));

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetTitle('Company address (optional)'),
        SheetField(controller: input.street, label: 'Street / building', icon: LucideIcons.mapPin, validator: _part('Street', 3, 120), max: 120),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SheetField(controller: input.city, label: 'City', icon: LucideIcons.building2, validator: _part('City', 2, 60))),
          const SizedBox(width: 10),
          Expanded(child: SheetField(controller: input.state, label: 'State', icon: LucideIcons.map, validator: _part('State', 2, 60))),
        ]),
        const SizedBox(height: 12),
        SheetField(controller: input.zip, label: 'Zip / PIN code', icon: LucideIcons.hash, validator: (v) => (v ?? '').trim().isEmpty && !input.startedAddress ? null : V.zip(v), max: 11, cap: TextCapitalization.characters),
        const SheetTitle('Government details (optional)'),
        const Muted('Add them now or later. They are used for invoices and compliance.', size: 12),
        const SizedBox(height: 10),
        _id(input.gstin, 'GSTIN', LucideIcons.receipt, 15, V.gstin),
        const SizedBox(height: 12),
        _id(input.pan, 'PAN', LucideIcons.idCard, 10, (v) => V.pan(v) ?? V.panMatchesGstin(v, input.gstin.text)),
        const SizedBox(height: 12),
        _id(input.cin, 'CIN (company registration)', LucideIcons.fileBadge, 21, V.cin),
        const SizedBox(height: 12),
        _id(input.udyam, 'Udyam (MSME) number', LucideIcons.badgeCheck, 19, V.udyam),
      ]);
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue value) => value.copyWith(text: value.text.toUpperCase());
}
