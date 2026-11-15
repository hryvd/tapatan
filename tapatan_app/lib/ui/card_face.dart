import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/lucide_icons.dart';
import 'tokens.dart';

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

/// EMV chip 44x32: flat layered gold plating with contact-pad lines (no glow).
class CardChip extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const CardChip({super.key, this.margin});
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 32,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFFB8892B), // outer plating edge
          border: Border.all(color: const Color(0xFF7A5A14), width: .6),
        ),
        child: CustomPaint(painter: _ChipLines()),
      );
}

class _ChipLines extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // inner gold plate
    final plate = RRect.fromRectAndRadius(Rect.fromLTWH(1.6, 1.6, w - 3.2, h - 3.2), const Radius.circular(4.5));
    c.drawRRect(plate, Paint()..color = const Color(0xFFD9AE45));
    // contact pads (flat, slightly different gold tones)
    final padA = Paint()..color = const Color(0xFFE6C063);
    final padB = Paint()..color = const Color(0xFFCFA03A);
    final x1 = w * .34, x2 = w * .66, y1 = h * .36, y2 = h * .64;
    final gap = 1.3;
    RRect pad(double l, double t, double r, double b) => RRect.fromLTRBR(l, t, r, b, const Radius.circular(1.6));
    c.drawRRect(pad(5, 5, x1 - gap, y1 - gap), padA);
    c.drawRRect(pad(5, y2 + gap, x1 - gap, h - 5), padB);
    c.drawRRect(pad(x2 + gap, 5, w - 5, y1 - gap), padB);
    c.drawRRect(pad(x2 + gap, y2 + gap, w - 5, h - 5), padA);
    c.drawRRect(pad(x1 + gap, 5, x2 - gap, h - 5), padB);
    c.drawRRect(pad(5, y1 + gap, x1 - gap, y2 - gap), padB);
    c.drawRRect(pad(x2 + gap, y1 + gap, w - 5, y2 - gap), padA);
    // center contact
    c.drawRRect(pad(x1 + gap + 1.5, y1 + gap + .5, x2 - gap - 1.5, y2 - gap - .5), Paint()..color = const Color(0xFFE2BA55));
    // etched separator lines
    final line = Paint()
      ..color = const Color(0xFF7A5A14).withValues(alpha: .75)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    c.drawLine(Offset(x1, 1.6), Offset(x1, y1), line);
    c.drawLine(Offset(x2, 1.6), Offset(x2, y1), line);
    c.drawLine(Offset(x1, y2), Offset(x1, h - 1.6), line);
    c.drawLine(Offset(x2, y2), Offset(x2, h - 1.6), line);
    c.drawLine(Offset(1.6, y1), Offset(x1, y1), line);
    c.drawLine(Offset(1.6, y2), Offset(x1, y2), line);
    c.drawLine(Offset(x2, y1), Offset(w - 1.6, y1), line);
    c.drawLine(Offset(x2, y2), Offset(w - 1.6, y2), line);
    c.drawRRect(RRect.fromLTRBR(x1, y1, x2, y2, const Radius.circular(2)), line);
    c.drawRRect(plate, line..strokeWidth = .6);
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
    final sub = card.physical ? 'JCOP4 J3R150' : card.kind == 'bank' ? (card.bank ?? 'BANK').toUpperCase() : 'VIRTUAL';
    return AspectRatio(
      aspectRatio: kCardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: Stack(fit: StackFit.expand, children: [
          _materialBg(m),
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
                  Text(card.network.split(' ').first.toUpperCase(), style: T.text(10, w: T.w700, color: txt.withValues(alpha: .8))),
                ]),
              ]),
            ),
          ),
          if (frozen)
            ColoredBox(
              color: const Color.fromRGBO(224, 242, 254, .30),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: T.white(.3), border: Border.all(color: T.white(.6))),
                  child: const Icon(LucideIcons.lock, size: 20, color: Colors.white),
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rCard), border: Border.all(color: T.white(.2))),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Interactive 3D stage: pointer tilt, optional gyroscope/accelerometer tilt, flip (double-tap, or
/// single tap if [tapToFlip]), vertical swipe → [onSwipe] (±1), horizontal swipe → [onSwipeHorizontal] (±1).
/// Only the Transform is rebuilt per frame (ValueNotifiers + AnimatedBuilder); front/back are built once.
/// Set [interactive] false for a static front-facing card (no tilt, flip, gestures or sensors).
class Card3D extends StatefulWidget {
  final Widget Function(double tiltX, double tiltY) front;
  final Widget back;
  final bool flipped;
  final VoidCallback? onFlip;
  final ValueChanged<int>? onSwipe;
  final ValueChanged<int>? onSwipeHorizontal;
  final bool flat; // X-ray mode: no tilt/flip (rotX=rotY=0)
  final bool tapToFlip;
  final bool interactive;
  final bool gyro; // follow phone orientation (accelerometer gravity tilt, low-pass filtered)
  final double cardWidth;
  final double stageHeight;
  final double cardTop;
  final Offset enterFrom;
  const Card3D({
    super.key,
    required this.front,
    required this.back,
    this.flipped = false,
    this.onFlip,
    this.onSwipe,
    this.onSwipeHorizontal,
    this.flat = false,
    this.tapToFlip = false,
    this.interactive = true,
    this.gyro = false,
    this.cardWidth = 290,
    this.stageHeight = 270,
    this.cardTop = 44,
    this.enterFrom = const Offset(0, 20),
  });
  @override
  State<Card3D> createState() => _Card3DState();
}

class _Card3DState extends State<Card3D> with TickerProviderStateMixin {
  static const _maxTilt = 0.35;
  final ValueNotifier<Offset> _touch = ValueNotifier(Offset.zero); // normalized -1..1
  final ValueNotifier<Offset> _gyro = ValueNotifier(Offset.zero); // radians (rx, ry)
  Offset _relFrom = Offset.zero;
  StreamSubscription<AccelerometerEvent>? _sub;
  bool _sensorOk = false;
  bool _holding = false;
  bool _holdSwiped = false;
  Offset _holdStartPos = Offset.zero;
  double _hDragDx = 0;

  late final AnimationController _in;
  late final AnimationController _flip;
  late final AnimationController _rel;

  bool get _static => widget.flat || !widget.interactive;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
    _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: widget.flipped ? 1 : 0);
    _rel = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() => _touch.value = Offset.lerp(_relFrom, Offset.zero, Curves.easeOut.transform(_rel.value))!);
    if (widget.gyro && !_static) _startSensor();
  }

  void _startSensor() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _sensorOk = true;
        final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (g < 1) return;
        final roll = math.asin((e.x / g).clamp(-1.0, 1.0)); // left/right lean
        final pitch = math.atan2(e.z, e.y) - 0.75; // relative to a comfortable reading angle
        final tx = pitch.clamp(-_maxTilt, _maxTilt).toDouble();
        final ty = roll.clamp(-_maxTilt, _maxTilt).toDouble();
        const a = 0.18; // responsive low-pass
        final c = _gyro.value;
        _gyro.value = Offset(c.dx + (tx - c.dx) * a, c.dy + (ty - c.dy) * a);
      }, onError: (Object _) {
        _sensorOk = false;
        _sub?.cancel();
        _sub = null;
      }, cancelOnError: true);
    } catch (_) {
      _sensorOk = false;
    }
  }

  void _stopSensor() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void didUpdateWidget(Card3D old) {
    super.didUpdateWidget(old);
    if (old.flipped != widget.flipped) widget.flipped ? _flip.forward() : _flip.reverse();
    if (old.gyro != widget.gyro || old.flat != widget.flat || old.interactive != widget.interactive) {
      if (widget.gyro && !_static) {
        _startSensor();
      } else {
        _stopSensor();
      }
    }
  }

  @override
  void dispose() {
    _stopSensor();
    _in.dispose();
    _flip.dispose();
    _rel.dispose();
    _touch.dispose();
    _gyro.dispose();
    super.dispose();
  }

  void _move(Offset p, Size s) {
    _rel.stop();
    _touch.value = Offset(((p.dx / s.width) - .5).clamp(-.5, .5) * 2, ((p.dy / s.height) - .5).clamp(-.5, .5) * 2);
  }

  void _release() {
    _relFrom = _touch.value;
    _rel.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final front = widget.front(0, 0);
    final stage = SizedBox(
      height: widget.stageHeight,
      width: double.infinity,
      child: RepaintBoundary(
        child: Stack(children: [
          Positioned(
            top: widget.cardTop,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: widget.cardWidth,
                child: _static ? front : _animated(front),
              ),
            ),
          ),
        ]),
      ),
    );
    if (!widget.interactive) return stage;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, widget.stageHeight);
      final gestures = <Type, GestureRecognizerFactory>{
        if (!widget.flat && widget.onFlip != null && widget.tapToFlip)
          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            (r) => r.onTap = widget.onFlip,
          ),
        if (!widget.flat && widget.onFlip != null && !widget.tapToFlip)
          DoubleTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
            () => DoubleTapGestureRecognizer(),
            (r) => r.onDoubleTap = widget.onFlip,
          ),
        if (widget.onSwipeHorizontal != null)
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(),
            (r) => r
              ..onStart = (_) {
                _hDragDx = 0;
              }
              ..onUpdate = (d) {
                _hDragDx += d.delta.dx;
              }
              ..onEnd = (d) {
                final vx = d.velocity.pixelsPerSecond.dx;
                if (_hDragDx.abs() > 42 || vx.abs() > 160) {
                  final dir = (_hDragDx != 0 ? _hDragDx : vx) < 0 ? 1 : -1;
                  widget.onSwipeHorizontal?.call(dir);
                }
                _hDragDx = 0;
                _release();
              }
              ..onCancel = () {
                _hDragDx = 0;
                _release();
              },
          ),
        if (widget.onSwipe != null)
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 220)),
            (r) => r
              ..onLongPressStart = (d) {
                _holding = true;
                _holdSwiped = false;
                _holdStartPos = d.globalPosition;
                HapticFeedback.selectionClick();
              }
              ..onLongPressMoveUpdate = (d) {
                if (!_holding) return;
                _move(d.localPosition, size);
                final dy = d.offsetFromOrigin.dy;
                if (!_holdSwiped && dy.abs() > 36) {
                  _holdSwiped = true;
                  widget.onSwipe?.call(dy < 0 ? 1 : -1);
                }
              }
              ..onLongPressEnd = (d) {
                final dy = d.globalPosition.dy - _holdStartPos.dy;
                if (_holding && !_holdSwiped && dy.abs() > 36) {
                  widget.onSwipe?.call(dy < 0 ? 1 : -1);
                }
                _holding = false;
                _holdSwiped = false;
                _release();
              }
              ..onLongPressCancel = () {
                _holding = false;
                _holdSwiped = false;
                _release();
              },
          ),
      };
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (e) => _move(e.localPosition, size),
        onPointerMove: (e) => _move(e.localPosition, size),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: gestures,
          child: stage,
        ),
      );
    });
  }

  Widget _animated(Widget front) {
    final back = Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: widget.back);
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _flip, _touch, _gyro]),
      builder: (_, _) {
        final t = _touch.value;
        final g = _gyro.value;
        final v = Curves.easeOutCubic.transform(_in.value);
        final flip = Curves.easeInOut.transform(_flip.value);
        final rx = (_sensorOk ? 0.0 : 8 * math.pi / 180) - t.dy * 0.21 + g.dx + (1 - v) * 0.35;
        final ry = (_sensorOk ? 0.0 : -12 * math.pi / 180) + t.dx * 0.31 + g.dy + flip * math.pi;
        final showFront = math.cos(ry) >= 0;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 1 / 1200)
          ..rotateX(rx)
          ..rotateY(ry);
        final s = (0.88 + 0.12 * v);
        return Transform.translate(
          offset: Offset(widget.enterFrom.dx * (1 - v), widget.enterFrom.dy * (1 - v)),
          child: Transform.scale(
            scale: s,
            child: Transform(alignment: Alignment.center, transform: m, child: showFront ? front : back),
          ),
        );
      },
    );
  }
}
