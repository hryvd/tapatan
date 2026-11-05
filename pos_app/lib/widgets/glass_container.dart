import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A frosted-glass panel widget.
/// Applies BackdropFilter blur + semi-transparent background + glowing border.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.sigmaX = 18.0,
    this.sigmaY = 18.0,
    this.tintOpacity = 0.10,
    this.borderOpacity = 0.22,
    this.glowColor,
    this.glowRadius = 24.0,
    this.width,
    this.height,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double sigmaX;
  final double sigmaY;
  final double tintOpacity;
  final double borderOpacity;
  final Color? glowColor;
  final double glowRadius;
  final double? width;
  final double? height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final bool dark = isDark(context);

    final Color tint = dark
        ? Colors.white.withValues(alpha: tintOpacity)
        : Colors.white.withValues(alpha: tintOpacity * 2.5);
    final Color border = dark
        ? Colors.white.withValues(alpha: borderOpacity)
        : Colors.white.withValues(alpha: borderOpacity * 1.5);

    // Reduced blur sigma for low-end GPU performance (was 18)
    final double blurX = sigmaX.clamp(0, 8);
    final double blurY = sigmaY.clamp(0, 8);

    final List<BoxShadow> shadows = [];
    if (glowColor != null) {
      shadows.add(BoxShadow(
        color: glowColor!.withValues(alpha: 0.20),
        blurRadius: glowRadius * 0.6,
        spreadRadius: -2,
      ));
    }
    if (dark) {
      shadows.add(BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ));
    }

    return RepaintBoundary(
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: gradient ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        tint,
                        tint.withValues(alpha: tint.a * 0.6),
                      ],
                    ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: border, width: 1.0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glowing neon badge / pill.
class GlowBadge extends StatelessWidget {
  const GlowBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 11,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: -2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: fontSize + 2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated shimmer loading placeholder styled for dark glass.
class GlassShimmer extends StatefulWidget {
  const GlassShimmer({super.key, required this.width, required this.height, this.borderRadius = 16});

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);
    _anim = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _anim.value * 2.5, 0),
              end: Alignment(0.5 + _anim.value * 2.5, 0),
              colors: const [
                Color(0x1AFFFFFF),
                Color(0x33FFFFFF),
                Color(0x1AFFFFFF),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A glass card that pulses with a glow on hover / focus.
class GlassPulseCard extends StatefulWidget {
  const GlassPulseCard({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<GlassPulseCard> createState() => _GlassPulseCardState();
}

class _GlassPulseCardState extends State<GlassPulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  final bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color glow = widget.glowColor ?? GlassColors.primary;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                        color: glow.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: -2),
                  ]
                : [
                    BoxShadow(
                        color: glow.withValues(alpha: 0.12),
                        blurRadius: 16,
                        spreadRadius: -4),
                  ],
          ),
          child: GlassContainer(
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            glowColor: widget.glowColor,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
