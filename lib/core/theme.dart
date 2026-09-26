import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // DM Sans, downloaded on first use and cached (falls back to the system font while offline)
    fontFamily: GoogleFonts.dmSans().fontFamily,
    textTheme: GoogleFonts.dmSansTextTheme(Typography.material2021().black.apply(bodyColor: Brand.ink, displayColor: Brand.ink)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Brand.ink,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white.withValues(alpha: 0.88), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.white.withValues(alpha: 0.9), surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(backgroundColor: Brand.navy900, contentTextStyle: const TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.42),
      border: border(Colors.white.withValues(alpha: 0.85)),
      enabledBorder: border(Colors.white.withValues(alpha: 0.85)),
      focusedBorder: border(Brand.gold500, 1.6),
      errorBorder: border(Brand.stopped),
      focusedErrorBorder: border(Brand.stopped, 1.6),
      labelStyle: const TextStyle(color: Brand.inkSoft),
      hintStyle: const TextStyle(color: Brand.inkSoft),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIconColor: Brand.inkSoft,
      suffixIconColor: Brand.inkSoft,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Brand.inkSoft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.gold500 : Brand.track),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    // glass buttons: blurred translucent fill + top sheen, clipped to [radius] (keep it equal to the button's shape),
    // bright hairline edge, soft glow from the button elevation
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Brand.navy900,
        elevation: 5,
        shadowColor: Brand.gold500.withValues(alpha: 0.35),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundBuilder: glassButton(16, active: true),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundBuilder: glassButton(16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Brand.gold300,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundBuilder: glassButton(14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? Brand.inkSoft.withValues(alpha: 0.5) : Brand.ink),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.white.withValues(alpha: 0.85))),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        backgroundBuilder: glassButton(999),
      ),
    ),
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
      // colourful blobs behind everything: glass only reads as glass when there is something to blur
      Positioned(top: -90, right: -70, child: _orb(Brand.gold500.withValues(alpha: 0.55), 320)),
      Positioned(top: 220, left: -130, child: _orb(const Color(0xFF4F8BFF).withValues(alpha: 0.30), 300)),
      Positioned(bottom: 120, right: -110, child: _orb(const Color(0xFFFF8A5B).withValues(alpha: 0.28), 300)),
      Positioned(bottom: -80, left: -60, child: _orb(Brand.navy500.withValues(alpha: 0.28), 320)),
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
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = 20, this.tint, this.alpha = 0.4, this.blur = 20});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius, alpha, blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // frosted glass: blurred backdrop, a diagonal sheen (brighter top-left), a bright hairline edge and a soft warm glow
    final top = (alpha + 0.2).clamp(0.0, 1.0), bottom = (alpha - 0.08).clamp(0.05, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: [
        BoxShadow(color: Brand.navy900.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 8)),
        BoxShadow(color: Brand.gold500.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 4)),
      ]),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur * 1.3, sigmaY: blur * 1.3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [(tint ?? Colors.white).withValues(alpha: top), (tint ?? Colors.white).withValues(alpha: bottom)]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, borderRadius: shape, child: Padding(padding: padding, child: child)),
            ),
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

/// Glass fill for small tinted things (status pills, icon tiles, selected rows): tint gradient + bright hairline.
/// [strong] is for selected / emphasised states.
BoxDecoration glassTint(Color c, [double radius = 20, bool strong = false]) => strong
    ? navPill(radius)
    : BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0.12)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      );

/// The selected-state look from the bottom navigation: a bright cream glass pill with a soft gold glow.
/// Used for the active tab, selected segments / chips / days and primary buttons.
BoxDecoration navPill(double radius) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.85), Brand.goldSoft.withValues(alpha: 0.75)]),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      boxShadow: [BoxShadow(color: Brand.gold500.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4))],
    );

/// Background for glass buttons (ButtonStyle.backgroundBuilder). Not clipped by the button itself, so it clips to [radius]:
/// 16 for normal buttons, 999 for pills / circles. [active] = the cream nav-pill look (primary buttons), else frosted white.
Widget Function(BuildContext, Set<WidgetState>, Widget?) glassButton(double radius, {bool active = false}) => (context, states, child) {
      final off = states.contains(WidgetState.disabled);
      final colors = active ? [Colors.white.withValues(alpha: 0.85), Brand.goldSoft.withValues(alpha: 0.75)] : [Colors.white.withValues(alpha: 0.62), Colors.white.withValues(alpha: 0.22)];
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Opacity(
            opacity: off ? 0.5 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
              child: DecoratedBox(
                // glossy highlight across the top half
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)])),
                child: child,
              ),
            ),
          ),
        ),
      );
    };
