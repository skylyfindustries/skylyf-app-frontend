import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'api.dart';
import 'theme.dart';

/// "Are you sure?" dialog. Returns true only when the user confirms.
Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String action = 'Yes, continue', bool danger = false}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(LucideIcons.triangleAlert, size: 36, color: danger ? Brand.stopped : Brand.idle),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Brand.stopped) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return yes == true;
}

/// Success or failure dialog, closed with OK.
Future<void> resultDialog(BuildContext context, {required bool ok, required String title, required String message}) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleAlert, size: 40, color: ok ? Brand.running : Brand.stopped),
        title: Text(ok ? 'Success' : 'Failed', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );

String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

/// The standard add / edit / delete flow: ask (unless [confirm] is null: the caller already asked), run, then a success or failure dialog.
/// Returns true when [run] succeeded. [showSuccess]: false when the screen closes itself with its own result.
Future<bool> guarded(
  BuildContext context, {
  required String title,
  String? confirm = 'Do you want to continue?',
  String action = 'Yes, continue',
  bool danger = false,
  String success = 'Completed successfully.',
  bool showSuccess = true,
  void Function(bool busy)? busy,
  required Future<void> Function() run,
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  if (confirm != null && !await confirmDialog(context, title: title, message: confirm, action: action, danger: danger)) return false;
  busy?.call(true);
  try {
    await run();
  } catch (e) {
    busy?.call(false);
    // ignore: use_build_context_synchronously
    if (nav.context.mounted) await resultDialog(nav.context, ok: false, title: title, message: errorText(e));
    return false;
  }
  busy?.call(false);
  // ignore: use_build_context_synchronously
  if (showSuccess && nav.context.mounted) await resultDialog(nav.context, ok: true, title: title, message: success);
  return true;
}
