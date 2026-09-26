import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/feedback.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'technician_form.dart';

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
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Brand.goldSoft,
                              backgroundImage: t.photo == null ? null : NetworkImage(photoUrl(t.photo!)),
                              child: t.photo == null ? const Icon(LucideIcons.wrench, color: Brand.gold500) : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Muted(t.phone.isEmpty ? 'No phone' : t.phone),
                              if (t.shift.isNotEmpty) Muted('Shift ${t.shift}'),
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
    await guarded(
      context,
      title: 'Remove ${t.name}',
      confirm: 'They will no longer be able to sign in.',
      action: 'Yes, remove',
      danger: true,
      success: '${t.name} was removed.',
      run: () async {
        await ref.read(apiProvider).delete('/technicians/${t.id}');
        ref.invalidate(techniciansProvider);
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await showTechnicianForm(context); // the form asks first and shows its own result
  }
}
