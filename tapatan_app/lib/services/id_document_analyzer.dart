import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Image exposure, contrast, glare, and focus metrics computed in an isolate.
class ImageQualityMetrics {
  final int width;
  final int height;
  final double meanLuma;
  final double contrastStdDev;
  final double glareRatio;
  final double darkRatio;
  final double sharpness;
  final bool isReadable;
  final bool isGoodPicture;
  final String? failureReason;

  const ImageQualityMetrics({
    required this.width,
    required this.height,
    required this.meanLuma,
    required this.contrastStdDev,
    required this.glareRatio,
    required this.darkRatio,
    required this.sharpness,
    required this.isReadable,
    required this.isGoodPicture,
    this.failureReason,
  });

  const ImageQualityMetrics.unreadable()
      : width = 0,
        height = 0,
        meanLuma = 0,
        contrastStdDev = 0,
        glareRatio = 0,
        darkRatio = 1,
        sharpness = 0,
        isReadable = false,
        isGoodPicture = false,
        failureReason = 'Could not read captured photo — please try again';
}

/// ID card linguistic and formatting signals extracted from recognized text.
class IdTextSignals {
  final String rawText;
  final int lineCount;
  final int charCount;
  final List<String> matchedKeywords;
  final bool hasMrz;
  final bool hasStructuredIdNumber;
  final bool hasDatePattern;
  final int score;

  const IdTextSignals({
    required this.rawText,
    required this.lineCount,
    required this.charCount,
    required this.matchedKeywords,
    required this.hasMrz,
    required this.hasStructuredIdNumber,
    required this.hasDatePattern,
    required this.score,
  });

  const IdTextSignals.empty()
      : rawText = '',
        lineCount = 0,
        charCount = 0,
        matchedKeywords = const [],
        hasMrz = false,
        hasStructuredIdNumber = false,
        hasDatePattern = false,
        score = 0;

  bool get hasSufficientText => lineCount >= 2 && charCount >= 14;
}

/// Combined picture-quality and ID-document verification outcome.
class IdDocumentAnalysis {
  final ImageQualityMetrics quality;
  final IdTextSignals text;
  final int detectedFaces;
  final bool hasIdPortrait;
  final bool looksLikeSelfieOnly;
  final bool isValidId;
  final String summary;
  final String? failureReason;

  const IdDocumentAnalysis({
    required this.quality,
    required this.text,
    required this.detectedFaces,
    required this.hasIdPortrait,
    required this.looksLikeSelfieOnly,
    required this.isValidId,
    required this.summary,
    this.failureReason,
  });

  bool get isAccepted => quality.isGoodPicture && isValidId;
}

/// Analyzes luminance, contrast, glare, sharpness, and edge detail on [bytes].
/// Designed for `compute(...)` isolate execution on the cropped scan frame.
ImageQualityMetrics analyzeIdImageQualityBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 200 || decoded.height < 120) {
    return const ImageQualityMetrics.unreadable();
  }

  final origW = decoded.width;
  final origH = decoded.height;
  final sample = origW > 240
      ? img.copyResize(
          decoded,
          width: 240,
          interpolation: img.Interpolation.linear,
        )
      : decoded;

  final w = sample.width;
  final h = sample.height;
  if (w < 16 || h < 16) {
    return const ImageQualityMetrics.unreadable();
  }

  final luma = Float64List(w * h);
  var sumY = 0.0;
  var sumY2 = 0.0;
  var glareCount = 0;
  var darkCount = 0;

  final marginX = (w * 0.04).floor().clamp(1, w ~/ 4);
  final marginY = (h * 0.04).floor().clamp(1, h ~/ 4);
  var interiorCount = 0;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = sample.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final yVal = 0.299 * r + 0.587 * g + 0.114 * b;
      luma[y * w + x] = yVal;

      if (x >= marginX &&
          x < w - marginX &&
          y >= marginY &&
          y < h - marginY) {
        interiorCount++;
        sumY += yVal;
        sumY2 += yVal * yVal;
        if (yVal >= 245.0) glareCount++;
        if (yVal <= 30.0) darkCount++;
      }
    }
  }

  if (interiorCount == 0) {
    return const ImageQualityMetrics.unreadable();
  }

  final meanY = sumY / interiorCount;
  final varianceY = math.max(0.0, (sumY2 / interiorCount) - meanY * meanY);
  final stdDevY = math.sqrt(varianceY);
  final glareRatio = glareCount / interiorCount;
  final darkRatio = darkCount / interiorCount;

  // 4-neighbor discrete Laplacian variance on interior pixels measures focus sharpness.
  var sumLap = 0.0;
  var sumLap2 = 0.0;
  var lapCount = 0;
  for (var y = math.max(1, marginY); y < math.min(h - 1, h - marginY); y++) {
    final row = y * w;
    for (var x = math.max(1, marginX); x < math.min(w - 1, w - marginX); x++) {
      final idx = row + x;
      final lap = 4.0 * luma[idx] -
          luma[idx - 1] -
          luma[idx + 1] -
          luma[idx - w] -
          luma[idx + w];
      sumLap += lap;
      sumLap2 += lap * lap;
      lapCount++;
    }
  }

  final lapMean = lapCount > 0 ? sumLap / lapCount : 0.0;
  final sharpness =
      lapCount > 0 ? math.max(0.0, (sumLap2 / lapCount) - lapMean * lapMean) : 0.0;

  String? failure;
  if (meanY < 50.0 || darkRatio > 0.72) {
    failure = 'Photo is too dark — move to brighter lighting';
  } else if (meanY > 232.0 || glareRatio > 0.34) {
    failure = 'Too much glare — angle the ID slightly away from direct light';
  } else if (stdDevY < 18.0) {
    failure = 'Low contrast or blank scene — place ID on a contrasting surface';
  } else if (sharpness < 75.0) {
    failure = 'Photo looks blurry — hold steady so all ID text is crisp';
  }

  return ImageQualityMetrics(
    width: origW,
    height: origH,
    meanLuma: meanY,
    contrastStdDev: stdDevY,
    glareRatio: glareRatio,
    darkRatio: darkRatio,
    sharpness: sharpness,
    isReadable: true,
    isGoodPicture: failure == null,
    failureReason: failure,
  );
}

