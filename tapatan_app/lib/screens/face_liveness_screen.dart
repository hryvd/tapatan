import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

/// A full-screen face liveness detection widget.
/// Uses the front camera + ML Kit face detector.
/// Calls [Navigator.pop(true)] when liveness is verified, or
/// pops with null if cancelled.
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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No cameras available.');
        }
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
      if (mounted) {
        setState(() => _errorMessage = 'Camera error: $e');
      }
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
    if (_streamActive && (_controller?.value.isStreamingImages ?? false)) {
      try {
        _controller?.stopImageStream();
      } catch (_) {}
    }
    _controller?.dispose();
    super.dispose();
  }

  Color get _frameColor {
    switch (_step) {
      case _LivenessStep.detecting:
        return T.cyan400;
      case _LivenessStep.blinkCheck:
        return T.amber500;
      case _LivenessStep.smileCheck:
        return T.indigo500;
      case _LivenessStep.done:
        return T.emerald400;
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
      backgroundColor: T.bg,
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
                        Text('Face Liveness Check',
                            style: T.text(16, w: T.w800)),
                        Text('On-device · No data sent to servers',
                            style: T.caption),
                      ],
                    ),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
      builder: (_, _) {
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
    return Glass(
      kind: GlassKind.strong,
      radius: T.rGlass,
      padding: const EdgeInsets.all(18),
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
                height: 8,
                decoration: BoxDecoration(
                  color: filled ? _frameColor : T.white(.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Icon + progress instruction
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
                    color: T.op(_frameColor, .18),
                    border: Border.all(color: T.op(_frameColor, .5)),
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
                        style: T.text(14.5, w: T.w800),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subInstruction,
                      style: T.text(11, color: T.white(.5)),
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
              height: 5,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: T.white(.1),
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

  Widget _buildError() {
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

    final dimPaint = Paint()..color = T.blk(.65);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawOval(rect, clearPaint);
    canvas.restore();

    // Glowing oval border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.6 + glowOpacity * 0.4)
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
