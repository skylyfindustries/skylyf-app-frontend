import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class SetGoalScreen extends ConsumerStatefulWidget {
  const SetGoalScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SetGoalScreen> createState() => _SetGoalScreenState();
}

class _SetGoalScreenState extends ConsumerState<SetGoalScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _target;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final machine = ref.read(machineProvider(widget.id)).valueOrNull;
    _target = TextEditingController(text: machine == null ? '' : '${machine.todayTarget.round()}');
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final saved = await guarded(
      context,
      title: 'Set daily production goal',
      confirm: 'Save ${_target.text.trim()} as today\'s production target?',
      action: 'Save goal',
      success: 'Daily production goal updated.',
      busy: (value) => setState(() => _busy = value),
      run: () => ref.read(apiProvider).patch('/machines/${widget.id}/goal', {'todayTarget': num.parse(_target.text.trim())}),
    );
    if (saved && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final machine = ref.watch(machineProvider(widget.id)).valueOrNull;
    final unit = machine?.outputUnit ?? 'units';
    return GlassPage(
      title: 'Daily production goal',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Icon(LucideIcons.target, size: 42, color: Brand.gold300),
          const SizedBox(height: 12),
          const Text('Set today\'s target', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose how many $unit this machine should produce today.', style: const TextStyle(color: Brand.inkSoft)),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: TextFormField(
              controller: _target,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Production target ($unit)', prefixIcon: const Icon(LucideIcons.target), suffixText: unit),
              validator: (value) {
                final n = num.tryParse(value?.trim() ?? '');
                return n == null || n < 0 || n > 1000000 ? 'Enter a number from 0 to 1,000,000' : null;
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.save),
            label: const Text('Save daily goal'),
          ),
        ],
      ),
    );
  }
}
