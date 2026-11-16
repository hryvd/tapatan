import 'dart:ui';
import 'package:flutter/material.dart';

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
    this.blur = 10.0,
    this.backgroundColor = const Color.fromRGBO(22, 32, 54, .54),
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
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final sigma = blur > 0 ? blur : (isGlass ? 10.0 : 0.0);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: border,
      ),
      child: child,
    );

    if (sigma > 0) {
      content = ClipRRect(
        borderRadius: effectiveBorderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: boxShadow,
      ),
      child: content,
    );
  }
}
