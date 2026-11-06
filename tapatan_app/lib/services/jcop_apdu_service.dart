import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'turing_composition_cipher.dart';

// ── APDU Status Words ─────────────────────────────────────────────────────

/// ISO 7816-4 standard status words.
class ApduStatus {
  static const int swNoError = 0x9000;
  static const int swFileNotFound = 0x6A82;
  static const int swSecurityNotSatisfied = 0x6982;
  static const int swConditionsNotSatisfied = 0x6985;
  static const int swWrongPin = 0x63C0; // 0x63Cx where x = retries left
  static const int swPinBlocked = 0x6983;
  static const int swWrongLength = 0x6700;
  static const int swInstructionNotSupported = 0x6D00;
  static const int swClassNotSupported = 0x6E00;

  /// Returns true if the card responded with success (SW=9000).
  static bool isSuccess(int sw) => sw == swNoError;

  /// Returns true if the SW is a wrong-PIN response (0x63Cx).
  static bool isWrongPin(int sw) => (sw & 0xFFF0) == 0x63C0;

  /// Extracts remaining PIN tries from a 0x63Cx SW word.
  static int pinTriesLeft(int sw) => sw & 0x000F;

  /// Returns true if the PIN is blocked (card locked).
  static bool isPinBlocked(int sw) => sw == swPinBlocked;
}

// ── APDU Response ─────────────────────────────────────────────────────────

/// Parsed result of an APDU command.
class ApduResponse {
  /// The data bytes returned by the card (may be empty).
  final Uint8List data;

  /// Status word (SW1 SW2) combined as a 16-bit integer.
  final int statusWord;

  ApduResponse({required this.data, required this.statusWord});

  bool get isSuccess => ApduStatus.isSuccess(statusWord);

  String get statusHex =>
      '0x${statusWord.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  @override
  String toString() =>
      'ApduResponse(sw=$statusHex, data=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':')})';
}

// ── JCOP Applet Constants ─────────────────────────────────────────────────

/// AID of the TapatMFAApplet installed on the JCOP4 J3R150 card:
/// F0 74 61 70 61 74 61 6E 01 01
const List<int> kTapatanAppletAid = [
  0xF0, 0x74, 0x61, 0x70, 0x61, 0x74, 0x61, 0x6E, 0x01, 0x01,
];

/// ISO 7816-4 instruction bytes (INS) used by TapatMFAApplet.
class ApduIns {
  static const int selectFile = 0xA4;           // Standard SELECT (ISO 7816)
  static const int getChallenge = 0x84;          // GET CHALLENGE
  static const int internalAuthenticate = 0x88;  // INTERNAL AUTHENTICATE
  static const int verify = 0x20;                // VERIFY (PIN)
  static const int getData = 0xCA;               // GET DATA
  static const int storeData = 0xE2;             // STORE DATA (payment token / identity)
  static const int changePin = 0x24;             // CHANGE REFERENCE DATA (PIN change)
}

// ── JCOP APDU Service ─────────────────────────────────────────────────────

/// Handles strict ISO 7816-4 APDU communication with TapatMFAApplet
/// running on the JCOP4 J3R150 dual-interface Java Card using the
/// Turing Multi-Tape State-Transition Composition Algorithm.
/// Any non-Tapat NFC card or unauthenticated response is strictly rejected.
class JcopApduService {
  // ── NFC Session Management ───────────────────────────────────────────────

  /// Polls for an ISO-DEP smart card (ISO 14443-4).
  static Future<Map<String, dynamic>> pollForTag({
    int timeoutSeconds = 20,
    void Function(String step)? onProgress,
  }) async {
    bool available = false;
    try {
      available = await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (_) {}

    if (!available) {
      return {'success': false, 'error': 'NFC is not available on this device'};
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          onProgress?.call('Tag detected — verifying Tapat JCOP4 applet...');

          final isoDep = IsoDepAndroid.from(tag);
          if (isoDep == null) {
            await stopSession(
              errorMessage:
                  'Unauthorized card: Not an ISO-DEP smart card.',
            );
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'unauthorizedCard': true,
                'error':
                    'Unauthorized NFC Card: Only an authentic Tapat JCOP4 Smart Card is supported.',
              });
            }
            return;
          }

