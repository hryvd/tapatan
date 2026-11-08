import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';
import 'tokens.dart';
import 'widgets.dart' show Badge2;

/// Plain-data card (mirrors store.tsx CardT; no provider dependency).
class CardData {
  final String id, name, material, network, num;
  final String kind; // 'virtual' | 'pass' | 'bank'
  final bool physical;
  final String? format; // 'qr' | 'barcode' (passes)
  final String? code, bank;
  const CardData({
    this.id = '',
    this.name = '',
    this.material = 'cyber',
    this.network = 'Visa',
    this.num = '•••• •••• •••• 0000',
    this.kind = 'virtual',
    this.physical = false,
    this.format,
    this.code,
    this.bank,
  });
}

class CardMaterial {
  final String label;
  final List<Gradient> layers; // top-most first
  final Color base; // bottom-most fill
  final Color accent;
  const CardMaterial(this.label, this.layers, this.base, this.accent);
}

/// CSS `linear-gradient(<deg>deg, ...)` equivalent.
LinearGradient cssLinear(double deg, List<Color> colors, [List<double>? stops]) {
  final r = deg * math.pi / 180;
  return LinearGradient(begin: Alignment(-math.sin(r), math.cos(r)), end: Alignment(math.sin(r), -math.cos(r)), colors: colors, stops: stops);
}

RadialGradient _rad(double cx, double cy, double radius, Color c, [double stop = .55]) =>
    RadialGradient(center: Alignment(cx * 2 - 1, cy * 2 - 1), radius: radius, colors: [c, c.withValues(alpha: 0)], stops: [0, stop]);

final Map<String, CardMaterial> kMaterials = {
  'obsidian': CardMaterial('Obsidian', [
    _rad(.85, 0, 1.9, const Color.fromRGBO(6, 182, 212, .55)),
    cssLinear(145, const [Color(0xFF1B2433), Color(0xFF05080F)], const [0, .7]),
  ], const Color(0xFF05080F), const Color(0xFF22D3EE)),
  'cyber': CardMaterial('Cyber Glass', [
    _rad(.1, 0, 1.75, const Color.fromRGBO(34, 211, 238, .6)),
    _rad(1, 1, 1.43, const Color.fromRGBO(99, 102, 241, .6), .6),
  ], const Color(0xFF0B1424), const Color(0xFF67E8F9)),
  'chrome': CardMaterial('Holo Chrome', [
    cssLinear(135, const [Color(0xFFCBD5E1), Color(0xFF64748B), Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFF475569)], const [0, .3, .5, .7, 1]),
  ], const Color(0xFF64748B), const Color(0xFF0F172A)),
  'emerald': CardMaterial('Emerald', [
    _rad(.9, 0, 1.59, const Color.fromRGBO(52, 211, 153, .6)),
    cssLinear(145, const [Color(0xFF064E3B), Color(0xFF022C22)]),
  ], const Color(0xFF022C22), const Color(0xFF6EE7B7)),
  'indigo': CardMaterial('Indigo', [
    _rad(.9, 0, 1.59, const Color.fromRGBO(167, 139, 250, .7)),
    cssLinear(145, const [Color(0xFF312E81), Color(0xFF1E1B4B)]),
  ], const Color(0xFF1E1B4B), const Color(0xFFC4B5FD)),
  'amber': CardMaterial('Amber', [
    _rad(.9, 0, 1.59, const Color.fromRGBO(251, 191, 36, .65)),
    cssLinear(145, const [Color(0xFF3A2A0A), Color(0xFF0C0A05)]),
  ], const Color(0xFF0C0A05), const Color(0xFFFCD34D)),
};

Widget _materialBg(CardMaterial m) => Stack(fit: StackFit.expand, children: [
      ColoredBox(color: m.base),
      for (final g in m.layers.reversed) DecoratedBox(decoration: BoxDecoration(gradient: g)),
    ]);

/// Brushed grain: repeating 1px white line every 3px, overlay blend.
class _GrainPainter extends CustomPainter {
  final double opacity;
  _GrainPainter(this.opacity);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: opacity)..blendMode = BlendMode.overlay;
    for (double x = 0; x < s.width; x += 3) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, s.height), p);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter o) => o.opacity != opacity;
}

