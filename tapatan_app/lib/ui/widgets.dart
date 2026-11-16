import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/lucide_icons.dart';
import 'tokens.dart';

// ───────────────────────── Press animation ─────────────────────────
/// whileTap scale wrapper (Btn .97, Numpad key .92).
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;
  const PressScale({super.key, required this.child, this.onTap, this.scale = .97, this.behavior = HitTestBehavior.opaque});
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────── Glass surfaces ─────────────────────────
enum GlassKind { glass, strong, tint, pill }

/// Liquid-glass surface (.glass / .glass-strong / .glass-tint / .glass-pill).
/// [radius] overrides the default per kind (glass 26, strong 16, tint 26, pill 999).
class Glass extends StatelessWidget {
  final Widget? child;
  final GlassKind kind;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width, height;
  final Color? fill; // overrides background fill (e.g. T.navFill)
  final BorderRadiusGeometry? borderRadius; // overrides radius (e.g. sheet top-only)
  final bool blur;
  const Glass({
    super.key,
    this.child,
    this.kind = GlassKind.glass,
    this.radius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.fill,
    this.borderRadius,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    // Translucent blurred surface with no stroke/border, no glow, no liquid highlight.
    late double r;
    late double sigma;
    late Color color;
    switch (kind) {
      case GlassKind.glass:
        r = T.rGlass;
        color = T.surface;
        sigma = 10;
        break;
      case GlassKind.strong:
        r = T.rStrong;
        color = T.surfaceStrong;
        sigma = 14;
        break;
      case GlassKind.tint:
        r = T.rGlass;
        color = T.surfaceTint;
        sigma = 10;
        break;
      case GlassKind.pill:
        r = 999;
        color = T.surfacePill;
        sigma = 8;
        break;
    }
    if (radius != null) r = radius!;
    if (fill != null) color = fill!;
    final br = borderRadius ?? BorderRadius.circular(r);
    Widget body = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        color: color,
      ),
      child: child,
    );
    if (blur) {
      body = ClipRRect(
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: body,
        ),
      );
    }
    if (margin != null) {
      body = Padding(padding: margin!, child: body);
    }
    return body;
  }
}


// ───────────────────────── Buttons ─────────────────────────
enum BtnVariant { primary, glass, danger }