          try {
            await isoDep.setTimeout(5000);
          } catch (_) {}

          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'tag': tag,
              'isIsoDep': true,
            });
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () {
        if (!completer.isCompleted) {
          NfcManager.instance.stopSession(
            errorMessageIos: 'No card detected — timed out.',
          );
          completer.complete({
            'success': false,
            'error': 'No Tapat JCOP4 card detected — hold card steady and try again',
          });
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({'success': false, 'error': e.toString()});
      }
    }

    return completer.future;
  }

  /// Stops the active NFC session cleanly.
  static Future<void> stopSession({String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(errorMessageIos: errorMessage);
    } catch (_) {}
  }

  // ── Low-Level APDU Transceive ────────────────────────────────────────────

  static Future<ApduResponse> transceive(
    NfcTag tag, {
    required int cla,
    required int ins,
    required int p1,
    required int p2,
    List<int> data = const [],
    int? le,
  }) async {
    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep == null) {
      throw StateError('Tag is not an ISO-DEP smart card');
    }

    final List<int> apdu = [cla, ins, p1, p2];
    if (data.isNotEmpty) {
      apdu.add(data.length); // Lc
      apdu.addAll(data);
    }
    if (le != null) {
      apdu.add(le); // Le
    }

    final responseBytes = await isoDep.transceive(Uint8List.fromList(apdu));

    if (responseBytes.length < 2) {
      throw StateError(
          'APDU response too short (${responseBytes.length} bytes)');
    }

    final sw1 = responseBytes[responseBytes.length - 2];
    final sw2 = responseBytes[responseBytes.length - 1];
    final responseData = responseBytes.sublist(0, responseBytes.length - 2);

    return ApduResponse(
      data: Uint8List.fromList(responseData),
      statusWord: (sw1 << 8) | sw2,
    );
  }

  // ── Applet Selection & TPT4 Handshake Verification ───────────────────────

  /// Sends `SELECT (0xA4)` for AID `F0 74 61 70 61 74 61 6E 01 01` and
  /// strictly verifies the 12-byte `"TPT4"` + 8-byte nonce Turing handshake.
  static Future<Map<String, dynamic>> selectApplet(
    NfcTag tag, {
    bool fastReadIdentity = false,
  }) async {
    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep == null) {
      return {
        'success': false,
        'unauthorizedCard': true,
        'error':
            'Unauthorized NFC Card: Only an authentic Tapat JCOP4 Smart Card is supported.',
      };
    }

    try {
      final int p2Byte = fastReadIdentity ? 0x01 : 0x00;
      ApduResponse response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.selectFile,
        p1: 0x04,
        p2: p2Byte,
        data: kTapatanAppletAid,
        le: 0x00,
      );

      if (!response.isSuccess || response.data.isEmpty) {
        response = await transceive(
          tag,
          cla: 0x00,
          ins: ApduIns.selectFile,
          p1: 0x04,
          p2: p2Byte,
          data: kTapatanAppletAid,
        );
      }

      if (!response.isSuccess) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Unauthorized NFC Card: TapatMFAApplet not found on this card (${response.statusHex}).',
        };
      }

      if (!TuringCompositionCodec.verifyTpt4Handshake(response.data)) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Unauthorized NFC Card: Card failed TPT4 Turing Composition handshake.',
        };
      }

      final String? decodedIdentity =
          TuringCompositionCodec.decodeUtf8Frame(response.data);
      final handshakeNonce =
          TuringCompositionCodec.extractHandshakeNonce(response.data);
      return {
        'success': true,
        if (handshakeNonce != null) 'nonce': handshakeNonce,
        if (decodedIdentity != null && decodedIdentity.isNotEmpty)
          'identityText': decodedIdentity,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NFC communication lost during applet selection: $e',
      };
    }
  }

  // ── Challenge-Response Authentication (Turing Composition) ───────────────

  static Future<Map<String, dynamic>> getChallenge(NfcTag tag) async {
    try {
      final response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.getChallenge,
        p1: 0x00,
        p2: 0x00,
        le: 0x08,
      );

      if (response.isSuccess && response.data.length >= 8) {
        return {'success': true, 'nonce': response.data};
      }
      return {
        'success': false,
        'error': 'Card failed GET CHALLENGE (${response.statusHex})',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NFC lost during GET CHALLENGE: $e',
      };
    }
  }

  /// Sends a Turing-encoded 16-byte challenge (`cardNonce + phoneChallenge`)
  /// via `INTERNAL AUTHENTICATE (0x88)` and decodes + verifies the card's
  /// Turing-composed response frame.
  static Future<Map<String, dynamic>> sendChallengeResponse(
    NfcTag tag,
    Uint8List cardNonce,
  ) async {
    final phoneChallenge = _generateRandomBytes(8);
    final combinedChallenge = Uint8List(16)
      ..setRange(0, cardNonce.length.clamp(0, 8), cardNonce)
      ..setRange(8, 16, phoneChallenge);

    final encodedChallenge =
        TuringCompositionCodec.encodeTuringFrame(combinedChallenge);

    try {
      ApduResponse response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.internalAuthenticate,
        p1: 0x00,
        p2: 0x00,
        data: encodedChallenge,
        le: 0x00,
      );

      if (!response.isSuccess || response.data.isEmpty) {
        response = await transceive(
          tag,
          cla: 0x00,
          ins: ApduIns.internalAuthenticate,
          p1: 0x00,
          p2: 0x00,
          data: encodedChallenge,
        );
      }

      if (!response.isSuccess) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Card rejected Turing mutual authentication (${response.statusHex}).',
        };
      }

      final decodedProof =
          TuringCompositionCodec.decodeTuringFrame(response.data);
      if (decodedProof == null || decodedProof.length < 16) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Unauthorized NFC Card: Invalid Turing Composition MAC on authentication proof.',
        };
      }

      // Verify the card decoded our challenge and echoed it inside its fresh Turing frame
      for (int i = 0; i < 16; i++) {
        if (decodedProof[i] != combinedChallenge[i]) {
          return {
            'success': false,
            'unauthorizedCard': true,
            'error':
                'Unauthorized NFC Card: Turing challenge-response mismatch.',
          };
        }
      }

      return {
        'success': true,
        'signature': response.data,
        'decodedProof': decodedProof,
        'phoneChallenge': phoneChallenge,
        'cardNonce': cardNonce,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NFC lost during Turing mutual authentication: $e',
      };
    }
  }

  // ── PIN Verification ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verifyPin(
    NfcTag tag,
    String pin,
  ) async {
    try {
      final pinBytes = utf8.encode(pin);

      final response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.verify,
        p1: 0x00,
        p2: 0x80,
        data: pinBytes,
      );

      if (response.isSuccess) {
        return {'success': true, 'retriesLeft': -1};
      }

      if (ApduStatus.isWrongPin(response.statusWord)) {
        final retries = ApduStatus.pinTriesLeft(response.statusWord);
        return {
          'success': false,
          'wrongPin': true,
          'retriesLeft': retries,
          'error':
              'Incorrect PIN — $retries ${retries == 1 ? 'attempt' : 'attempts'} remaining',
        };
      }

      if (ApduStatus.isPinBlocked(response.statusWord)) {
        return {
          'success': false,
          'blocked': true,
          'retriesLeft': 0,
          'error': 'PIN blocked — card is locked. Contact support to unblock.',
        };
      }

      return {
        'success': false,
        'error': 'PIN verification failed (${response.statusHex})',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NFC lost during PIN verification: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getPinRetryCount(NfcTag tag) async {
    try {
      final response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.verify,
        p1: 0x00,
        p2: 0x80,
      );

      if (response.isSuccess) {
        return {'success': true, 'retriesLeft': 5};
      }
      if (ApduStatus.isWrongPin(response.statusWord)) {
        return {
          'success': true,
          'retriesLeft': ApduStatus.pinTriesLeft(response.statusWord),
        };
      }
      if (ApduStatus.isPinBlocked(response.statusWord)) {
        return {'success': true, 'retriesLeft': 0};
      }
    } catch (_) {}

    return {'success': false, 'retriesLeft': 0};
  }

  // ── Card Identity & Data ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> readCardUid(NfcTag tag) async {
    try {
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && androidTag.id.isNotEmpty) {
        final uidBytes = androidTag.id;
        final uid = uidBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(':');
        return {
          'success': true,
          'uid': uid,
          'uidBytes': List<int>.from(uidBytes),
        };
      }
    } catch (_) {}

    return {
      'success': false,
      'error': 'Unable to read hardware UID from NFC tag.',
    };
  }

  static Future<Map<String, dynamic>> readAts(NfcTag tag) async {
    try {
      final isoDep = IsoDepAndroid.from(tag);
      if (isoDep != null) {
        final hiLayer = isoDep.hiLayerResponse ?? isoDep.historicalBytes;
        if (hiLayer != null && hiLayer.isNotEmpty) {
          final ats = hiLayer
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(' ');
          return {'success': true, 'ats': ats};
        }
      }
    } catch (_) {}
    return {'success': true, 'ats': 'ISO-DEP T=CL'};
  }

  // ── Turing-Composed STORE DATA / GET DATA ────────────────────────────────

  /// Encodes [jsonPayload] into a `'T','M'` Turing Composition frame and
  /// writes it to `TapatMFAApplet` via `STORE DATA (0xE2)`.
  static Future<Map<String, dynamic>> storeDataOnCard(
    NfcTag tag,
    String jsonPayload, {
    int p1 = 0x00,
  }) async {
    try {
      final rawBytes = utf8.encode(jsonPayload);
      final plainBytes =
          rawBytes.length > 128 ? rawBytes.sublist(0, 128) : rawBytes;
      final turingFrame = TuringCompositionCodec.encodeTuringFrame(plainBytes);

      final response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.storeData,
        p1: p1,
        p2: 0x00,
        data: turingFrame,
      );

      if (!response.isSuccess) {
        return {
          'success': false,
          'error':
              'Card rejected Turing STORE DATA frame (${response.statusHex}).',
        };
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('snfc_last_card_json', jsonPayload);
      if (p1 == 0x01 || jsonPayload.contains('"tapatan_id"')) {
        await prefs.setString('snfc_identity_json', jsonPayload);
      }

      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to write Turing frame to card: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> storePaymentToken(
    NfcTag tag,
    String tokenJson,
  ) async {
    return storeDataOnCard(tag, tokenJson, p1: 0x00);
  }

  /// Reads a `'T','M'` Turing Composition frame from `TapatMFAApplet` via
  /// `GET DATA (0xCA)` and verifies + decodes its UTF-8 JSON payload.
  static Future<Map<String, dynamic>> getDataFromCard(
    NfcTag tag, {
    int p1 = 0x00,
  }) async {
    try {
      final response = await transceive(
        tag,
        cla: 0x00,
        ins: ApduIns.getData,
        p1: p1,
        p2: 0x00,
        le: 0x00,
      );

      if (!response.isSuccess || response.data.isEmpty) {
        return {
          'success': false,
          'error': 'GET DATA failed (${response.statusHex}).',
        };
      }

      final decodedText = TuringCompositionCodec.decodeUtf8Frame(response.data);
      if (decodedText == null || decodedText.isEmpty) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Unauthorized NFC Card: Failed Turing Composition MAC decoding on card data.',
        };
      }

      return {'success': true, 'text': decodedText};
    } catch (e) {
      return {
        'success': false,
        'error': 'NFC lost while reading Turing frame from card: $e',
      };
    }
  }

  // ── Full Auth Flow ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> runAuthFlow(
    NfcTag tag, {
    void Function(String step)? onStep,
  }) async {
    onStep?.call('Selecting TapatMFAApplet & verifying TPT4 handshake...');
    final selRes = await selectApplet(tag);
    if (selRes['success'] != true) {
      return selRes;
    }

    onStep?.call('Reading card hardware UID...');
    final uidResult = await readCardUid(tag);
    if (uidResult['success'] != true) {
      return uidResult;
    }
    final uid = uidResult['uid'] as String;

    onStep?.call('Requesting hardware RNG challenge...');
    final challengeResult = await getChallenge(tag);
    if (challengeResult['success'] != true) {
      return challengeResult;
    }
    final nonce = challengeResult['nonce'] as Uint8List;

    onStep?.call('Verifying Turing Composition mutual proof...');
    final authResult = await sendChallengeResponse(tag, nonce);
    if (authResult['success'] != true) {
      return authResult;
    }

    return {
      ...authResult,
      'uid': uid,
      'success': true,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Uint8List _generateRandomBytes(int count) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(count, (_) => rng.nextInt(256)),
    );
  }
}