/// EMV chip 44x32, radius 7.
class CardChip extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const CardChip({super.key, this.margin});
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 32,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: cssLinear(135, const [Color(0xFFFDE68A), Color(0xFFD4A63A), Color(0xFFF5D77A)], const [0, .45, 1]),
          border: Border.all(color: T.blk(.4), width: .5),
        ),
        child: CustomPaint(painter: _ChipLines()),
      );
}

class _ChipLines extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = T.blk(.25)..strokeWidth = 1;
    c.drawLine(Offset(s.width / 3, 0), Offset(s.width / 3, s.height), p);
    c.drawLine(Offset(s.width * 2 / 3, 0), Offset(s.width * 2 / 3, s.height), p);
    c.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Deterministic pseudo QR / barcode (same hash as the React `Code`).
class CodeMark extends StatelessWidget {
  final bool qr;
  final String value;
  final bool dark; // true → white modules
  const CodeMark({super.key, required this.qr, required this.value, this.dark = false});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CodePainter(qr, value, dark), size: Size.infinite);
}

class _CodePainter extends CustomPainter {
  final bool qr, dark;
  final String value;
  _CodePainter(this.qr, this.value, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    int h = 2166136261;
    final src = value.isEmpty ? 'x' : value;
    for (final ch in src.codeUnits) {
      h = (((h ^ ch).toSigned(32)) * 16777619 & 0xFFFFFFFF).toSigned(32);
      if (h == 0) h = 0;
    }
    double rnd(int i) {
      final x = math.sin(h + i * 12.9898) * 43758.5453;
      return x - x.floorToDouble();
    }

    final paint = Paint()..color = dark ? Colors.white : T.slate900;
    if (!qr) {
      final sx = size.width / 120, sy = size.height / 40;
      double x = 2;
      for (var i = 0; i < 48 && x < 118; i++) {
        final w = 1 + (rnd(i) * 3).floor();
        if (i % 2 == 0) canvas.drawRect(Rect.fromLTWH(x * sx, 0, w * sx, 40 * sy), paint);
        x += w + .4;
      }
      return;
    }
    const n = 21;
    final cs = size.width / n, cy = size.height / n;
    bool fin(int x, int y) => (x < 7 && y < 7) || (x > 13 && y < 7) || (x < 7 && y > 13);
    bool f(int a, int b) {
      final m = math.min(math.min(a, 6 - a), math.min(b, 6 - b));
      return m == 0 || m >= 2;
    }

    bool ring(int x, int y) {
      final lx = (x % 14 > 6 && x > 13) ? x - 14 : x;
      final ly = y > 13 ? y - 14 : y;
      return f(lx, ly);
    }

    for (var i = 0; i < n * n; i++) {
      final x = i % n, y = i ~/ n;
      final on = fin(x, y) ? ring(x, y) : rnd(i) > .52;
      if (on) canvas.drawRect(Rect.fromLTWH(x * cs, y * cy, cs * 1.02, cy * 1.02), paint);
    }
  }

  @override
  bool shouldRepaint(_CodePainter o) => o.value != value || o.qr != qr || o.dark != dark;
}

const double kCardAspect = 1.586;

/// QR / barcode pass face (ticket style with notches).
class PassFace extends StatelessWidget {
  final CardData card;
  const PassFace({super.key, required this.card});
  @override
  Widget build(BuildContext context) {
    final m = kMaterials[card.material] ?? kMaterials['cyber']!;
    final qr = (card.format ?? 'qr') == 'qr';
    return AspectRatio(
      aspectRatio: kCardAspect,
      child: LayoutBuilder(builder: (context, c) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(T.rCard),
          child: Stack(fit: StackFit.expand, children: [
            _materialBg(m),
            Opacity(opacity: 1, child: CustomPaint(painter: _GrainPainter(.12))),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(qr ? 'QR PASS' : 'BARCODE PASS', style: T.mono(8.5, color: T.white(.7), ls: 8.5 * .1)),
                      const SizedBox(height: 4),
                      Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.text(17, w: T.w800, height: 1.25)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CODE', style: T.mono(8, color: T.white(.6))),
                      Text(card.code ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.mono(11)),
                    ]),
                  ]),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                padding: const EdgeInsets.all(8),
                width: qr ? 86 : 96,
                height: qr ? 86 : 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: CodeMark(qr: qr, value: card.code ?? ''),
              ),
            ]),
            Positioned(left: c.maxWidth - 110, top: -8, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: T.bg, shape: BoxShape.circle))),
            Positioned(left: c.maxWidth - 110, bottom: -8, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: T.bg, shape: BoxShape.circle))),
            IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rCard), border: Border.all(color: T.white(.2))))),
          ]),
        );
      }),
    );
  }
}

