import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secure_nfc_pay/services/id_document_analyzer.dart';

Uint8List _encodeRgbImage(int w, int h, int Function(int x, int y) lumaAt) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = lumaAt(x, y).clamp(0, 255);
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('Image quality rejects dark, glared, flat, and blurry captures while accepting sharp well-lit shots', () {
    final dark = _encodeRgbImage(240, 150, (x, y) => (x + y) % 15 + 10);
    final darkRes = analyzeIdImageQualityBytes(dark);
    expect(darkRes.isGoodPicture, isFalse);
    expect(darkRes.failureReason?.toLowerCase(), contains('dark'));

    final glared = _encodeRgbImage(240, 150, (x, y) => 250);
    final glareRes = analyzeIdImageQualityBytes(glared);
    expect(glareRes.isGoodPicture, isFalse);
    expect(glareRes.failureReason?.toLowerCase(), contains('glare'));

    final flat = _encodeRgbImage(240, 150, (x, y) => 130 + ((x + y) % 4));
    final flatRes = analyzeIdImageQualityBytes(flat);
    expect(flatRes.isGoodPicture, isFalse);
    expect(flatRes.failureReason?.toLowerCase(), contains('contrast'));

    // Smooth low-frequency sine/ramp gradient simulates an out-of-focus shot
    final blurry = _encodeRgbImage(
      240,
      150,
      (x, y) => (70 + (x * 110 / 240)).round(),
    );
    final blurryRes = analyzeIdImageQualityBytes(blurry);
    expect(blurryRes.isGoodPicture, isFalse);
    expect(blurryRes.failureReason?.toLowerCase(), contains('blurry'));

    // Crisp printed-card bands and dark-on-light block edges pass quality gate
    final sharpCard = _encodeRgbImage(240, 150, (x, y) {
      final isCardHeader = y >= 18 && y <= 34 && x >= 24 && x <= 216;
      final isTextStripe =
          (y == 54 || y == 74 || y == 94) && x >= 88 && x <= 210 && (x % 4 < 2);
      final isPortrait = x >= 24 && x <= 74 && y >= 48 && y <= 122 && ((x + y) % 3 == 0);
      return (isCardHeader || isTextStripe || isPortrait) ? 28 : 210;
    });
    final sharpRes = analyzeIdImageQualityBytes(sharpCard);
    expect(sharpRes.isReadable, isTrue);
    expect(sharpRes.isGoodPicture, isTrue, reason: sharpRes.failureReason);
  });

  test('ID document evaluation accepts government IDs and passports, and rejects selfies or non-ID text', () {
    const goodQuality = ImageQualityMetrics(
      width: 960,
      height: 605,
      meanLuma: 145,
      contrastStdDev: 48,
      glareRatio: 0.02,
      darkRatio: 0.05,
      sharpness: 620,
      isReadable: true,
      isGoodPicture: true,
    );

    // 1. Philippine Driver's License + printed ID portrait
    final dlSignals = IdDocumentAnalyzer.classifyIdOcrText('''
REPUBLIC OF THE PHILIPPINES
LAND TRANSPORTATION OFFICE
DRIVER'S LICENSE
SURNAME: DELA CRUZ
FIRST NAME: JUAN
LICENSE NO: N01-12-345678
DATE OF BIRTH: 1994/05/12
''');
    final dlEval = IdDocumentAnalyzer.evaluateSignals(
      quality: goodQuality,
      text: dlSignals,
      relativeFaceWidths: const [0.22],
    );
    expect(dlEval.isAccepted, isTrue, reason: dlEval.failureReason);
    expect(dlEval.hasIdPortrait, isTrue);

    // 2. Passport MRZ document even without portrait detector hit
    final passportSignals = IdDocumentAnalyzer.classifyIdOcrText('''
PASSPORT
REPUBLIC OF THE PHILIPPINES
SURNAME: REYES
GIVEN NAMES: ELENA
NATIONALITY: FILIPINO
P<PHLREYES<<ELENA<<<<<<<<<<<<<<<<<<<<<<<<<<<
P1234567A8PHL9503141F3005128<<<<<<<<<<<<<<04
''');
    final passportEval = IdDocumentAnalyzer.evaluateSignals(
      quality: goodQuality,
      text: passportSignals,
      relativeFaceWidths: const [],
    );
    expect(passportEval.isAccepted, isTrue, reason: passportEval.failureReason);

    // 3. Random grocery store receipt (text present, no ID markers, no face portrait) -> rejected
    final receiptSignals = IdDocumentAnalyzer.classifyIdOcrText('''
MERCURY STORE #14
ITEM COFFEE   125.00
SUBTOTAL      125.00
THANK YOU COME AGAIN
''');
    final receiptEval = IdDocumentAnalyzer.evaluateSignals(
      quality: goodQuality,
      text: receiptSignals,
      relativeFaceWidths: const [],
    );
    expect(receiptEval.isAccepted, isFalse);
    expect(receiptEval.failureReason?.toLowerCase(), contains('not recognized'));

    // 4. Close-up live selfie with no ID text -> rejected
    final selfieEval = IdDocumentAnalyzer.evaluateSignals(
      quality: goodQuality,
      text: const IdTextSignals.empty(),
      relativeFaceWidths: const [0.76],
    );
    expect(selfieEval.isAccepted, isFalse);
    expect(selfieEval.looksLikeSelfieOnly, isTrue);
  });
}

