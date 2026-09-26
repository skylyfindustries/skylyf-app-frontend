import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return GlassPage(
      title: t('Alerts'),
      child: asyncView(
        ref.watch(alertsProvider),
        (list) => RefreshIndicator(
          color: Brand.gold500,
          onRefresh: () async {
            ref.invalidate(alertsProvider);
            await ref.read(alertsProvider.future);
          },
          child: list.isEmpty
              ? ListView(children: const [SizedBox(height: 200), Center(child: Muted('No alerts', size: 14))])
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: a.machineId == null ? null : () => context.push('/machine/${a.machineId}'),
                        child: Row(children: [
                          Icon(a.type == 'status' ? LucideIcons.info : LucideIcons.triangleAlert, color: a.status == 'open' ? Brand.stopped : Brand.inkSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.message, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Muted('${timeAgo(a.createdAt)} • ${a.status}'),
                            ]),
                          ),
                          if (a.status == 'open')
                            TextButton(
                              onPressed: () async {
                                await ref.read(apiProvider).patch('/alerts/${a.id}/ack', {});
                                ref.invalidate(alertsProvider);
                              },
                              child: const Text('OK', style: TextStyle(color: Brand.gold300, fontWeight: FontWeight.w800)),
                            ),
                        ]),
                      ),
                    ),
                ]),
        ),
        onRetry: () => ref.invalidate(alertsProvider),
      ),
    );
  }
}