/// `Btn` — h-12, rounded 18, weight 700, press scale .97, disabled opacity .4.
/// [width]: null = natural/expanded by parent; use `double.infinity` for w-full.
class Btn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool disabled;
  final BtnVariant variant;
  final double? width;
  final EdgeInsetsGeometry padding;
  const Btn({super.key, required this.child, this.onTap, this.disabled = false, this.variant = BtnVariant.primary, this.width, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  /// Convenience: text label.
  factory Btn.text(String label, {Key? key, VoidCallback? onTap, bool disabled = false, BtnVariant variant = BtnVariant.primary, double? width, EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20)}) =>
      Btn(
        key: key,
        onTap: onTap,
        disabled: disabled,
        variant: variant,
        width: width,
        padding: padding,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Color fg = Colors.white;
    BoxDecoration deco;
    switch (variant) {
      case BtnVariant.primary:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(T.rBtn),
          color: T.teal,
        );
        break;
      // Every button is solid teal (danger/glass variants no longer differ).
      case BtnVariant.danger:
      case BtnVariant.glass:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(T.rBtn),
          color: T.teal,
        );
        break;
    }
    final isOff = disabled || onTap == null && false;
    return Opacity(
      opacity: isOff ? .4 : 1,
      child: PressScale(
        onTap: isOff ? null : onTap,
        child: Container(
          width: width,
          height: T.btnH,
          padding: padding,
          alignment: Alignment.center,
          decoration: deco,
          child: DefaultTextStyle(
            style: T.btn.copyWith(color: fg),
            child: IconTheme(
              data: IconThemeData(color: fg, size: 18),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, spacing: 8, children: [Flexible(child: child)]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular glass-pill icon button (close buttons: 32px sheet / 36px NFC cancel).
class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;
  const GlassIconBtn({super.key, required this.icon, this.onTap, this.size = 32, this.iconSize = 16, this.color});
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Glass(
          kind: GlassKind.pill,
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color ?? T.white(.8)),
        ),
      );
}

// ───────────────────────── Inputs ─────────────────────────
/// `Field` — label (11px/600 white50) above h-11 rounded-14 input; cyan focus border.
class Field extends StatefulWidget {
  final String label;
  final bool mono;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffix;
  final bool enabled;
  final String? initialValue;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  const Field({super.key, required this.label, this.mono = false, this.controller, this.hint, this.obscure = false, this.keyboardType, this.onChanged, this.onSubmitted, this.inputFormatters, this.maxLength, this.suffix, this.enabled = true, this.initialValue, this.textInputAction, this.focusNode});
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _focus = false;
  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focus = _node.hasFocus));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.mono ? T.mono(14) : T.text(14));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(widget.label, style: T.label)),
        ClipRRect(
          borderRadius: BorderRadius.circular(T.rField),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: T.fieldH,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _focus ? T.inputFillFocus : T.inputFill,
                borderRadius: BorderRadius.circular(T.rField),
              ),
              child: Row(children: [
            Expanded(
              child: TextFormField(
                focusNode: _node,
                controller: widget.controller,
                initialValue: widget.controller == null ? widget.initialValue : null,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onSubmitted,
                inputFormatters: widget.inputFormatters,
                maxLength: widget.maxLength,
                enabled: widget.enabled,
                textInputAction: widget.textInputAction,
                cursorColor: T.teal,
                style: style,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: widget.hint,
                  hintStyle: style.copyWith(color: T.white(.25)),
                ),
              ),
            ),
            if (widget.suffix != null) widget.suffix!,
          ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// `Toggle` row with label/hint and 46x28 switch (emerald when on).
class Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? hint;
  const Toggle({super.key, required this.on, required this.onChanged, required this.label, this.hint});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: T.text(13, w: T.w600)),
                if (hint != null) Text(hint!, style: T.text(11, color: T.white(.45))),
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 28,
              decoration: BoxDecoration(color: on ? T.teal : T.white(.15), borderRadius: BorderRadius.circular(99)),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  top: 2,
                  left: on ? 20 : 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// 3-col numpad (h-14, radius 20). Controlled: pass [value], receive [onChanged].
class Numpad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final int max;
  const Numpad({super.key, required this.value, required this.onChanged, this.max = 6});
  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      mainAxisExtent: T.keyH,
      children: [
        for (final k in keys)
          k.isEmpty
              ? const SizedBox()
              : PressScale(
                  scale: .92,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(k == '⌫' ? (value.isEmpty ? value : value.substring(0, value.length - 1)) : (value.length < max ? value + k : value));
                  },
                  child: Glass(
                    kind: GlassKind.pill,
                    radius: T.rKey,
                    child: Center(child: k == '⌫' ? Icon(LucideIcons.delete, size: 20, color: Colors.white) : Text(k, style: T.text(20, w: T.w600))),
                  ),
                ),
      ],
    );
  }
}

/// PIN indicator dots (14px; filled cyan-300 with glow).
class PinDots extends StatelessWidget {
  final int n;
  final int max;
  const PinDots({super.key, required this.n, this.max = 6});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < max; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(left: i == 0 ? 0 : 12),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < n ? T.teal : T.white(.22),
              ),
            ),
        ]),
      );
}

// ───────────────────────── Small pieces ─────────────────────────
/// Pill badge (e.g. ENROLLED · TPT4). Defaults to emerald.
class Badge2 extends StatelessWidget {
  final String text;
  final Color color; // base tone, fill=.2, border=.5
  final Color? textColor;
  final bool mono;
  final double fontSize;
  const Badge2(this.text, {super.key, this.color = T.emerald400, this.textColor, this.mono = true, this.fontSize = 8.5});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: T.op(color, .22), borderRadius: BorderRadius.circular(99)),
            child: Text(text, style: (mono ? T.mono(fontSize) : T.text(fontSize, w: T.w600)).copyWith(color: textColor ?? T.emerald300)),
          ),
        ),
      );
}

/// Section title row: text 15/700 with optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.text(15, w: T.w700))),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ]),
      );
}