/// Front face of a card. [tiltX]/[tiltY] ∈ [-1,1] drive the holographic foil + glare.
/// Width fills parent; height = width / 1.586. Fixed-px layout designed for ~290px width.
class CardFace extends StatelessWidget {
  final CardData card;
  final String holder;
  final double tiltX, tiltY;
  final bool frozen;
  final bool small;
  const CardFace({super.key, required this.card, required this.holder, this.tiltX = 0, this.tiltY = 0, this.frozen = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    if (card.kind == 'pass') return PassFace(card: card);
    final m = kMaterials[card.material] ?? kMaterials['obsidian']!;
    final dark = card.material == 'chrome';
    final txt = dark ? T.slate900 : Colors.white;
    final tx = tiltX;
    double pct(double v) => ((v) / 100).clamp(0.0, 1.0);
    final sub = card.physical ? 'JCOP4 J3R150' : card.kind == 'bank' ? (card.bank ?? 'BANK').toUpperCase() : 'VIRTUAL';
    final foilStops = [pct(30 + tx * 25), pct(42 + tx * 25), pct(50 + tx * 25), pct(58 + tx * 25), pct(70 + tx * 25)];
    return AspectRatio(
      aspectRatio: kCardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: Stack(fit: StackFit.expand, children: [
          // bg + grain + holo foil (color-dodge)
          ShaderMask(
            blendMode: BlendMode.colorDodge,
            shaderCallback: (r) => cssLinear(115 + tx * 40, const [
              Color(0x00000000),
              Color.fromRGBO(255, 0, 200, .35 * .6),
              Color.fromRGBO(0, 255, 220, .4 * .6),
              Color.fromRGBO(255, 230, 0, .3 * .6),
              Color(0x00000000),
            ], foilStops).createShader(r),
            child: Stack(fit: StackFit.expand, children: [
              _materialBg(m),
              CustomPaint(painter: _GrainPainter(.13)),
            ]),
          ),
          // glare orb
          Positioned(
            top: -64 + tiltY * -20,
            right: -40 + tiltX * 30,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(width: 192, height: 192, decoration: BoxDecoration(shape: BoxShape.circle, color: T.white(.10))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: T.text(12, color: txt),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'tap'),
                        TextSpan(text: '@', style: TextStyle(color: m.accent)),
                        const TextSpan(text: 'tan'),
                      ]),
                      style: T.text(small ? 15 : 17, w: T.w800, color: txt, height: 1, shadows: dark ? null : [Shadow(color: T.blk(.4), offset: const Offset(0, 1))]),
                    ),
                    const SizedBox(height: 4),
                    Text(sub, style: T.mono(8.5, color: txt.withValues(alpha: .7), ls: 8.5 * .05)),
                  ]),
                  Icon(LucideIcons.nfc, size: 20, color: txt.withValues(alpha: .8)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const CardChip(margin: EdgeInsets.only(bottom: 10)),
                  Text(card.num, style: T.mono(13.5, color: txt, ls: 13.5 * .12)),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(holder, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.text(10.5, w: T.w600, color: txt, ls: 10.5 * .05)),
                  ),
                  if (card.physical)
                    const Badge2('ENROLLED · TPT4', color: Color(0xFF34D399), textColor: Color(0xFFA7F3D0))
                  else
                    Text(card.network.split(' ').first.toUpperCase(), style: T.text(10, w: T.w700, color: txt.withValues(alpha: .8))),
                ]),
              ]),
            ),
          ),
          if (frozen)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(224, 242, 254, .25),
                    gradient: cssLinear(135, const [Color.fromRGBO(255, 255, 255, .4), Color.fromRGBO(186, 230, 253, .1), Color.fromRGBO(255, 255, 255, .35)], const [0, .4, 1]),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: T.white(.3), border: Border.all(color: T.white(.6))),
                    child: const Icon(LucideIcons.lock, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rCard), border: Border.all(color: T.white(.2))),
            ),
          ),
          // inset top highlight
          Positioned(top: 0, left: 0, right: 0, height: 1, child: IgnorePointer(child: ColoredBox(color: T.white(.35)))),
        ]),
      ),
    );
  }
}

