import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

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

  // Assume the camera preview fills the screen (simple ratio scaling)
  final scaleX = original.width / screenW;
  final scaleY = original.height / screenH;

  final x = (cropX * scaleX).toInt().clamp(0, original.width);
  final y = (cropY * scaleY).toInt().clamp(0, original.height);
  final w = (cropW * scaleX).toInt().clamp(0, original.width - x);
  final h = (cropH * scaleY).toInt().clamp(0, original.height - y);

  final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
  final newBytes = img.encodeJpg(cropped, quality: 85);

  final newPath = path.replaceFirst(RegExp(r'\.jpg|\.jpeg'), '_cropped.jpg');
  await File(newPath).writeAsBytes(newBytes);
  return newPath;
}

/// A full-screen camera capture screen for ID document scanning.
/// Returns the captured image file path via [Navigator.pop], or null if cancelled.
class CameraCaptureOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isOval; // true for face, false for document (rectangle)

  const CameraCaptureOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    this.isOval = false,
  });

  @override
  State<CameraCaptureOverlay> createState() => _CameraCaptureOverlayState();
}

class _CameraCaptureOverlayState extends State<CameraCaptureOverlay>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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

      // Face mode uses front camera; ID scan uses back camera
      final description = widget.isOval
          ? (_cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            ))
          : _cameras.first;

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

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

  Future<void> _capture() async {
    if (_controller == null || !_isInitialized || _isCapturing) return;

    final size = MediaQuery.of(context).size;
    final frameW = widget.isOval ? size.width * 0.65 : size.width * 0.85;
    final frameH = widget.isOval ? size.width * 0.8 : size.width * 0.58;
    final centerY = size.height * 0.42;

    final left = (size.width - frameW) / 2;
    final top = centerY - frameH / 2;

    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();

      final croppedPath = await compute(_cropImage, {
        'path': file.path,
        'screenW': size.width,
        'screenH': size.height,
        'cropX': left,
        'cropY': top,
        'cropW': frameW,
        'cropH': frameH,
      });

      if (!mounted) return;
      Navigator.of(context).pop(croppedPath);
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        showToast(context, 'Capture failed: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else if (_errorMessage != null)
            _buildErrorState()
          else
            _buildLoadingState(),

          // Dark liquid-glass overlay with cutout
          if (_isInitialized) _buildOverlay(context),

          // Top navigation bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GlassIconBtn(
                    icon: LucideIcons.x,
                    size: 40,
                    iconSize: 18,
                    onTap: () => Navigator.of(context).pop(null),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: T.text(16, w: T.w800)),
                        Text(widget.subtitle, style: T.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom capture button
          if (_isInitialized)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: GestureDetector(
                    onTap: _capture,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _isCapturing ? 0.92 : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: T.btnLiquidGradient,
                          border: Border.all(color: T.white(.6), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: T.cyan500.withValues(
                                alpha: 0.5 * _pulseAnim.value,
                              ),
                              blurRadius: 26,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                LucideIcons.camera,
                                color: T.slate900,
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameW = widget.isOval ? size.width * 0.65 : size.width * 0.85;
    final frameH = widget.isOval ? size.width * 0.8 : size.width * 0.58;
    final centerY = size.height * 0.42;

    return CustomPaint(
      painter: _OverlayPainter(
        frameWidth: frameW,
        frameHeight: frameH,
        centerY: centerY,
        isOval: widget.isOval,
        scanLineProgress: _scanLineAnim.value,
      ),
      child: Stack(
        children: [
          // Scanning line animation
          AnimatedBuilder(
            animation: _scanLineAnim,
            builder: (_, _) {
              final top = (centerY - frameH / 2) + (frameH * _scanLineAnim.value);
              final left = (size.width - frameW) / 2 + 4;
              return Positioned(
                top: top,
                left: left,
                child: Container(
                  width: frameW - 8,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        T.cyan400.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Corner markers (only for rectangle)
          if (!widget.isOval) ..._buildCornerMarkers(size, frameW, frameH, centerY),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers(
      Size size, double frameW, double frameH, double centerY) {
    final left = (size.width - frameW) / 2;
    final top = centerY - frameH / 2;
    const len = 24.0;
    const thick = 3.0;
    const color = T.cyan400;

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
      corner(left, top, false, false),
      corner(left + frameW - len, top, true, false),
      corner(left, top + frameH - len, false, true),
      corner(left + frameW - len, top + frameH - len, true, true),
    ];
  }

  Widget _buildLoadingState() {
    return Container(
      color: T.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: T.cyan400),
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
              variant: BtnVariant.glass,
              onTap: () => Navigator.of(context).pop(null),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overlay Painter ──────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final double centerY;
  final bool isOval;
  final double scanLineProgress;

  _OverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
    required this.centerY,
    required this.isOval,
    required this.scanLineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = T.blk(.65);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    final left = (size.width - frameWidth) / 2;
    final top = centerY - frameHeight / 2;
    final rect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);

    if (isOval) {
      canvas.drawOval(rect, clearPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        clearPaint,
      );
    }

    canvas.restore();

    // Frame border
    final borderPaint = Paint()
      ..color = T.cyan400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (isOval) {
      canvas.drawOval(rect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.scanLineProgress != scanLineProgress;
}

// ─── Corner Marker Painter ────────────────────────────────────────────────

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
