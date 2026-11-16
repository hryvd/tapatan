import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/id_document_analyzer.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

Future<String> _cropImage(Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final screenW = params['screenW'] as double;
  final screenH = params['screenH'] as double;
  final cropX = params['cropX'] as double;
  final cropY = params['cropY'] as double;
  final cropW = params['cropW'] as double;
  final cropH = params['cropH'] as double;

  final bytes = await File(path).readAsBytes();
  var original = img.decodeImage(bytes);
  if (original == null) return path;

  // Bake EXIF orientation so width & height match portrait layout seen on screen
  original = img.bakeOrientation(original);

  final double imgW = original.width.toDouble();
  final double imgH = original.height.toDouble();

  final double displayScale = math.max(screenW / imgW, screenH / imgH);
  final double displayOffsetX = (screenW - imgW * displayScale) / 2.0;
  final double displayOffsetY = (screenH - imgH * displayScale) / 2.0;

  final int x =
      ((cropX - displayOffsetX) / displayScale).round().clamp(0, original.width - 1);
  final int y =
      ((cropY - displayOffsetY) / displayScale).round().clamp(0, original.height - 1);
  final int w = (cropW / displayScale).round().clamp(1, original.width - x);
  final int h = (cropH / displayScale).round().clamp(1, original.height - y);

  final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
  final newBytes = img.encodeJpg(cropped, quality: 92);

  final newPath = path.replaceFirst(RegExp(r'\.jpe?g$'), '_cropped.jpg');
  final finalPath = newPath == path ? '${path}_cropped.jpg' : newPath;
  await File(finalPath).writeAsBytes(newBytes);
  return finalPath;
}

typedef IdAnalyzerFn = Future<IdDocumentAnalysis> Function(String imagePath);

/// Full-screen camera capture overlay for ID document scanning.
/// Keeps the ID cutout unobstructed with controls/status placed cleanly below,
/// and verifies both picture quality and ID document presence before accepting.
class CameraCaptureOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isOval;
  final IdAnalyzerFn? analyzer;

  const CameraCaptureOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    this.isOval = false,
    this.analyzer,
  });

  /// Computes the unobstructed scan cutout rect above the bottom overlay dock
  /// and below the top header chrome.
  static Rect computeScanRect(
    Size size,
    EdgeInsets padding, {
    bool isOval = false,
  }) {
    final topLimit = padding.top + 82.0;
    final bottomReserve = padding.bottom + (isOval ? 196.0 : 226.0);
    final bottomLimit = math.max(topLimit + 130.0, size.height - bottomReserve);
    final availH = math.max(120.0, bottomLimit - topLimit);

    double frameW = isOval ? size.width * 0.65 : size.width * 0.88;
    double frameH = isOval ? size.width * 0.80 : frameW / 1.586;

    if (frameH > availH - 16.0) {
      frameH = math.max(100.0, availH - 16.0);
      if (!isOval) {
        frameW = math.min(size.width * 0.88, frameH * 1.586);
      } else {
        frameW = math.min(size.width * 0.68, frameH * 0.8125);
      }
    }

    final centerY = topLimit + availH / 2.0;
    return Rect.fromCenter(
      center: Offset(size.width / 2.0, centerY),
      width: frameW,
      height: frameH,
    );
  }

  @override
  State<CameraCaptureOverlay> createState() => _CameraCaptureOverlayState();
}

