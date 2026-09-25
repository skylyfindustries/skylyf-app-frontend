import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/role.dart';
import '../../core/theme.dart';

/// Tab shell with a floating glass navigation bar. Tabs come from the signed-in role.
class Shell extends ConsumerWidget {
  const Shell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    ref.listen(meProvider, (_, me) => me.whenData((m) => ref.read(langProvider.notifier).setFromServer(m.language)));
    ref.watch(meProvider); // keep alive so the listener fires once loaded
    final tabs = (ref.watch(roleProvider) ?? Role.customer).tabs;
    final current = location == '/' ? 0 : tabs.indexWhere((e) => e.path != '/' && location.startsWith(e.path)).clamp(0, tabs.length - 1);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassCard(
              radius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.go(tabs[i].path),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: i == current ? Brand.goldSoft : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedScale(scale: i == current ? 1.12 : 1, duration: const Duration(milliseconds: 260), curve: Curves.easeOutBack, child: Icon(tabs[i].icon, size: 24, color: i == current ? Brand.gold300 : Brand.inkSoft)),
                          const SizedBox(height: 3),
                          Text(
                            t(tabs[i].label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: i == current ? FontWeight.w800 : FontWeight.w500, color: i == current ? Brand.gold300 : Brand.inkSoft),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
