import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:secure_nfc_pay/services/jcop_apdu_service.dart';
import 'package:secure_nfc_pay/services/nfc_service.dart';

void main() {
  group('iOS CoreNFC & ISO-7816 Configuration Verification', () {
    test('CoreNFC expectedResponseLength maps ISO 7816-4 Le values accurately',
        () {
      // Case 1 / Case 3 (no Le): CoreNFC requires -1
      expect(JcopApduService.coreNfcExpectedResponseLength(null), equals(-1));
      // Le = 0x00 (max 256 bytes in short APDU): CoreNFC requires 256
      expect(JcopApduService.coreNfcExpectedResponseLength(0x00), equals(256));
      // Explicit short Le values (e.g. GET CHALLENGE = 8 bytes)
      expect(JcopApduService.coreNfcExpectedResponseLength(0x08), equals(8));
      expect(JcopApduService.coreNfcExpectedResponseLength(0x0C), equals(12));
    });

    test('TapatMFAApplet AID hex matches byte array constant', () {
      final computedHex = kTapatanAppletAid
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();
      expect(computedHex, equals('F07461706174616E0101'));
      expect(JcopApduService.kTapatanAppletAidHex, equals(computedHex));
    });

    test('Mock/unsupported NfcTag is safely rejected without crashing', () {
      const dummyTag = NfcTag(data: Object());
      expect(JcopApduService.isIso7816SupportedTag(dummyTag), isFalse);
      expect(
        NfcService.uidToHex([0x04, 0x7A, 0x93, 0xE2, 0x10, 0x88, 0x01]),
        equals('04:7A:93:E2:10:88:01'),
      );
    });

    test('ios/Runner/Info.plist declares CoreNFC ISO-7816 AID and permissions',
        () {
      final infoPlist = File('ios/Runner/Info.plist');
      expect(infoPlist.existsSync(), isTrue);
      final content = infoPlist.readAsStringSync();

      expect(content, contains('<string>tap@tan v2</string>'));
      expect(content, contains('<key>NFCReaderUsageDescription</key>'));
      expect(
        content,
        contains(
          '<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>',
        ),
      );
      expect(content, contains('<string>F07461706174616E0101</string>'));
      expect(content, contains('<key>NSCameraUsageDescription</key>'));
      expect(content, contains('<key>NSLocalNetworkUsageDescription</key>'));
    });

    test('ios/Runner/Runner.entitlements declares CoreNFC TAG & NDEF formats',
        () {
      final entitlements = File('ios/Runner/Runner.entitlements');
      expect(entitlements.existsSync(), isTrue);
      final content = entitlements.readAsStringSync();

      expect(
        content,
        contains('<key>com.apple.developer.nfc.readersession.formats</key>'),
      );
      expect(content, contains('<string>TAG</string>'));
      expect(content, contains('<string>NDEF</string>'));
    });

    test('ios/Podfile and Xcode project target iOS 15.5+ for MLKit & CoreNFC',
        () {
      final podfile = File('ios/Podfile');
      expect(podfile.existsSync(), isTrue);
      expect(podfile.readAsStringSync(), contains("platform :ios, '15.5'"));

      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(pbxproj.existsSync(), isTrue);
      final pbxContent = pbxproj.readAsStringSync();
      expect(pbxContent, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.5;'));
      expect(
        pbxContent,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
      );
      expect(
        pbxContent,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.sare.secureNfcPay.v2;'),
      );
    });
  });
}

