import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/machine_art.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../auth/auth_widgets.dart';
import 'connect_dialog.dart';
import 'spec_view.dart';

/// "Register new": every machine available to register, as a shop grid (photo, name, model, speed, stock) with search, type filter and sort.
class StoreGrid extends ConsumerStatefulWidget {
  const StoreGrid({super.key});
  @override
  ConsumerState<StoreGrid> createState() => _StoreGridState();
}

class _StoreGridState extends ConsumerState<StoreGrid> {
  String _q = '';
  String? _type; // null = all


  @override
  Widget build(BuildContext context) => asyncView(
        ref.watch(storeProvider),
        (all) {
          final types = <String, String>{for (final m in all) if (m.typeKey.isNotEmpty) m.typeKey: m.typeName};
          final q = _q.trim().toLowerCase();
          final shown = all.where((m) => (_type == null || m.typeKey == _type) && (q.isEmpty || '${m.name} ${m.model} ${m.typeName} ${m.description}'.toLowerCase().contains(q))).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final filtered = _q.isNotEmpty || _type != null;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search machines',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(LucideIcons.x, size: 18), onPressed: () => setState(() => _q = '')),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Brand.gold500, width: 1.6)),
                  ),
                ),
              ),
            ]),
            if (types.length > 1) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _TypeChip('All', _type == null, () => setState(() => _type = null)),
                  for (final e in types.entries) _TypeChip(e.value, _type == e.key, () => setState(() => _type = e.key)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Muted('${shown.length} machine${shown.length == 1 ? '' : 's'}', size: 13)),
              if (filtered) TextButton(onPressed: () => setState(() { _q = ''; _type = null; }), child: const Text('Clear filters')),
            ]),
            const SizedBox(height: 6),
            if (shown.isEmpty)
              GlassCard(
                alpha: 0.92,
                padding: const EdgeInsets.all(28),
                child: Center(child: Column(children: [
                  const Icon(LucideIcons.packageSearch, size: 34, color: Brand.gold300),
                  const SizedBox(height: 10),
                  Text(all.isEmpty ? 'No machines available right now' : 'No machines match your search', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Muted(all.isEmpty ? 'Skylyf adds new machines here. Check back soon.' : 'Try another word or clear the filters.', size: 13),
                ])),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shown.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 306),
                itemBuilder: (_, i) => StoreCard(shown[i], onOpen: () => _open(shown[i]), onRegister: () => registerFromStore(context, ref, shown[i])).reveal(i < 8 ? i : 0),
              ),
          ]);
        },
        onRetry: () => ref.invalidate(storeProvider),
      );

  Future<void> _open(StoreItem m) async {
    final register = await showFormSheet<bool>(context, _Detail(m));
    if (register == true && mounted) await registerFromStore(context, ref, m);
  }
}

typedef _TypeChip = PillChip;

/// One product card of the grid.
class StoreCard extends StatelessWidget {
  const StoreCard(this.m, {super.key, required this.onOpen, required this.onRegister});
  final StoreItem m;
  final VoidCallback onOpen, onRegister;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      alpha: 0.95,
      blur: 6,
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          MachineArt(m.typeKey, photo: m.photos.firstOrNull, status: '', height: 128, radius: 0),
          if (m.photos.length > 1)
            Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(LucideIcons.images, size: 11, color: Colors.white), const SizedBox(width: 3), Text('${m.photos.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white))]))),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
              if (m.model.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.model, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.gold300))),
              const SizedBox(height: 6),
              if (m.speed.isNotEmpty) Row(children: [const Icon(LucideIcons.gauge, size: 13, color: Brand.inkSoft), const SizedBox(width: 5), Expanded(child: Text(m.speed, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))]),
              if (m.cupSize.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [Icon(m.typeKey == 'tissue' ? LucideIcons.ruler : LucideIcons.cupSoda, size: 13, color: Brand.inkSoft), const SizedBox(width: 5), Expanded(child: Text(m.cupSize, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Brand.inkSoft)))])),
              const Spacer(),
              if ((m.price ?? 0) > 0) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('₹${fmt(m.price!)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              SizedBox(width: double.infinity, height: 38, child: FilledButton(onPressed: onRegister, style: FilledButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), child: const Text('Register'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Product page: photo carousel, description, the specifications, and the register button.
class _Detail extends StatefulWidget {
  const _Detail(this.m);
  final StoreItem m;
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Widget _row(IconData icon, String label, String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: Brand.gold300),
            const SizedBox(width: 12),
            SizedBox(width: 104, child: Text(label, style: const TextStyle(fontSize: 13, color: Brand.inkSoft))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          ]),
        );

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final count = m.photos.isEmpty ? 1 : m.photos.length;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 240,
          child: Stack(children: [
            PageView.builder(controller: _page, itemCount: count, onPageChanged: (v) => setState(() => _i = v), itemBuilder: (_, i) => MachineArt(m.typeKey, photo: m.photos.isEmpty ? null : m.photos[i], status: '', height: 240, radius: 0)),
            if (count > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < count; k++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: k == _i ? 18 : 7, height: 7, decoration: BoxDecoration(color: k == _i ? Brand.gold500 : Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6))),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        if (m.model.isNotEmpty) _Pill(m.model, Brand.goldSoft, Brand.gold300),
        if (m.typeName.isNotEmpty) _Pill(m.typeName, Brand.navy500.withValues(alpha: 0.1), Brand.navy500),
      ]),
      if (m.description.isNotEmpty) ...[const SizedBox(height: 14), Text(m.description, style: const TextStyle(fontSize: 14, height: 1.4))],
      const SheetTitle('Specifications'),
      SpecView(typeKey: m.typeKey, spec: m.spec, speedText: m.speed, sizeText: m.cupSize, paperText: m.paperRequired),
      if ((m.price ?? 0) > 0) _row(LucideIcons.tag, 'Price', '₹${fmt(m.price!)}'),
      for (final s in m.specs) _row(LucideIcons.check, '', s),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Register this machine')),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)));
}

