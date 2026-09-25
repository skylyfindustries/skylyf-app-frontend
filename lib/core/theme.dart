import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Light theme. Palette sampled from the Skylyf logo (navy wordmark + gold "LYF"), on warm cream.
/// See docs/04-design-system.md.
class Brand {
  // surfaces
  static const cream = Color(0xFFFAF6EE);
  static const creamDeep = Color(0xFFF1EADB);
  static const surface = Colors.white;
  // text
  static const ink = Color(0xFF14213D); // primary text (logo navy)
  static const inkSoft = Color(0xFF5B6478);
  // logo colours
  static const navy900 = Color(0xFF0A1A33);
  static const navy700 = Color(0xFF14284B);
  static const navy500 = Color(0xFF24406F);
  static const gold500 = Color(0xFFC8902E); // fills / buttons
  static const gold300 = Color(0xFFB07A1B); // gold text + icons on cream (kept legible)
  static const goldSoft = Color(0xFFF6E7C4);
  // lines
  static const line = Color(0x1A14213D); // ink @ 10%
  static const track = Color(0x1414213D); // progress tracks
  // status
  static const running = Color(0xFF1FA85A);
  static const stopped = Color(0xFFE5484D);
  static const idle = Color(0xFFEA9A0C);
}

Color statusColor(String s) => switch (s) {
      'running' => Brand.running,
      'stopped' => Brand.stopped,
      _ => Brand.idle,
    };

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.gold500,
    brightness: Brightness.light,
    primary: Brand.gold500,
    onPrimary: Brand.navy900,
    surface: Brand.surface,
    onSurface: Brand.ink,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: Typography.material2021().black.apply(bodyColor: Brand.ink, displayColor: Brand.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Brand.ink,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Brand.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Brand.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(backgroundColor: Brand.navy900, contentTextStyle: const TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.8),
      border: border(Brand.line),
      enabledBorder: border(Brand.line),
      focusedBorder: border(Brand.gold500, 1.6),
      errorBorder: border(Brand.stopped),
      focusedErrorBorder: border(Brand.stopped, 1.6),
      labelStyle: const TextStyle(color: Brand.inkSoft),
      hintStyle: const TextStyle(color: Brand.inkSoft),
      prefixIconColor: Brand.inkSoft,
      suffixIconColor: Brand.inkSoft,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Brand.inkSoft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.gold500 : Brand.track),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.gold500,
        foregroundColor: Brand.navy900,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Brand.line, width: 1.4),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Brand.gold300)),
  );
}

/// Warm cream gradient with two soft orbs so the frosted cards have something to blur.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.cream, Brand.creamDeep])),
        ),
      ),
      Positioned(top: -90, right: -70, child: _orb(Brand.gold500.withValues(alpha: 0.28), 280)),
      Positioned(bottom: 100, left: -120, child: _orb(Brand.navy500.withValues(alpha: 0.12), 320)),
      Positioned.fill(child: child),
    ]);
  }

  Widget _orb(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
      );
}

/// Frosted white panel: blur + translucent fill + hairline border + soft shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = 20, this.tint});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: [BoxShadow(color: Brand.navy900.withValues(alpha: 0.07), blurRadius: 22, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: (tint ?? Colors.white).withValues(alpha: 0.78),
            shape: RoundedRectangleBorder(borderRadius: shape, side: BorderSide(color: Colors.white.withValues(alpha: 0.95))),
            child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
          ),
        ),
      ),
    );
  }
}

/// Coloured dot; running machines get a soft pulsing ring.
class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 12, this.pulse = true});
  final String status;
  final double size;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    final dot = Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
    if (status != 'running' || !pulse) return dot;
    final ring = DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.45)));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: ring.animate(onPlay: (ctl) => ctl.repeat()).scale(begin: const Offset(1, 1), end: const Offset(2.3, 2.3), duration: 1500.ms, curve: Curves.easeOut).fadeOut(duration: 1500.ms),
        ),
        dot,
      ]),
    );
  }
}

/// The logo sits on a white card so the navy wordmark stays crisp.
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.width = 180});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Brand.navy900.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10))]),
        child: Image.asset('assets/logo.webp', width: width),
      );
}

String fmt(num n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