/// Dashed-underline small text button (e.g. "Demo: simulate unauthorized card").
class LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const LinkText(this.text, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(text, textAlign: TextAlign.center, style: T.text(11, color: T.white(.35)).copyWith(decoration: TextDecoration.underline, decorationColor: T.white(.35))),
      );
}

// ───────────────────────── Page background (static depth) ─────────────────────────
/// Static ambient backdrop so blurred translucent elements have subtle depth without per-frame ticks.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF070C16), T.bg, Color(0xFF0A1624)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.75, -0.80),
                      radius: 0.95,
                      colors: [Color(0x240D9488), Color(0x000D9488)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.85, 0.78),
                      radius: 0.90,
                      colors: [Color(0x1E1D4ED8), Color(0x001D4ED8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ───────────────────────── Bottom nav ─────────────────────────
class NavTab {
  final String label;
  final IconData icon;
  const NavTab(this.label, this.icon);
}

/// Default 5 tabs from App.tsx: Home, Cards, Sar-E, Analytics, Profile.
const kNavTabs = [
  NavTab('Home', LucideIcons.home),
  NavTab('Cards', LucideIcons.creditCard),
  NavTab('Sar-E', LucideIcons.store),
  NavTab('Analytics', LucideIcons.barChart2),
  NavTab('Profile', LucideIcons.user),
];

/// Floating liquid-glass nav. Position it with `Positioned(left:12,right:12,bottom:12)` or use [AppBottomNav.positioned].
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<NavTab> tabs;
  const AppBottomNav({super.key, required this.index, required this.onTap, this.tabs = kNavTabs});

  static Widget positioned({required int index, required ValueChanged<int> onTap, List<NavTab> tabs = kNavTabs}) =>
      Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: AppBottomNav(index: index, onTap: onTap, tabs: tabs)));

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    return Glass(
      radius: T.rNav,
      fill: T.navFill,
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / n;
        return SizedBox(
          height: 54,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              left: w * index,
              width: w,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: T.white(.10),
                  borderRadius: BorderRadius.circular(T.rNavItem),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    label: tabs[i].label,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(tabs[i].icon, size: 21, color: i == index ? T.teal : T.white(.55)),
                        const SizedBox(height: 2),
                        Text(tabs[i].label, style: T.text(10, w: i == index ? T.w700 : T.w500, color: i == index ? T.teal : T.white(.55))),
                      ]),
                    ),
                  ),
                ),
            ]),
          ]),
        );
      }),
    );
  }
}

/// Slide-up + fade (8px) entrance used on tab switch. Give it a ValueKey per tab.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const FadeSlideIn({super.key, required this.child, this.duration = const Duration(milliseconds: 300)});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOut,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c)),
        child: child,
      );
}

// ───────────────────────── Sheet ─────────────────────────
/// Bottom sheet (glass-strong, top radius 32, grabber, title + close). Returns the popped value.
/// Content scrolls; padded px-5 pb-8 pt-1. [tall] = 88% height else wraps up to 88%.
Future<T2?> showAppSheet<T2>(BuildContext context, {required String title, required Widget child, bool tall = false}) {
  return showGeneralDialog<T2>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, a, b) => _SheetBody(title: title, tall: tall, child: child),
    transitionBuilder: (ctx, a, b, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).maybePop(),
            child: FadeTransition(
              opacity: curved,
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: ColoredBox(color: T.blk(.55))),
            ),
          ),
        ),
        SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: child),
      ]);
    },
  );
}

