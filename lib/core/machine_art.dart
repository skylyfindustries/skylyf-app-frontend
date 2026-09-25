import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Vector illustration of a machine (no image files needed, crisp at any size).
/// Swap for real product photos later by passing an `imageUrl` in the API and using Image.network here.
class MachineArt extends StatelessWidget {
  const MachineArt(this.typeKey, {super.key, this.status = 'running', this.height = 160, this.radius = 20});
  final String typeKey;
  final String status;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFF3E9D2)])),
            child: CustomPaint(painter: _MachinePainter(typeKey, status)),
          ),
        ),
      );
}

class _MachinePainter extends CustomPainter {
  _MachinePainter(this.type, this.status);
  final String type, status;

  static const _navy = Brand.navy700;
  static const _navyLight = Brand.navy500;
  static const _gold = Brand.gold500;
  static const _steel = Color(0xFFCBD3DF);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final floor = h * 0.86;

    // soft floor shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, floor + 2), width: w * 0.78, height: h * 0.07), Paint()..color = Brand.navy900.withValues(alpha: 0.10));

    switch (type) {
      case 'tissue':
        _tissue(canvas, w, h, floor);
      case 'paper_cup':
        _cup(canvas, w, h, floor);
      default:
        _generic(canvas, w, h, floor);
    }

    // status lamp on top of the control box
    final lamp = statusColor(status);
    final c = Offset(w * 0.80, h * 0.20);
    canvas.drawCircle(c, h * 0.075, Paint()..color = lamp.withValues(alpha: 0.22));
    canvas.drawCircle(c, h * 0.042, Paint()..color = lamp);
  }

  RRect _rr(double l, double t, double w, double h, [double r = 8]) => RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

  void _cup(Canvas c, double w, double h, double floor) {
    final body = Paint()..color = _navy;
    // base frame
    c.drawRRect(_rr(w * 0.12, floor - h * 0.18, w * 0.76, h * 0.18, 10), body);
    // main housing
    c.drawRRect(_rr(w * 0.18, h * 0.26, w * 0.48, floor - h * 0.18 - h * 0.26, 12), Paint()..color = _navyLight);
    // gold band + window
    c.drawRRect(_rr(w * 0.18, h * 0.40, w * 0.48, h * 0.05, 4), Paint()..color = _gold);
    c.drawRRect(_rr(w * 0.24, h * 0.50, w * 0.36, h * 0.17, 8), Paint()..color = Colors.white.withValues(alpha: 0.85));
    // gears seen in the window
    final g = Paint()..color = _steel;
    c.drawCircle(Offset(w * 0.34, h * 0.585), h * 0.055, g);
    c.drawCircle(Offset(w * 0.46, h * 0.585), h * 0.038, Paint()..color = _gold);
    // control box
    c.drawRRect(_rr(w * 0.70, h * 0.28, w * 0.16, h * 0.30, 10), body);
    c.drawRRect(_rr(w * 0.72, h * 0.42, w * 0.12, h * 0.07, 4), Paint()..color = Colors.white.withValues(alpha: 0.85));
    // stacked cups on the output tray
    final cupY = floor - h * 0.34;
    for (var i = 0; i < 4; i++) {
      final x = w * 0.70 + i * w * 0.045;
      final path = Path()
        ..moveTo(x, cupY)
        ..lineTo(x + w * 0.05, cupY)
        ..lineTo(x + w * 0.04, cupY + h * 0.12)
        ..lineTo(x + w * 0.01, cupY + h * 0.12)
        ..close();
      c.drawPath(path, Paint()..color = i.isEven ? Colors.white : const Color(0xFFF1E4C7));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = _gold);
    }
    // feed roll on the left
    c.drawCircle(Offset(w * 0.09, floor - h * 0.34), h * 0.14, Paint()..color = const Color(0xFFF1E4C7));
    c.drawCircle(Offset(w * 0.09, floor - h * 0.34), h * 0.06, Paint()..color = _gold);
    c.drawRect(Rect.fromLTWH(w * 0.09, floor - h * 0.36, w * 0.09, h * 0.04), Paint()..color = _steel);
  }

  void _tissue(Canvas c, double w, double h, double floor) {
    final body = Paint()..color = _navy;
    // long base
    c.drawRRect(_rr(w * 0.06, floor - h * 0.14, w * 0.88, h * 0.14, 10), body);
    // unwind stand (left) with jumbo roll
    c.drawRRect(_rr(w * 0.10, h * 0.30, w * 0.05, floor - h * 0.14 - h * 0.30, 4), Paint()..color = _navyLight);
    c.drawCircle(Offset(w * 0.20, h * 0.50), h * 0.20, Paint()..color = Colors.white);
    c.drawCircle(Offset(w * 0.20, h * 0.50), h * 0.20, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = _steel);
    c.drawCircle(Offset(w * 0.20, h * 0.50), h * 0.07, Paint()..color = _gold);
    // guide rollers + web
    for (final x in [0.40, 0.52, 0.64]) {
      c.drawCircle(Offset(w * x, h * 0.36), h * 0.05, Paint()..color = _steel);
    }
    c.drawLine(Offset(w * 0.28, h * 0.36), Offset(w * 0.64, h * 0.36), Paint()..color = Colors.white..strokeWidth = 4);
    // embossing / rewinder housing
    c.drawRRect(_rr(w * 0.40, h * 0.44, w * 0.30, floor - h * 0.14 - h * 0.44, 12), Paint()..color = _navyLight);
    c.drawRRect(_rr(w * 0.40, h * 0.54, w * 0.30, h * 0.045, 4), Paint()..color = _gold);
    c.drawRRect(_rr(w * 0.45, h * 0.62, w * 0.20, h * 0.10, 6), Paint()..color = Colors.white.withValues(alpha: 0.85));
    // finished small rolls (right)
    for (var i = 0; i < 3; i++) {
      final cx = w * 0.79 + i * w * 0.075;
      final cy = floor - h * 0.22;
      c.drawRRect(_rr(cx - w * 0.03, cy - h * 0.09, w * 0.06, h * 0.18, 6), Paint()..color = Colors.white);
      c.drawRRect(_rr(cx - w * 0.03, cy - h * 0.09, w * 0.06, h * 0.18, 6), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _steel);
      c.drawCircle(Offset(cx, cy - h * 0.09), h * 0.02, Paint()..color = _gold);
    }
    // control box
    c.drawRRect(_rr(w * 0.72, h * 0.26, w * 0.14, h * 0.20, 10), body);
    final path = Path()..addArc(Rect.fromCircle(center: Offset(w * 0.79, h * 0.36), radius: h * 0.05), math.pi, math.pi);
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _gold);
  }

  void _generic(Canvas c, double w, double h, double floor) {
    c.drawRRect(_rr(w * 0.14, floor - h * 0.16, w * 0.72, h * 0.16, 10), Paint()..color = _navy);
    c.drawRRect(_rr(w * 0.22, h * 0.30, w * 0.56, floor - h * 0.16 - h * 0.30, 14), Paint()..color = _navyLight);
    c.drawRRect(_rr(w * 0.22, h * 0.44, w * 0.56, h * 0.05, 4), Paint()..color = _gold);
    c.drawRRect(_rr(w * 0.30, h * 0.54, w * 0.40, h * 0.16, 8), Paint()..color = Colors.white.withValues(alpha: 0.85));
    c.drawCircle(Offset(w * 0.5, h * 0.62), h * 0.05, Paint()..color = _gold);
  }

  @override
  bool shouldRepaint(_MachinePainter old) => old.type != type || old.status != status;
}
