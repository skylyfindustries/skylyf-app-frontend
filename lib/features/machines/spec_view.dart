import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/spec.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The specification of a machine: size range, production speed (with per minute / hour / day), paper, coating.
/// Uses the structured [spec] when there is one; older machines only have the text fields, which are shown as before.
class SpecView extends StatelessWidget {
  const SpecView({super.key, required this.typeKey, this.spec, this.speedText = '', this.sizeText = '', this.paperText = ''});
  final String typeKey;
  final Spec? spec;
  final String speedText, sizeText, paperText; // legacy / derived text from the server

  Widget _row(IconData icon, String label, String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: Brand.gold300),
            const SizedBox(width: 12),
            SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 13, color: Brand.inkSoft))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          ]),
        );

  Widget _tile(String per, (int, int) v, bool entered) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: entered ? Brand.goldSoft : Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: entered ? Brand.gold500 : Brand.line)),
          child: Column(children: [
            FittedBox(child: Text(Spec.range(v.$1, v.$2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            const SizedBox(height: 2),
            Text(Spec.perName[per]!, style: const TextStyle(fontSize: 10.5, color: Brand.inkSoft)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = spec;
    final size = s?.sizeText ?? sizeText;
    final speed = s?.speedText(typeKey) ?? speedText;
    final paper = s?.hasGsm == true ? [s!.gsmText!, if (s.coating != null && s.coating != 'none') Spec.coatingName[s.coating]!, if (s.coating == 'none') 'Uncoated'].join(' · ') : paperText;
    final label = sizeLabelFor(typeKey);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _row(typeKey == 'tissue' ? LucideIcons.ruler : LucideIcons.cupSoda, label, size),
      if (s?.maxHeightMm != null) _row(LucideIcons.moveVertical, 'Max height', '${Spec.n(s!.maxHeightMm!)} mm'),
      _row(LucideIcons.gauge, 'Production speed', speed),
      if (s?.hasSpeed == true) ...[
        const SizedBox(height: 4),
        Row(children: [for (final p in const ['min', 'hr', 'day']) _tile(p, s!.speedIn(p)!, s.speedPer == p)]),
        const Padding(padding: EdgeInsets.only(top: 6), child: Muted('Same speed, shown per minute, hour and day (the unit it is rated in is highlighted).', size: 11)),
      ],
      _row(LucideIcons.fileText, 'Paper', paper),
    ]);
  }
}
