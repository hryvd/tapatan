import 'package:flutter/material.dart';

class GlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final List<Color>? gradientColors;
  final bool isLoading;
  final bool isSecondary;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradientColors,
    this.isLoading = false,
    this.isSecondary = false,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;

    // Determine gradient colors
    final List<Color> gradColors = widget.gradientColors ??
        (widget.isSecondary
            ? [const Color(0xFF0C1E35), const Color(0xFF0A1628)]
            : [const Color(0xFF0369A1), const Color(0xFF0891B2)]);

    Widget buttonContent = widget.isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : widget.child;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _controller.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Opacity(
          opacity: disabled ? 0.45 : 1.0,
          child: Container(
            width: double.infinity,
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: widget.isSecondary
                    ? const Color(0xFF0891B2).withOpacity(0.35)
                    : Colors.white.withOpacity(0.15),
              ),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: (widget.isSecondary
                                ? const Color(0xFF0369A1)
                                : const Color(0xFF0891B2))
                            .withOpacity(0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                child: buttonContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
