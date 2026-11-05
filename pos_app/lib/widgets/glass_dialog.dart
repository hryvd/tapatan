import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows a premium glassmorphic dialog with a beautifully animated blurred background.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'GlassDialog',
    barrierColor: Colors.black.withValues(alpha: 0.15), // Very subtle dimming to separate layers
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return builder(context);
    },
    transitionBuilder: (context, anim1, anim2, child) {
      // Elastic spring animation for premium feel
      final double curvedValue = Curves.easeOutBack.transform(anim1.value) - 1.0;
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: anim1.value * 12.0,
          sigmaY: anim1.value * 12.0,
        ),
        child: Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * -40, 0.0),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
      );
    },
  );
}
