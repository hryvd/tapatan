import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ─── Store product label map (matches training class order IMG_4042–IMG_4081) ─
const List<String> _classNames = <String>[
  'Kopiko Blanca 3-in-1',                    // 0  – IMG_4042
  'Great Taste White 3-in-1',               // 1  – IMG_4043
  'Great Taste White 3-in-1',               // 2  – IMG_4044 (same product)
  'Choco Crunch Milk Powder',               // 3
  'Swiss Miss Choco Mix',                   // 4  – IMG_4045
  'Birch Tree Chocolate Milk Powder',       // 5  – IMG_4046
  'Milo Choco Malt Drink',                  // 6  – IMG_4047
  'Great Taste Choco 3-in-1',               // 7  – IMG_4048
  'Choco Milk Drink Sachet',                // 8  – IMG_4049
  'Chocolait Choco Drink',                  // 9  – IMG_4050
  'Hopia Hapon Style Ube Flavor',           // 10 – IMG_4051
  'Hopia Hapon Style Monggo Flavor',        // 11 – IMG_4052
  'Special Piyaya',                         // 12 – IMG_4053
  'Alaska Creamer Sachet',                  // 13 – IMG_4054
  "Lady's Choice Mayonnaise",               // 14 – IMG_4055
  'Kulina Real Mayonnaise',                 // 15 – IMG_4056
  'Kulina Spread',                          // 16 – IMG_4057
  "Lady's Choice Sandwich Spread",          // 17 – IMG_4058
  'Hotcake Mix 200g',                       // 18 – IMG_4059
  'Alaska Classic Evaporated Milk 370mL',   // 19 – IMG_4060
  'Alaska Evaporada 250mL',                 // 20 – IMG_4061
  'Hany Milk Chocolate Bar',                // 21 – IMG_4062
  'Sea Point Corned Tuna 155g',             // 22 – IMG_4063
  'Bingo Corned Beef 150g',                 // 23 – IMG_4064
  'Sea Point Tuna 155g',                    // 24 – IMG_4065
  'Century Tuna Flakes in Oil 180g',        // 25 – IMG_4066
  'Century Tuna Hot and Spicy 180g',        // 26 – IMG_4067
  'San Marino Chili Corned Tuna 155g',      // 27 – IMG_4068
  'Sea Point Tuna Flakes in Spicy 155g',    // 28 – IMG_4069
  'Lucky Me! Pancit Canton Chilimansi',     // 29 – IMG_4070
  'Lucky Me! Pancit Canton Original',       // 30 – IMG_4071
  'Lucky Me! Pancit Canton Extra Spicy',    // 31 – IMG_4072
  'Xtra Big Spicy Instant Noodles',         // 32 – IMG_4073
  'Xtra Big Calamansi Instant Noodles',     // 33 – IMG_4074
  'Pocari Sweat 350mL',                     // 34 – IMG_4075
  'Gatorade 350mL',                         // 35 – IMG_4076
  'Twist-O Juice Drink',                    // 36 – IMG_4077
  'Rite+Lite Lychee Rose Juice',            // 37 – IMG_4078
  'Soda Water',                             // 38 – IMG_4079
  'Sprite 1.5L',                            // 39 – IMG_4080
  'Mountain Dew 1.5L',                      // 40 – IMG_4081
];

// ─── Prediction result ────────────────────────────────────────────────────────

class AiPrediction {
  const AiPrediction({
    required this.rank,
    required this.classId,
    required this.productName,
    required this.confidence,
    this.isMock = false,
  });

  final int rank;
  final String classId;
  final String productName;
  final double confidence;
  final bool isMock;
}

// ─── Background preprocessing (runs in a separate Isolate) ───────────────────

/// Input data sent to the isolate: raw image bytes + class count
class _PreprocessInput {
  _PreprocessInput(this.bytes, this.numClasses);
  final Uint8List bytes;
  final int numClasses;
}