/// Interactive 3D stage from CardsScreen.tsx: pointer tilt (rotX = 8 − ty·12°, rotY = −12 + tx·18°),
/// double-tap (or single tap if [tapToFlip]) flips 180° around Y, vertical swipe > 60px → [onSwipe] (±1).
/// Entrance: slides up 60px, fades in, rotateX 40°→tilt. Give it a `ValueKey(card.id)` to replay entrance.
/// Stage is 270px tall (perspective 1200); card is [cardWidth] wide, placed at top 44, centered.
class Card3D extends StatefulWidget {
  final Widget Function(double tiltX, double tiltY) front;
  final Widget back;
  final bool flipped;
  final VoidCallback? onFlip;
  final ValueChanged<int>? onSwipe;
  final bool flat; // X-ray mode: no tilt/flip (rotX=rotY=0)
  final bool tapToFlip;
  final double cardWidth;
  final double stageHeight;
  final double cardTop;
  const Card3D({super.key, required this.front, required this.back, this.flipped = false, this.onFlip, this.onSwipe, this.flat = false, this.tapToFlip = false, this.cardWidth = 290, this.stageHeight = 270, this.cardTop = 44});
  @override
  State<Card3D> createState() => _Card3DState();
}

class _Card3DState extends State<Card3D> with SingleTickerProviderStateMixin {
  double tx = 0, ty = 0;
  double? _startY;
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  void _move(Offset p, Size s) => setState(() {
        tx = ((p.dx / s.width) - .5) * 2;
        ty = ((p.dy / s.height) - .5) * 2;
        tx = tx.clamp(-1.0, 1.0);
        ty = ty.clamp(-1.0, 1.0);
      });

  @override
  Widget build(BuildContext context) {
    final baseX = widget.flat ? 0.0 : 8 - ty * 12;
    final baseY = widget.flat ? 0.0 : -12 + tx * 18 + (widget.flipped ? 180 : 0);
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, widget.stageHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.tapToFlip ? null : widget.onFlip,
        onTap: widget.tapToFlip ? widget.onFlip : null,
        child: Listener(
          onPointerHover: (e) => _move(e.localPosition, size),
          onPointerMove: (e) => _move(e.localPosition, size),
          onPointerDown: (e) => _startY = e.position.dy,
          onPointerUp: (e) {
            if (_startY != null) {
              final d = e.position.dy - _startY!;
              if (d.abs() > 60) widget.onSwipe?.call(d < 0 ? 1 : -1);
            }
            _startY = null;
            setState(() => tx = ty = 0);
          },
          onPointerCancel: (_) => setState(() => tx = ty = 0),
          child: SizedBox(
            height: widget.stageHeight,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _in,
              builder: (_, child) {
                final v = Curves.easeOutBack.transform(_in.value.clamp(0.0, 1.0));
                final o = Curves.easeOut.transform((_in.value * 2).clamp(0.0, 1.0));
                return Opacity(
                  opacity: o,
                  child: Transform.translate(offset: Offset(0, 60 * (1 - v)), child: _stage(baseX + 40 * (1 - v), baseY)),
                );
              },
            ),
          ),
        ),
      );
    });
  }

  Widget _stage(double rx, double ry) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: Offset(rx, ry), end: Offset(rx, ry)),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) {
        final radY = v.dy * math.pi / 180;
        final showFront = math.cos(radY) >= 0;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 1 / 1200)
          ..rotateX(v.dx * math.pi / 180)
          ..rotateY(radY);
        return Stack(children: [
          Positioned(
            top: widget.cardTop,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: widget.cardWidth,
                child: Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: showFront
                      ? widget.front(tx, ty)
                      : Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: widget.back),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