// ---------------- register ----------------

Future<void> registerFromStore(BuildContext context, WidgetRef ref, StoreItem m) async {
  final done = await showFormSheet<bool>(context, _RegisterForm(m));
  if (done == true && context.mounted) {
    ref.invalidate(registrationsProvider);
    ref.invalidate(storeProvider);
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm(this.m);
  final StoreItem m;
  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> with BusyError {
  final _form = GlobalKey<FormState>();
  // one serial number field per piece: the list grows and shrinks with the quantity
  final _serials = <TextEditingController>[TextEditingController()];
  final _nick = TextEditingController();
  int get _qty => _serials.length;

  void _setQty(int n) => setState(() {
        while (_serials.length < n) {
          _serials.add(TextEditingController());
        }
        while (_serials.length > n) {
          _serials.removeLast().dispose();
        }
      });

  /// Each serial is 8+ characters and different from the others.
  String? Function(String?) _serialRule(int i) => (v) {
        final err = V.text('Serial number', 8, 40)(v);
        if (err != null) return err;
        final mine = v!.trim().toUpperCase();
        final twin = _serials.indexWhere((c) => c != _serials[i] && c.text.trim().toUpperCase() == mine);
        return twin >= 0 ? 'Same as serial number ${twin + 1}' : null;
      };

  @override
  void dispose() {
    for (final c in _serials) {
      c.dispose();
    }
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final name = widget.m.model.isEmpty ? widget.m.name : widget.m.model;
    final serials = [for (final c in _serials) c.text.trim().toUpperCase()];
    if (!await confirmDialog(context, title: 'Register machine', message: 'Register $_qty × $name? Skylyf will verify the serial number and approve it.', action: 'Yes, register')) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    // "Connecting..." then a success or a failure screen, like a payment
    final ok = await showConnectDialog(
      context,
      workingTitle: _qty == 1 ? 'Connecting your machine' : 'Connecting your $_qty machines',
      steps: [_qty == 1 ? 'Checking the serial number' : 'Checking $_qty serial numbers', 'Linking to your Skylyf account', 'Sending for verification'],
      task: () => ref.read(apiProvider).post('/registrations', {...widget.m.pick, 'qty': _qty, 'serials': serials, 'nickname': _nick.text.trim()}),
      successTitle: 'Registration successful',
      successText: _qty == 1
          ? 'Your machine is registered. Skylyf will verify the serial number within 24 hours and it will then show in My machines.'
          : 'Your $_qty machines are registered. Skylyf will verify the serial numbers within 24 hours and they will then show in My machines.',
      details: serials,
    );
    if (ok && mounted) Navigator.pop(context, true); // on failure the form stays open so the client can fix the serials and try again
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            SheetHeader('Register ${widget.m.model.isEmpty ? widget.m.name : widget.m.model}', 'The serial number is on the nameplate at the back of the machine.'),
            Row(children: [
              SizedBox(width: 84, child: MachineArt(widget.m.typeKey, photo: widget.m.photos.firstOrNull, status: '', height: 64, radius: 14)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
            const SheetTitle('How many?'),
            Row(children: [
              IconButton.outlined(onPressed: _qty > 1 ? () => _setQty(_qty - 1) : null, icon: const Icon(LucideIcons.minus, size: 18)),
              SizedBox(width: 56, child: Text('$_qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton.outlined(onPressed: _qty < StoreItem.maxQty ? () => _setQty(_qty + 1) : null, icon: const Icon(LucideIcons.plus, size: 18)),
              const SizedBox(width: 12),
              const Expanded(child: Muted('Each piece gets its own machine code and serial number.', size: 12)),
            ]),
            SheetTitle(_qty == 1 ? 'Serial number' : 'Serial numbers ($_qty)'),
            for (var i = 0; i < _qty; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              SheetField(controller: _serials[i], label: _qty == 1 ? 'Serial number' : 'Serial number ${i + 1} of $_qty', icon: LucideIcons.hash, validator: _serialRule(i), max: 40, cap: TextCapitalization.characters),
            ],
            const SheetTitle('Machine name'),
            SheetField(controller: _nick, label: _qty == 1 ? 'Machine name (e.g. PC-12)' : 'Name for the machines (e.g. PC, numbered for you)', icon: LucideIcons.tag, validator: V.text('Machine name', 1, 30), max: 30, cap: TextCapitalization.characters, action: TextInputAction.done),
            ErrorText(error),
            const SizedBox(height: 20),
            BusyButton(label: 'Submit registration', busy: busy, onPressed: _submit, icon: LucideIcons.check),
          ]),
        ),
      );
}
