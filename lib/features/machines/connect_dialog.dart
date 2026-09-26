import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

enum _Stage { working, ok, failed }

/// Payment-style progress dialog: "Connecting..." while [task] runs, then a success or a failure screen.
/// Returns true when the task succeeded and the user closed the success screen, false when they chose to try again / closed the failure.
Future<bool> showConnectDialog(
  BuildContext context, {
  required Future<void> Function() task,
  required String workingTitle,
  required List<String> steps, // shown one after another while working
  required String successTitle,
  required String successText,
  List<String> details = const [], // e.g. the serial numbers, shown on the success screen
  Duration minimum = const Duration(milliseconds: 1800), // long enough to be read, like a real payment
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ConnectDialog(task: task, workingTitle: workingTitle, steps: steps, successTitle: successTitle, successText: successText, details: details, minimum: minimum),
    ) ??
    false;

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({required this.task, required this.workingTitle, required this.steps, required this.successTitle, required this.successText, required this.details, required this.minimum});
  final Future<void> Function() task;
  final String workingTitle, successTitle, successText;
  final List<String> steps, details;
  final Duration minimum;

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  _Stage _stage = _Stage.working;
  String _error = '';
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _run();
    _tick();
  }

  // the step list advances while we wait, so it never looks frozen
  Future<void> _tick() async {
    final each = widget.minimum.inMilliseconds ~/ (widget.steps.length + 1);
    for (var i = 1; i <= widget.steps.length; i++) {
      await Future<void>.delayed(Duration(milliseconds: each));
      if (!mounted || _stage != _Stage.working) return;
      setState(() => _step = i);
    }
  }

  Future<void> _run() async {
    String? error;
    try {
      await Future.wait([widget.task(), Future<void>.delayed(widget.minimum)]);
    } catch (e) {
      error = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      _stage = error == null ? _Stage.ok : _Stage.failed;
      _error = error ?? '';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Brand.cream,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: switch (_stage) {
                _Stage.working => _working(),
                _Stage.ok => _done(ok: true),
                _Stage.failed => _done(ok: false),
              },
            ),
          ),
        ),
      );

  Widget _working() => Column(mainAxisSize: MainAxisSize.min, children: [
        Lottie.asset('assets/lottie/gears.json', width: 110, height: 110),
        const SizedBox(height: 6),
        Text(widget.workingTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Muted('Please keep the app open. This takes a few seconds.', size: 13),
        const SizedBox(height: 18),
        for (final (i, s) in widget.steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: i < _step
                    ? const Icon(LucideIcons.circleCheck, key: ValueKey('done'), size: 20, color: Brand.running)
                    : i == _step
                        ? const SizedBox(key: ValueKey('now'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.gold500))
                        : const Icon(LucideIcons.circle, key: ValueKey('todo'), size: 20, color: Brand.line),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s, style: TextStyle(fontSize: 14, fontWeight: i <= _step ? FontWeight.w700 : FontWeight.w500, color: i <= _step ? Brand.ink : Brand.inkSoft))),
            ]),
          ),
      ]);

  Widget _done({required bool ok}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Lottie.asset(ok ? 'assets/lottie/success.json' : 'assets/lottie/failure.json', width: 120, height: 120, repeat: false),
        const SizedBox(height: 4),
        Text(ok ? widget.successTitle : 'Could not connect', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ok ? Brand.running : Brand.stopped)),
        const SizedBox(height: 8),
        Text(ok ? widget.successText : _error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4, color: Brand.inkSoft)),
        if (ok && widget.details.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final d in widget.details)
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(20)), child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Brand.gold300))),
          ]),
        ],
        const SizedBox(height: 20),
        if (ok)
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done'))
        else ...[
          FilledButton.icon(onPressed: () => Navigator.pop(context, false), icon: const Icon(LucideIcons.rotateCcw, size: 18), label: const Text('Try again')),
        ],
      ]);
}
