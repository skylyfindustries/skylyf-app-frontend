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
    ref.listen(meProvider, (_, me) => me.whenData((m) => ref.read(langProvider.notifier).setFromServer(m.language)));
    ref.watch(meProvider); // keep alive so the listener fires once loaded
    final tabs = (ref.watch(roleProvider) ?? Role.customer).tabs;
    final current = location == '/' ? 0 : tabs.indexWhere((e) => e.path != '/' && location.startsWith(e.path)).clamp(0, tabs.length - 1);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.only(top: 14), child: child)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 22),
            child: GlassCard(
              radius: 34,
              alpha: 0.32,
              blur: 30,
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                height: 54,
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth / tabs.length;
                  return Stack(children: [
                    // the frosted pill that slides under the selected icon
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      left: current * w,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(decoration: navPill(28)),
                    ),
                    Row(children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.go(tabs[i].path),
                            child: Center(
                              child: AnimatedScale(
                                scale: i == current ? 1.12 : 1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                child: Icon(tabs[i].icon, size: 23, color: i == current ? Brand.gold300 : Brand.inkSoft),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
