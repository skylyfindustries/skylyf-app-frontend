import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Client owner: the technicians of MY company. The server takes the tenant id from the login token,
/// so an owner can only ever list, add or remove their own people.
class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassPage(
        title: 'My technicians',
        actions: [IconButton(tooltip: 'Add technician', icon: const Icon(LucideIcons.userPlus), onPressed: () => _add(context, ref))],
        child: asyncView(
          ref.watch(techniciansProvider),
          (list) => RefreshIndicator(
            color: Brand.gold500,
            onRefresh: () async {
              ref.invalidate(techniciansProvider);
              await ref.read(techniciansProvider.future);
            },
            child: list.isEmpty
                ? ListView(children: const [SizedBox(height: 200), Center(child: Muted('No technicians yet. Tap + to add one.', size: 14))])
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    for (final (i, t) in list.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                          child: Row(children: [
                            const Icon(LucideIcons.wrench, color: Brand.gold500),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Muted(t.phone.isEmpty ? 'No phone' : t.phone),
                            ])),
                            IconButton(tooltip: 'Remove', icon: const Icon(LucideIcons.trash2, color: Brand.stopped), onPressed: () => _remove(context, ref, t)),
                          ]),
                        ),
                      ).reveal(i),
                  ]),
          ),
          onRetry: () => ref.invalidate(techniciansProvider),
        ),
      );

  Future<void> _remove(BuildContext context, WidgetRef ref, Technician t) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${t.name}?'),
        content: const Text('They will no longer be able to sign in.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(apiProvider).delete('/technicians/${t.id}');
      ref.invalidate(techniciansProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(), phone = TextEditingController(), password = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(c).viewInsets.bottom),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add technician', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Muted('They sign in with this phone number and password, and only see your plant.', size: 13),
            const SizedBox(height: 16),
            TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(LucideIcons.user)), validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name' : null),
            const SizedBox(height: 12),
            TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (login)', prefixIcon: Icon(LucideIcons.phone)), validator: (v) => (v == null || v.trim().length < 5) ? 'Enter a phone number' : null),
            const SizedBox(height: 12),
            TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 8)', prefixIcon: Icon(LucideIcons.lock)), validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null),
            const SizedBox(height: 18),
            FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(c, true); }, child: const Text('Add technician')),
          ]),
        ),
      ),
    );
    final body = {'name': name.text.trim(), 'phone': phone.text.trim(), 'password': password.text};
    name.dispose();
    phone.dispose();
    password.dispose();
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).post('/technicians', body);
      ref.invalidate(techniciansProvider);
      messenger.showSnackBar(SnackBar(content: Text('${body['name']} added')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