/// Runs in a background isolate: decode → resize → normalize → return Float32List
Float32List _preprocessInBackground(_PreprocessInput input) {
  img.Image? raw = img.decodeImage(input.bytes);
  if (raw == null) return Float32List(0);

  const int size = 224;
  final img.Image resized = img.copyResize(raw, width: size, height: size);

  const List<double> mean = <double>[0.485, 0.456, 0.406];
  const List<double> std  = <double>[0.229, 0.224, 0.225];

  // Flatten into [1, 224, 224, 3] row-major Float32 buffer
  final Float32List buf = Float32List(1 * size * size * 3);
  int offset = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final img.Pixel pixel = resized.getPixel(x, y);
      buf[offset++] = (pixel.r / 255.0 - mean[0]) / std[0];
      buf[offset++] = (pixel.g / 255.0 - mean[1]) / std[1];
      buf[offset++] = (pixel.b / 255.0 - mean[2]) / std[2];
    }
  }
  return buf;
}

// ─── Offline TFLite AI Service ────────────────────────────────────────────────

class AiScanService {
  static const String _modelAsset = 'assets/models/product_model.tflite';
  static const int _inputSize = 224;
  static const int _topK = 3;

  Interpreter? _interpreter;
  bool _loaded = false;
  bool _modelMissing = false;
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  /// Load the TFLite model from Flutter assets. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final InterpreterOptions options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
      _loaded = true;
    } catch (_) {
      _modelMissing = true;
      _loaded = true; // avoid retry loops
    } finally {
      _loading = false;
    }
  }

  bool get isReady => _loaded && !_modelMissing && _interpreter != null;

  Future<bool> isHealthy() async => true;

  /// Picks image from [source], runs TFLite inference on a background thread,
  /// and returns top-K predictions. Never throws — returns empty list on error.
  Future<List<AiPrediction>> pickAndPredict({
    ImageSource source = ImageSource.camera,
  }) async {
    try {
      await load();

      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return const <AiPrediction>[];

      return await _predict(File(file.path));
    } catch (e) {
      return const <AiPrediction>[];
    }
  }

  Future<List<AiPrediction>> predictOnFile(File imageFile) async {
    try {
      await load();
      return await _predict(imageFile);
    } catch (e) {
      return const <AiPrediction>[];
    }
  }

  Future<List<AiPrediction>> _predict(File imageFile) async {
    if (_modelMissing || _interpreter == null) {
      return _mockPredictions();
    }

    try {
      final Uint8List bytes = await imageFile.readAsBytes();

      // ── Heavy preprocessing runs in a background isolate ─────────────────
      final Float32List flatInput = await Isolate.run(
        () => _preprocessInBackground(_PreprocessInput(bytes, _classNames.length)),
      );

      if (flatInput.isEmpty) return _mockPredictions();

      // Reshape to [1, 224, 224, 3]
      final List<List<List<List<double>>>> input = List.generate(
          1,
          (_) => List.generate(
              _inputSize,
              (y) => List.generate(
                  _inputSize,
                  (x) => List<double>.from(flatInput.sublist(
                        (y * _inputSize + x) * 3,
                        (y * _inputSize + x) * 3 + 3,
                      )))));

      // Output shape: [1, NUM_CLASSES]
      final List<List<double>> output =
          List.generate(1, (_) => List<double>.filled(_classNames.length, 0.0));

      _interpreter!.run(input, output);

      final List<double> logits = output[0];
      final List<double> probs = _softmax(logits);

      final List<int> sortedIdx = List<int>.generate(probs.length, (i) => i)
        ..sort((int a, int b) => probs[b].compareTo(probs[a]));

      return sortedIdx.take(_topK).toList().asMap().entries.map((MapEntry<int, int> e) {
        final int idx = e.value;
        final String name = idx < _classNames.length
            ? _classNames[idx]
            : 'Unknown Product $idx';
        return AiPrediction(
          rank: e.key + 1,
          classId: 'class_$idx',
          productName: name,
          confidence: double.parse(probs[idx].toStringAsFixed(4)),
        );
      }).toList();
    } catch (_) {
      return _mockPredictions();
    }
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return <double>[];
    final double maxLogit = logits.reduce(math.max);
    final List<double> exps = logits.map((double l) => math.exp(l - maxLogit)).toList();
    final double sumExp = exps.reduce((double a, double b) => a + b);
    return exps.map((double e) => e / sumExp).toList();
  }

  List<AiPrediction> _mockPredictions() {
    return const <AiPrediction>[
      AiPrediction(
        rank: 1,
        classId: 'mock',
        productName: 'AI model not loaded yet',
        confidence: 0.0,
        isMock: true,
      ),
    ];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
    _loading = false;
  }
}

/// App-wide singleton
final AiScanService aiScanService = AiScanService();