class _SheetBody extends StatelessWidget {
  final String title;
  final Widget child;
  final bool tall;
  const _SheetBody({required this.title, required this.child, required this.tall});
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * .88;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: ConstrainedBox(
          constraints: tall ? BoxConstraints.tightFor(height: h) : BoxConstraints(maxHeight: h),
          child: Material(
            type: MaterialType.transparency,
            child: Glass(
              kind: GlassKind.strong,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
              child: Column(mainAxisSize: tall ? MainAxisSize.max : MainAxisSize.min, children: [
                Container(margin: const EdgeInsets.only(top: 8), width: 36, height: 4, decoration: BoxDecoration(color: T.white(.3), borderRadius: BorderRadius.circular(99))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.text(17, w: T.w700))),
                    const SizedBox(width: 8),
                    GlassIconBtn(icon: LucideIcons.x, onTap: () => Navigator.of(context).maybePop()),
                  ]),
                ),
                Flexible(fit: tall ? FlexFit.tight : FlexFit.loose, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), child: child)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Toast ─────────────────────────
OverlayEntry? _toast;
Timer? _toastTimer;

/// Top-center glass-strong pill toast (auto-dismiss, default 2.2s / 3.2s for errors).
void showToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration? duration,
}) {
  _toastTimer?.cancel();
  _toast?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  final top = MediaQuery.of(context).padding.top + 52;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (_, v, c) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, -20 * (1 - v)),
                  child: c,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Glass(
                  kind: GlassKind.strong,
                  fill: isError ? const Color(0xEB991B1B) : null,
                  radius: isError ? 18 : 999,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: isError
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.alertCircle,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                message,
                                style: T.text(12, w: T.w600, color: Colors.white, height: 1.35),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          message,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: T.text(12, w: T.w600, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(
    duration ?? Duration(milliseconds: isError ? 3200 : 2200),
    () {
      entry.remove();
      if (_toast == entry) _toast = null;
    },
  );
}

// ───────────────────────── NFC tap simulation ─────────────────────────
/// Full-screen NFC tap simulation (Scanning → Verifying → Approved | Unauthorized(5s retry)).
/// Put in a Stack over the screen, or push via `showNfcTap`.
class NfcTap extends StatefulWidget {
  final String title;
  final List<String> apdu;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final String doneLabel;
  final Widget? successNode;
  const NfcTap({super.key, required this.title, required this.apdu, required this.onSuccess, required this.onCancel, this.doneLabel = 'Done', this.successNode});
  @override
  State<NfcTap> createState() => _NfcTapState();
}

enum _Phase { scan, verify, ok, fail }

class _NfcTapState extends State<NfcTap> with TickerProviderStateMixin {
  _Phase phase = _Phase.scan;
  int step = 0, left = 5;
  bool forceFail = false;
  Timer? _t;
  late final AnimationController _ring;
  late final AnimationController _shake;
  late final AnimationController _dash;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _dash = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _enter();
  }

  @override
  void dispose() {
    _t?.cancel();
    _ring.dispose();
    _shake.dispose();
    _dash.dispose();
    super.dispose();
  }

  void _set(_Phase p) {
    if (!mounted) return;
    setState(() => phase = p);
    _enter();
  }

  void _enter() {
    _t?.cancel();
    switch (phase) {
      case _Phase.scan:
        _t = Timer(const Duration(milliseconds: 2400), () {
          if (forceFail) {
            forceFail = false;
            left = 5;
            _shake.forward(from: 0);
            _dash.forward(from: 0);
            _set(_Phase.fail);
          } else {
            step = 0;
            _set(_Phase.verify);
          }
        });
        break;
      case _Phase.verify:
        _tickVerify();
        break;
      case _Phase.fail:
        _tickFail();
        break;
      case _Phase.ok:
        break;
    }
  }

  void _tickVerify() {
    if (step < widget.apdu.length) {
      _t = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() => step++);
        _tickVerify();
      });
    } else {
      _t = Timer(const Duration(milliseconds: 400), () => _set(_Phase.ok));
    }
  }

  void _tickFail() {
    if (left <= 0) {
      _set(_Phase.scan);
      return;
    }
    _t = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => left--);
      _tickFail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fail = phase == _Phase.fail, ok = phase == _Phase.ok;
    final tone = fail ? T.red400 : ok ? T.emerald400 : T.teal;
    final title = ok ? 'Approved ✓' : fail ? 'Unauthorized Card' : phase == _Phase.verify ? 'Verifying Card & MAC…' : widget.title;
    return Material(
      type: MaterialType.transparency,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: T.op(T.bg, .76),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 56, 24, 32),
            child: Stack(children: [
              Column(children: [
                Text('ISO 14443-4 · JCOP4 J3R150', style: T.mono(11, color: T.white(.45), ls: 1.1)),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.center, style: T.text(22, w: T.w800)),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shake,
                    builder: (_, c) {
                      final v = _shake.value;
                      final dx = fail && _shake.isAnimating ? (v < .2 ? -8 * v / .2 : v < .4 ? -8 + 16 * (v - .2) / .2 : v < .6 ? 8 - 16 * (v - .4) / .2 : v < .8 ? -8 + 16 * (v - .6) / .2 : 8 * (1 - v) / .2) : 0.0;
                      return Transform.translate(offset: Offset(dx, 0), child: c);
                    },
                    child: Center(
                      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                        if (!fail && !ok)
                          for (var i = 0; i < 3; i++)
                            AnimatedBuilder(
                              animation: _ring,
                              builder: (_, _) {
                                final p = ((_ring.value * 2.4 - i * .8) / 2.4) % 1.0;
                                final pp = p < 0 ? p + 1 : p;
                                final eased = Curves.easeOut.transform(pp);
                                return Opacity(
                                  opacity: .8 * (1 - eased),
                                  child: Transform.scale(scale: .4 + 1.2 * eased, child: Container(width: 208, height: 208, decoration: BoxDecoration(shape: BoxShape.circle, color: T.op(tone, .18)))),
                                );
                              },
                            ),
                        if (fail)
                          SizedBox(
                            width: 224, height: 224,
                            child: AnimatedBuilder(animation: _dash, builder: (_, _) => CustomPaint(painter: _RingPainter(_dash.value))),
                          ),
                        AnimatedScale(
                          scale: ok ? 1.1 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: Glass(
                              radius: 64, width: 128, height: 128,
                              child: Icon(ok ? LucideIcons.check : fail ? LucideIcons.shieldAlert : LucideIcons.nfc, size: 56, color: tone),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                _bottom(fail, ok),
              ]),
              Positioned(top: 0, right: -4, child: GlassIconBtn(icon: LucideIcons.x, size: 36, onTap: widget.onCancel)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottom(bool fail, bool ok) {
    switch (phase) {
      case _Phase.scan:
        return Column(children: [
          Text('Hold your tap@tan JCOP4 card to the back of your phone', textAlign: TextAlign.center, style: T.text(13, color: T.white(.6))),
          const SizedBox(height: 12),
          LinkText('Demo: simulate unauthorized card', onTap: () => setState(() => forceFail = true)),
        ]);
      case _Phase.verify:
        return Glass(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            for (var i = 0; i < widget.apdu.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: DefaultTextStyle(
                  style: T.mono(11.5, color: i < step ? T.emerald400 : i == step ? T.teal : T.white(.3)),
                  child: Row(children: [
                    i < step ? const Icon(LucideIcons.check, size: 14, color: T.emerald400) : const SizedBox(width: 14, child: Center(child: Text('›'))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.apdu[i])),
                    if (i < step) Text('9000', style: T.mono(11.5, color: T.white(.4))),
                  ]),
                ),
              ),
          ]),
        );
      case _Phase.fail:
        return Column(children: [
          Text('SW 0x6982 · SECURITY_STATUS_NOT_SATISFIED', style: T.mono(12, color: T.red400)),
          const SizedBox(height: 4),
          Text('Auto-rescanning in ${left}s…', style: T.text(12, color: T.white(.55))),
          const SizedBox(height: 12),
          Btn(variant: BtnVariant.glass, width: double.infinity, onTap: () => _set(_Phase.scan), child: Text('Retry Now (${left}s)')),
        ]);
      case _Phase.ok:
        return Column(children: [
          if (widget.successNode != null) widget.successNode!,
          const SizedBox(height: 12),
          Btn(width: double.infinity, onTap: widget.onSuccess, child: Text(widget.doneLabel)),
        ]);
    }
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  _RingPainter(this.p);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width * .45;
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = s.width * .03..color = T.white(.1));
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = s.width * .03..strokeCap = StrokeCap.round..color = T.amber500;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.5708, 6.2832 * (1 - p), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.p != p;
}

/// Convenience: show NfcTap as a full-screen route overlay. Pops itself on cancel/success.
Future<bool?> showNfcTap(BuildContext context, {required String title, required List<String> apdu, String doneLabel = 'Done', Widget? successNode}) {
  return Navigator.of(context, rootNavigator: true).push<bool>(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, a, b) => FadeTransition(
      opacity: a,
      child: NfcTap(
        title: title,
        apdu: apdu,
        doneLabel: doneLabel,
        successNode: successNode,
        onSuccess: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    ),
  ));
}
