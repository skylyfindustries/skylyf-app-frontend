import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../tasks/tasks_screen.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final tickets = ref.watch(ticketsProvider(id));
    final code = ref.watch(machineProvider(id)).valueOrNull?.code ?? '';
    final canRequest = ref.watch(roleProvider)?.canRequestService ?? true;

    return GlassPage(
      title: '${t('Maintenance')} $code',
      child: Column(children: [
        Expanded(
          child: asyncView(
            tickets,
            (list) => list.isEmpty
                ? const Center(child: Muted('No maintenance history yet', size: 14))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final (i, k) in list.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(12)),
                              child: Icon(k.type == 'request' ? LucideIcons.headset : LucideIcons.history, size: 20, color: Brand.gold300),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(k.note, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                if (k.technician != null) Text('Technician: ${k.technician}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.gold300)),
                                Muted('${k.createdAt.day}/${k.createdAt.month}/${k.createdAt.year}', size: 12),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: statusTint(k.status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                k.type == 'request' ? (k.status == 'open' ? 'REQUESTED' : k.status == 'in_progress' ? 'IN PROGRESS' : 'RESOLVED') : 'COMPLETED',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusTint(k.status)),
                              ),
                            ),
                          ]),
                        ).reveal(i),
                      ),
                  ]),
            onRetry: () => ref.invalidate(ticketsProvider(id)),
          ),
        ),
        if (canRequest)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () async {
                final sent = await showServiceRequest(context, machineId: id);
                if (sent && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to your technician')));
              },
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(t('Request service')),
            ),
          ),
      ]),
    );
  }
}