/// On-device quality + OCR + portrait analyzer for government ID scans.
class IdDocumentAnalyzer {
  IdDocumentAnalyzer._();

  static const List<String> _idKeywords = [
    'republic',
    'republika',
    'philippines',
    'pilipinas',
    'pambansang',
    'pagkakakilanlan',
    'philsys',
    'philid',
    'umid',
    'sss',
    'gsis',
    'philhealth',
    'driver',
    'license',
    'licence',
    'passport',
    'pasaporte',
    'postal',
    'voter',
    'comelec',
    'prc',
    'nbi',
    'identification',
    'identity',
    'national',
    'citizen',
    'government',
    'surname',
    'last name',
    'given name',
    'first name',
    'middle',
    'apelyido',
    'pangalan',
    'birth',
    'kapanganakan',
    'dob',
    'sex',
    'nationality',
    'address',
    'tirahan',
    'valid',
    'expiry',
    'expires',
    'issued',
    'crn',
    'psn',
    'tin',
    'phl',
    'card',
  ];

  static final RegExp _keywordBoundCache = RegExp(r'\s+');
  static final RegExp _alnumRe = RegExp(r'[A-Za-z0-9]');
  static final RegExp _mrzLineRe = RegExp(r'[A-Z0-9<]{22,}<<[A-Z0-9<]*');
  static final RegExp _structuredIdRe = RegExp(
    r'\b(?:[A-Z]\d{2}-\d{2}-\d{6}|\d{4}[-\s]\d{4}[-\s]\d{4}(?:[-\s]\d{4})?|\d{4}-\d{7}-\d|[A-Z]{1,2}\d{6,8}[A-Z]?|[A-Z0-9]{2,5}(?:-[A-Z0-9]{2,7}){1,3})\b',
  );
  static final RegExp _dateRe = RegExp(
    r'\b(?:\d{2,4}[-/]\d{2}[-/]\d{2,4}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4})\b',
    caseSensitive: false,
  );

  /// Classifies recognized OCR text for government / identity document traits.
  static IdTextSignals classifyIdOcrText(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const IdTextSignals.empty();

    final nonEmptyLines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => _alnumRe.allMatches(l).length >= 2)
        .toList();
    final charCount = _alnumRe.allMatches(trimmed).length;
    final upperText = trimmed.toUpperCase().replaceAll(' ', '');
    final hasMrz = _mrzLineRe.hasMatch(upperText);

    final normLower =
        trimmed.toLowerCase().replaceAll(_keywordBoundCache, ' ');
    final matched = <String>[];
    for (final kw in _idKeywords) {
      if (kw.contains(' ')) {
        if (normLower.contains(kw)) matched.add(kw);
      } else {
        if (RegExp('\\b${RegExp.escape(kw)}\\b').hasMatch(normLower)) {
          matched.add(kw);
        }
      }
    }

    final hasStructuredIdNumber = _structuredIdRe.allMatches(trimmed.toUpperCase()).any(
          (m) => RegExp(r'\d').allMatches(m.group(0) ?? '').length >= 4,
        ) ||
        RegExp(r'\b\d{7,16}\b').hasMatch(trimmed);
    final hasDatePattern = _dateRe.hasMatch(trimmed);

    var score = 0;
    if (hasMrz) score += 3;
    score += math.min(6, matched.length * 2);
    if (hasStructuredIdNumber) score += 2;
    if (hasDatePattern) score += 2;
    if (nonEmptyLines.length >= 4 && charCount >= 30) score += 1;