class _CameraCaptureOverlayState extends State<CameraCaptureOverlay>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  String? _capturedPath;
  IdDocumentAnalysis? _analysis;
  String? _errorMessage;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No cameras found on this device.');
        }
        return;
      }

      final description = widget.isOval
          ? (_cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            ))
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            );

      Future<CameraController> createAndInit(ResolutionPreset preset) async {
        final ctrl = CameraController(
          description,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await ctrl.initialize();
        return ctrl;
      }

      CameraController controller;
      try {
        controller = await createAndInit(
          widget.isOval ? ResolutionPreset.medium : ResolutionPreset.high,
        );
      } catch (_) {
        controller = await createAndInit(ResolutionPreset.medium);
      }

      if (_disposed) {
        await controller.dispose();
        return;
      }

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera error: ${e.toString()}');
      }
    }
  }

  Future<void> _focusAtPoint(TapDownDetails details, Size screenSize) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final dx = (details.globalPosition.dx / screenSize.width).clamp(0.0, 1.0);
    final dy = (details.globalPosition.dy / screenSize.height).clamp(0.0, 1.0);
    try {
      await ctrl.setFocusPoint(Offset(dx, dy));
    } catch (_) {}
  }

  void _discardCapturedFile() {
    final old = _capturedPath;
    if (old != null && old.isNotEmpty) {
      try {
        final f = File(old);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _retake() async {
    _discardCapturedFile();
    if (!mounted) return;
    setState(() {
      _capturedPath = null;
      _analysis = null;
      _isAnalyzing = false;
      _isCapturing = false;
    });
  }

  Future<void> _capture(Rect scanRect, Size screenSize) async {
    if (_controller == null ||
        !_isInitialized ||
        _isCapturing ||
        _isAnalyzing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _analysis = null;
    });

    try {
      final file = await _controller!.takePicture();

      final croppedPath = await compute(_cropImage, {
        'path': file.path,
        'screenW': screenSize.width,
        'screenH': screenSize.height,
        'cropX': scanRect.left,
        'cropY': scanRect.top,
        'cropW': scanRect.width,
        'cropH': scanRect.height,
      });

      if (!mounted) return;

      if (widget.isOval) {
        Navigator.of(context).pop(croppedPath);
        return;
      }

      setState(() {
        _isCapturing = false;
        _isAnalyzing = true;
        _capturedPath = croppedPath;
      });

      final analyzeFn = widget.analyzer ?? IdDocumentAnalyzer.analyzeFile;
      final analysis = await analyzeFn(croppedPath);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysis = analysis;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAnalyzing = false;
        });
        showToast(context, 'Capture failed: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scanLineController.dispose();
    final ctrl = _controller;
    _controller = null;
    try {
      ctrl?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scanRect = CameraCaptureOverlay.computeScanRect(
      media.size,
      media.padding,
      isOval: widget.isOval,
    );

    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && _controller != null)
            _buildCameraPreview(context)
          else if (_errorMessage != null)
            _buildErrorState()
          else
            _buildLoadingState(),

          // Captured ID crop preview sits cleanly inside the scan frame while analyzing/reviewing
          if (_capturedPath != null && _capturedPath!.isNotEmpty)
            Positioned.fromRect(
              rect: scanRect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_capturedPath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Translucent mask & frame outline (only over preview/frozen shot)
          if (_isInitialized || _capturedPath != null)
            _buildOverlay(scanRect, media.size),

          // Tap inside scan frame to focus camera
          if (_isInitialized && _capturedPath == null)
            Positioned.fromRect(
              rect: scanRect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (d) => _focusAtPoint(d, media.size),
              ),
            ),

          // Top navigation bar placed cleanly above the scan area
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Glass(
                      kind: GlassKind.strong,
                      radius: 999,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title, style: T.text(14, w: T.w700)),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: PressScale(
                        onTap: () {
                          _discardCapturedFile();
                          Navigator.of(context).pop(null);
                        },
                        child: const Glass(
                          kind: GlassKind.strong,
                          radius: 999,
                          width: 42,
                          height: 42,
                          child: Icon(
                            LucideIcons.x,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom overlay dock positioned strictly BELOW the scan area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('id-scan-bottom-overlay'),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildBottomOverlayContent(scanRect, media.size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlayContent(Rect scanRect, Size screenSize) {
    if (_errorMessage != null) return const SizedBox.shrink();

    if (!_isInitialized && _capturedPath == null) {
      return Glass(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: T.teal),
            ),
            const SizedBox(width: 10),
            Text(
              'Preparing ID scanner...',
              style: T.text(12.5, color: T.white(.75)),
            ),
          ],
        ),
      );
    }

    if (_isAnalyzing) {
      return Glass(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: T.teal),
            ),
            const SizedBox(height: 10),
            Text(
              'Checking photo quality & ID document...',
              style: T.text(13, w: T.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Inspecting lighting, sharpness, ID text, and photo',
              style: T.text(11, color: T.white(.60)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final analysis = _analysis;
    if (_capturedPath != null && analysis != null) {
      final goodPic = analysis.quality.isGoodPicture;
      final goodId = analysis.isValidId;
      final accepted = analysis.isAccepted;

      return Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statusPill(
                  ok: goodPic,
                  label: goodPic ? 'Good photo' : 'Improve photo',
                ),
                const SizedBox(width: 8),
                _statusPill(
                  ok: goodId,
                  label: goodId ? 'ID recognized' : 'ID not verified',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              accepted
                  ? analysis.summary
                  : (analysis.failureReason ?? 'Please retake ID photo'),
              style: T.text(
                12.5,
                w: T.w600,
                color: accepted ? T.emerald300 : T.amber300,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            if (accepted)
              Row(
                children: [
                  Expanded(
                    child: PressScale(
                      onTap: _retake,
                      child: Glass(
                        kind: GlassKind.strong,
                        radius: T.rBtn,
                        height: T.btnH,
                        child: Center(
                          child: Text(
                            'Retake',
                            style: T.text(14, w: T.w700, color: T.white(.9)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Btn.text(
                      'Use ID Photo',
                      width: double.infinity,
                      onTap: () => Navigator.of(context).pop(_capturedPath),
                    ),
                  ),
                ],
              )
            else
              Btn.text(
                'Retake Photo',
                width: double.infinity,
                onTap: _retake,
              ),
          ],
        ),
      );
    }

    // Live preview controls dock strictly below scan frame
    return Glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isOval
                ? 'Center your face inside the frame'
                : 'Align full ID inside the frame · Tap frame to focus',
            style: T.text(12.5, w: T.w600, color: T.white(.90)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Checks lighting, sharpness, and valid ID document',
            style: T.text(11, color: T.white(.58)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _capture(scanRect, screenSize),
            child: AnimatedScale(
              scale: _isCapturing ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.teal,
                ),
                child: _isCapturing
                    ? const Padding(
                        padding: EdgeInsets.all(19),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        LucideIcons.camera,
                        color: Colors.white,
                        size: 27,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({required bool ok, required String label}) {
    final tone = ok ? T.emerald300 : T.amber300;
    return Glass(
      kind: GlassKind.pill,
      fill: T.op(ok ? T.emerald : T.amber500, .20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? LucideIcons.check : LucideIcons.alertCircle,
            size: 13,
            color: tone,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: T.text(11.5, w: T.w700, color: tone),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext context) {
    final previewSize = _controller?.value.previewSize;
    if (previewSize == null) {
      return Center(child: CameraPreview(_controller!));
    }

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final double camW = isPortrait ? previewSize.height : previewSize.width;
    final double camH = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: camW,
            height: camH,
            child: CameraPreview(_controller!),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(Rect scanRect, Size size) {
    final analysis = _analysis;
    final frameTone = analysis == null
        ? T.teal
        : (analysis.isAccepted ? T.emerald400 : T.amber300);

    return CustomPaint(
      painter: _OverlayPainter(
        scanRect: scanRect,
        isOval: widget.isOval,
        frameColor: frameTone,
      ),
      child: Stack(
        children: [
          if (_capturedPath == null)
            AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, _) {
                final top = scanRect.top + (scanRect.height * _scanLineAnim.value);
                return Positioned(
                  top: top,
                  left: scanRect.left + 6,
                  child: Container(
                    width: scanRect.width - 12,
                    height: 2,
                    color: T.op(T.teal, 0.85),
                  ),
                );
              },
            ),
          if (!widget.isOval)
            ..._buildCornerMarkers(scanRect, frameTone),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers(Rect scanRect, Color color) {
    const len = 24.0;
    const thick = 3.0;

    Widget corner(double x, double y, bool flipH, bool flipV) {
      return Positioned(
        left: x,
        top: y,
        child: Transform.scale(
          scaleX: flipH ? -1.0 : 1.0,
          scaleY: flipV ? -1.0 : 1.0,
          child: SizedBox(
            width: len,
            height: len,
            child: CustomPaint(
              painter: _CornerMarkerPainter(color: color, thick: thick),
            ),
          ),
        ),
      );
    }

    return [
      corner(scanRect.left, scanRect.top, false, false),
      corner(scanRect.right - len, scanRect.top, true, false),
      corner(scanRect.left, scanRect.bottom - len, false, true),
      corner(scanRect.right - len, scanRect.bottom - len, true, true),
    ];
  }

  Widget _buildLoadingState() {
    return Container(
      color: T.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: T.teal),
            const SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: T.text(14, color: T.white(.55)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: T.bg,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff, color: T.red400, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera unavailable',
              style: T.text(14, color: T.white(.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Btn.text(
              'Go Back',
              width: 160,
              onTap: () {
                _discardCapturedFile();
                Navigator.of(context).pop(null);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  final bool isOval;
  final Color frameColor;

  _OverlayPainter({
    required this.scanRect,
    required this.isOval,
    required this.frameColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = T.blk(.62);
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path();
    if (isOval) {
      hole.addOval(scanRect);
    } else {
      hole.addRRect(
          RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));
    }
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, hole),
      dimPaint,
    );

    if (isOval) {
      final borderPaint = Paint()
        ..color = T.op(frameColor, .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawOval(scanRect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.scanRect != scanRect ||
      old.isOval != isOval ||
      old.frameColor != frameColor;
}

class _CornerMarkerPainter extends CustomPainter {
  final Color color;
  final double thick;

  _CornerMarkerPainter({required this.color, required this.thick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerMarkerPainter old) => old.color != color;
}
