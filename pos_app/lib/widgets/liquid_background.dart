import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen dark liquid glass background with animated floating orbs.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key, required this.child});

  final Widget child;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with TickerProviderStateMixin {
  late final AnimationController _orb1Ctrl;
  late final AnimationController _orb2Ctrl;
  late final AnimationController _orb3Ctrl;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _orb2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
    _orb3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _orb3Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDark(context);
    final AppColors c = appColors(context);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const <Color>[
                    GlassColors.bg1,
                    GlassColors.bg2,
                    GlassColors.bg3,
                  ]
                : <Color>[c.background, c.backgroundSecondary],
            stops: dark ? const [0.0, 0.5, 1.0] : const [0.0, 1.0],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Orb 1 — primary neon red, top-left
            AnimatedBuilder(
              animation: _orb1Ctrl,
              builder: (context, _) {
                final double dx = _lerp(-80, -30, _orb1Ctrl.value);
                final double dy = _lerp(-70, -30, _orb1Ctrl.value);
                return Positioned(
                  left: dx,
                  top: dy,
                  child: _GlowOrb(
                    color: dark
                        ? GlassColors.primary.withValues(alpha: 0.35)
                        : c.primary.withValues(alpha: 0.16),
                    size: 260,
                  ),
                );
              },
            ),

            // Orb 2 — cyan accent, right-center
            AnimatedBuilder(
              animation: _orb2Ctrl,
              builder: (context, _) {
                final double dx = _lerp(-50, -20, _orb2Ctrl.value);
                final double dy = _lerp(120, 180, _orb2Ctrl.value);
                return Positioned(
                  right: dx,
                  top: dy,
                  child: _GlowOrb(
                    color: dark
                        ? GlassColors.accent.withValues(alpha: 0.22)
                        : c.accent.withValues(alpha: 0.12),
                    size: 200,
                  ),
                );
              },
            ),

            // Orb 3 — deep crimson, bottom-center
            AnimatedBuilder(
              animation: _orb3Ctrl,
              builder: (context, _) {
                final double dx = _lerp(60, 100, _orb3Ctrl.value);
                final double dy = _lerp(-80, -40, _orb3Ctrl.value);
                return Positioned(
                  left: dx,
                  bottom: dy,
                  child: _GlowOrb(
                    color: dark
                        ? GlassColors.primaryGlow.withValues(alpha: 0.18)
                        : c.primaryDark.withValues(alpha: 0.10),
                    size: 280,
                  ),
                );
              },
            ),

            // Orb 4 — gold accent, bottom-right  (only in dark mode)
            if (dark)
              AnimatedBuilder(
                animation: _orb2Ctrl,
                builder: (context, _) {
                  final double t = (_orb2Ctrl.value + 0.5) % 1.0;
                  final double dx = _lerp(-40, -10, t);
                  final double dy = _lerp(-60, -30, t);
                  return Positioned(
                    right: dx,
                    bottom: dy,
                    child: _GlowOrb(
                      color: GlassColors.gold.withValues(alpha: 0.10),
                      size: 160,
                    ),
                  );
                },
              ),

            // Frosted noise layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox.expand(),
              ),
            ),

            // Grain noise overlay (dark mode only)
            if (dark)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GrainPainter(),
                  ),
                ),
              ),

            widget.child,
          ],
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 120, spreadRadius: 40),
        ],
      ),
    );
  }
}

/// Paints a very subtle grain noise (dark only).
class _GrainPainter extends CustomPainter {
  final _random = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.012);
    for (int i = 0; i < 1800; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}