    return IdTextSignals(
      rawText: trimmed,
      lineCount: nonEmptyLines.length,
      charCount: charCount,
      matchedKeywords: matched,
      hasMrz: hasMrz,
      hasStructuredIdNumber: hasStructuredIdNumber,
      hasDatePattern: hasDatePattern,
      score: score,
    );
  }

  /// Combines [quality], [text], and face width ratios relative to card width.
  static IdDocumentAnalysis evaluateSignals({
    required ImageQualityMetrics quality,
    required IdTextSignals text,
    required List<double> relativeFaceWidths,
  }) {
    if (!quality.isGoodPicture) {
      return IdDocumentAnalysis(
        quality: quality,
        text: text,
        detectedFaces: relativeFaceWidths.length,
        hasIdPortrait: false,
        looksLikeSelfieOnly: false,
        isValidId: false,
        summary: 'Photo quality check failed',
        failureReason: quality.failureReason,
      );
    }

    final hasIdPortrait =
        relativeFaceWidths.any((w) => w >= 0.06 && w <= 0.62);
    final looksLikeSelfieOnly =
        relativeFaceWidths.any((w) => w > 0.62) && !text.hasSufficientText;

    if (looksLikeSelfieOnly) {
      return IdDocumentAnalysis(
        quality: quality,
        text: text,
        detectedFaces: relativeFaceWidths.length,
        hasIdPortrait: false,
        looksLikeSelfieOnly: true,
        isValidId: false,
        summary: 'Selfie detected',
        failureReason:
            'Selfie detected — place your physical government ID in the frame',
      );
    }

    if (!text.hasSufficientText) {
      return IdDocumentAnalysis(
        quality: quality,
        text: text,
        detectedFaces: relativeFaceWidths.length,
        hasIdPortrait: hasIdPortrait,
        looksLikeSelfieOnly: false,
        isValidId: false,
        summary: 'ID text not readable',
        failureReason:
            'Could not read ID text — move closer so card text is legible',
      );
    }

    final hasPortraitAndIdText =
        hasIdPortrait && (text.score >= 2 || text.lineCount >= 3);
    final hasStrongGovIdText = text.score >= 5 &&
        (text.matchedKeywords.length >= 2 ||
            text.hasMrz ||
            (text.matchedKeywords.isNotEmpty &&
                (text.hasStructuredIdNumber || text.hasDatePattern)));

    if (!hasPortraitAndIdText && !hasStrongGovIdText) {
      return IdDocumentAnalysis(
        quality: quality,
        text: text,
        detectedFaces: relativeFaceWidths.length,
        hasIdPortrait: hasIdPortrait,
        looksLikeSelfieOnly: false,
        isValidId: false,
        summary: 'Not recognized as an ID document',
        failureReason:
            'Not recognized as an ID — ensure both photo and ID text are clearly visible',
      );
    }

    final kwLabel = text.matchedKeywords.isNotEmpty
        ? text.matchedKeywords.take(2).map((k) => k.toUpperCase()).join(' · ')
        : '${text.lineCount} text lines';
    final summary = hasIdPortrait
        ? 'Photo ✓ · $kwLabel'
        : 'ID text ✓ · $kwLabel';

    return IdDocumentAnalysis(
      quality: quality,
      text: text,
      detectedFaces: relativeFaceWidths.length,
      hasIdPortrait: hasIdPortrait,
      looksLikeSelfieOnly: false,
      isValidId: true,
      summary: summary,
    );
  }

  /// Runs image quality analysis, ML Kit text recognition, and face detection
  /// on [imagePath] to verify the shot is crisp and actually depicts an ID card.
  static Future<IdDocumentAnalysis> analyzeFile(String imagePath) async {
    late final Uint8List bytes;
    try {
      bytes = await File(imagePath).readAsBytes();
    } catch (_) {
      return const IdDocumentAnalysis(
        quality: ImageQualityMetrics.unreadable(),
        text: IdTextSignals.empty(),
        detectedFaces: 0,
        hasIdPortrait: false,
        looksLikeSelfieOnly: false,
        isValidId: false,
        summary: 'Photo unreadable',
        failureReason: 'Could not read captured photo — please retake',
      );
    }

    final quality = await compute(analyzeIdImageQualityBytes, bytes);
    if (!quality.isGoodPicture) {
      return evaluateSignals(
        quality: quality,
        text: const IdTextSignals.empty(),
        relativeFaceWidths: const [],
      );
    }

    final inputImage = InputImage.fromFilePath(imagePath);

    final textFuture = () async {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognized = await recognizer.processImage(inputImage);
        return recognized.text;
      } catch (_) {
        return '';
      } finally {
        try {
          await recognizer.close();
        } catch (_) {}
      }
    }();

    final faceFuture = () async {
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.06,
        ),
      );
      try {
        final faces = await detector.processImage(inputImage);
        return faces
            .map((f) => f.boundingBox.width / quality.width)
            .toList(growable: false);
      } catch (_) {
        return const <double>[];
      } finally {
        try {
          await detector.close();
        } catch (_) {}
      }
    }();

    final results = await Future.wait([textFuture, faceFuture]);
    final ocrText = results[0] as String;
    final faceWidths = results[1] as List<double>;

    return evaluateSignals(
      quality: quality,
      text: classifyIdOcrText(ocrText),
      relativeFaceWidths: faceWidths,
    );
  }
}

