import 'package:flutter/material.dart';
import 'dart:ui';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color backgroundColor;
  final Border? border;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;
  final bool isGlass;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 0.0,
    this.backgroundColor = const Color(0xFF18181B), // Shadcn card color
    this.border,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16); // Shadcn uses slightly smaller radius
    
    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: border ?? Border.all(color: const Color(0xFF27272A)), // Shadcn border color
      ),
      child: child,
    );

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: boxShadow ?? [
          const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: (isGlass && blur > 0)
          ? ClipRRect(
              borderRadius: effectiveBorderRadius,
              clipBehavior: clipBehavior,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: innerContainer,
              ),
            )
          : innerContainer,
    );
  }
}
