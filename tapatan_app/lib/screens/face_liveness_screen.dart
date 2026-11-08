import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/lucide_icons.dart';

/// A full-screen face liveness detection widget.
/// Uses the front camera + ML Kit face detector.
/// Calls [onLivenessConfirmed] when liveness is verified, or
/// pops the navigator with null if cancelled.
class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

enum _LivenessStep { detecting, blinkCheck, smileCheck, done }

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  _LivenessStep _step = _LivenessStep.detecting;
  double _progress = 0.0;
  String _instruction = 'Position your face in the oval';
  String _subInstruction = 'Keep your face centered and steady';

  // ML Kit face detector
  late final FaceDetector _faceDetector;

  // Timers and counters for liveness checks
  int _faceDetectedFrames = 0;
  bool _blinkDetected = false;
  bool _smileDetected = false;
  Timer? _livenessTimer;
  bool _streamActive = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // for blink & smile probability
        enableLandmarks: false,
        enableContours: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available.');
        return;
      }

      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
        _startFaceStream();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _startFaceStream() {
    if (_controller == null || _streamActive) return;
    _streamActive = true;

    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing || _step == _LivenessStep.done) return;
      _isProcessing = true;

      try {
        final inputImage = _buildInputImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final faces = await _faceDetector.processImage(inputImage);
        if (!mounted) {
          _isProcessing = false;
          return;
        }

        if (faces.isNotEmpty) {
          final face = faces.first;
          _onFaceDetected(face);
        } else {
          // No face — reset detection counter
          if (_step == _LivenessStep.detecting) {
            _faceDetectedFrames = 0;
            if (mounted) {
              setState(() {
                _instruction = 'Position your face in the oval';
                _subInstruction = 'Keep your face centered and steady';
                _progress = 0.0;
              });
            }
          }
        }
      } catch (_) {
        // Ignore individual frame errors
      } finally {
        _isProcessing = false;
      }
    });
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _onFaceDetected(Face face) {
    switch (_step) {
      case _LivenessStep.detecting:
        _faceDetectedFrames++;
        final progress = (_faceDetectedFrames / 20).clamp(0.0, 1.0);
        if (mounted) {
          setState(() {
            _progress = progress;
            _instruction = 'Face detected — hold steady';
            _subInstruction = 'Analyzing biometrics...';
          });
        }
        if (_faceDetectedFrames >= 20) {
          if (mounted) {
            setState(() {
              _step = _LivenessStep.blinkCheck;
              _instruction = 'Blink your eyes';
              _subInstruction = 'Slowly blink both eyes once';
              _progress = 0.33;
            });
          }
        }
        break;

      case _LivenessStep.blinkCheck:
        // ML Kit returns leftEyeOpenProbability (0=closed, 1=open)
        final leftOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightOpen = face.rightEyeOpenProbability ?? 1.0;
        if (leftOpen < 0.2 && rightOpen < 0.2) {
          _blinkDetected = true;
        }
        if (_blinkDetected) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && _step == _LivenessStep.blinkCheck) {
              setState(() {
                _step = _LivenessStep.smileCheck;
                _instruction = 'Now smile 😊';
                _subInstruction = 'Give a natural smile';
                _progress = 0.66;
              });
            }
          });
        }
        break;

      case _LivenessStep.smileCheck:
        final smilingProb = face.smilingProbability ?? 0.0;
        if (smilingProb > 0.75) {
          _smileDetected = true;
        }
        if (_smileDetected) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _step == _LivenessStep.smileCheck) {
              setState(() {
                _step = _LivenessStep.done;
                _instruction = 'Liveness Confirmed ✓';
                _subInstruction = 'Identity verified successfully';
                _progress = 1.0;
              });
              _stopStreamAndReturn();
            }
          });
        }
        break;

      case _LivenessStep.done:
        break;
    }
  }

  Future<void> _stopStreamAndReturn() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    _faceDetector.close();
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  Color get _frameColor {
    switch (_step) {
      case _LivenessStep.detecting:
        return const Color(0xFF0891B2);
      case _LivenessStep.blinkCheck:
        return const Color(0xFFF59E0B);
      case _LivenessStep.smileCheck:
        return const Color(0xFF8B5CF6);
      case _LivenessStep.done:
        return const Color(0xFF10B981);
    }
  }

  IconData get _stepIcon {
    switch (_step) {
      case _LivenessStep.detecting:
        return LucideIcons.scanFace;
      case _LivenessStep.blinkCheck:
        return LucideIcons.eye;
      case _LivenessStep.smileCheck:
        return LucideIcons.smile;
      case _LivenessStep.done:
        return LucideIcons.checkCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else if (_errorMessage != null)
            _buildError()
          else
            _buildLoading(),

          // Dark overlay with oval cutout
          if (_isInitialized) _buildOvalOverlay(context),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child:
                          const Icon(LucideIcons.x, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Face Liveness Check',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'On-device • No data sent to servers',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: _buildInstructionCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvalOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameW = size.width * 0.68;
    final frameH = size.width * 0.85;
    final centerY = size.height * 0.40;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        return CustomPaint(
          painter: _OvalOverlayPainter(
            frameWidth: frameW,
            frameHeight: frameH,
            centerY: centerY,
            borderColor: _frameColor,
            glowOpacity: _glowAnim.value,
          ),
        );
      },
    );
  }

  Widget _buildInstructionCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _frameColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _frameColor.withOpacity(0.25),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = _progress > (i / 3);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: filled ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: filled ? _frameColor : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Icon + progress
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _step != _LivenessStep.done ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _frameColor.withOpacity(0.15),
                    border: Border.all(color: _frameColor.withOpacity(0.4)),
                  ),
                  child: Icon(_stepIcon, color: _frameColor, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _instruction,
                        key: ValueKey(_instruction),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subInstruction,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 6,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_frameColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: const Color(0xFF020B18),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0891B2)),
            SizedBox(height: 16),
            Text('Starting camera...',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF020B18),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera unavailable',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Go Back',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Oval Overlay Painter ─────────────────────────────────────────────────

class _OvalOverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final double centerY;
  final Color borderColor;
  final double glowOpacity;

  _OvalOverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
    required this.centerY,
    required this.borderColor,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - frameWidth) / 2;
    final top = centerY - frameHeight / 2;
    final rect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawOval(rect, clearPaint);
    canvas.restore();

    // Glowing oval border
    final borderPaint = Paint()
      ..color = borderColor.withOpacity(0.6 + glowOpacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glowOpacity);
    canvas.drawOval(rect, borderPaint);

    // Solid border on top
    final solidPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(rect, solidPaint);
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter old) =>
      old.borderColor != borderColor || old.glowOpacity != glowOpacity;
}
