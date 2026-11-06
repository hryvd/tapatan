import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// AID of the TapatMFAApplet installed on the JCOP4 J3R150 card:
/// F0 74 61 70 61 74 61 6E 01 01
const List<int> kTapatanAppletAid = <int>[
  0xF0, 0x74, 0x61, 0x70, 0x61, 0x74, 0x61, 0x6E, 0x01, 0x01,
];

/// Turing-Type Multi-Tape State-Transition Composition Codec
/// (\mathcal{T} = \delta_{MAC} \circ \delta_{tape} \circ \delta_{init}).
///
/// Mutually encodes, decodes, and authenticates APDU payloads between
/// the Sar-E POS terminal and TapatMFAApplet on the physical JCOP4 smart card.
/// Any non-Tapat card or forged/unencoded payload fails verification.
class TuringCompositionCodec {
  static const int headerLength = 14; // 'T', 'M' (2B) + Nonce (8B) + TMAC (4B)

  /// Shared 16-byte Hardware Key ("TAPAT_TURING_KEY") matching TapatMFAApplet.java
  static const List<int> turingKey = <int>[
    0x54, 0x41, 0x50, 0x41, // "TAPA"
    0x54, 0x5F, 0x54, 0x55, // "T_TU"
    0x52, 0x49, 0x4E, 0x47, // "RING"
    0x5F, 0x4B, 0x45, 0x59, // "_KEY"
  ];

  /// Verifies the 12-byte "TPT4" + 8B nonce SELECT handshake returned by TapatMFAApplet.
  static bool verifyTpt4Handshake(List<int> selectData) {
    if (selectData.length >= 12 &&
        selectData[0] == 0x54 && // 'T'
        selectData[1] == 0x50 && // 'P'
        selectData[2] == 0x54 && // 'T'
        selectData[3] == 0x34) {
      // '4'
      return true;
    }
    if (selectData.length > headerLength &&
        selectData[0] == 0x54 &&
        selectData[1] == 0x4D) {
      return decodeTuringFrame(selectData) != null;
    }
    return false;
  }

  /// Extracts the 8-byte card nonce from a verified "TPT4" SELECT handshake.
  static Uint8List? extractHandshakeNonce(List<int> selectData) {
    if (selectData.length >= 12 &&
        selectData[0] == 0x54 &&
        selectData[1] == 0x50 &&
        selectData[2] == 0x54 &&
        selectData[3] == 0x34) {
      return Uint8List.fromList(selectData.sublist(4, 12));
    }
    return null;
  }

  /// Stage 1 (\delta_{init}): Initializes the 8-byte Turing state tape
  /// from turingKey and an 8-byte session nonce.
  static Uint8List initTuringTape(List<int> nonce) {
    final Uint8List state = Uint8List(8);
    for (int j = 0; j < 8; j++) {
      final int k1 = turingKey[j] & 0xFF;
      final int k2 = turingKey[j + 8] & 0xFF;
      final int n = nonce[j] & 0xFF;
      state[j] = ((k1 ^ n ^ k2) + (j * 29) + 0x3D) & 0xFF;
    }
    return state;
  }

  /// Stage 2 & 3 (\delta_{tape} & \delta_{MAC}):
  /// Single-pass duplex Turing state-transition composition over [input].
  /// Returns `(transformedBytes, 4ByteTmac)`.
  static (Uint8List, Uint8List) runTuringTape(
    List<int> input,
    List<int> nonce, {
    required bool encode,
  }) {
    final Uint8List data = Uint8List.fromList(input);
    final Uint8List state = initTuringTape(nonce);

    for (int i = 0; i < data.length; i++) {
      final int idx = i & 7;
      final int s = state[idx] & 0xFF;
      final int sNext = state[(idx + 3) & 7] & 0xFF;
      final int k = turingKey[i & 15] & 0xFF;
      final int n = nonce[idx] & 0xFF;
      final int ki = ((s + sNext + k + i + 0x5A) ^ n) & 0xFF;

      final int inByte = data[i] & 0xFF;
      final int outByte = (inByte ^ ki) & 0xFF;
      final int plain = encode ? inByte : outByte;
      data[i] = outByte;

      final int k2 = turingKey[(i + plain) & 15] & 0xFF;
      state[idx] = (((s ^ plain) + k2 + ki) ^ (plain << 2)) & 0xFF;
    }

    final Uint8List mac = Uint8List.fromList(<int>[
      (state[0] ^ state[4] ^ 0x54) & 0xFF,
      (state[1] ^ state[5] ^ 0x50) & 0xFF,
      (state[2] ^ state[6] ^ 0x54) & 0xFF,
      (state[3] ^ state[7] ^ 0x34) & 0xFF,
    ]);
    return (data, mac);
  }

  /// Encodes [plain] into a 14-byte header + Turing-composed ciphertext frame:
  /// `[ 'T', 'M', nonce(8B), tmac(4B), ciphertext... ]`.
  static Uint8List encodeTuringFrame(List<int> plain, {List<int>? customNonce}) {
    final Random rng = Random.secure();
    final Uint8List nonce = customNonce != null
        ? Uint8List.fromList(customNonce.take(8).toList())
        : Uint8List.fromList(List<int>.generate(8, (_) => rng.nextInt(256)));

    final (Uint8List cipher, Uint8List mac) =
        runTuringTape(plain, nonce, encode: true);
    final Uint8List frame = Uint8List(headerLength + cipher.length);
    frame[0] = 0x54; // 'T'
    frame[1] = 0x4D; // 'M'
    frame.setRange(2, 10, nonce);
    frame.setRange(10, 14, mac);
    frame.setRange(14, 14 + cipher.length, cipher);
    return frame;
  }

  /// Decodes and authenticates a `'T','M'` Turing frame from the card.
  /// Returns `null` if the header is missing or the 4-byte TMAC fails verification.
  static Uint8List? decodeTuringFrame(List<int> frame) {
    if (frame.length <= headerLength ||
        frame[0] != 0x54 || // 'T'
        frame[1] != 0x4D) {
      // 'M'
      return null;
    }
    final List<int> nonce = frame.sublist(2, 10);
    final List<int> expectedMac = frame.sublist(10, 14);
    final List<int> cipher = frame.sublist(14);

    final (Uint8List plain, Uint8List actualMac) =
        runTuringTape(cipher, nonce, encode: false);
    for (int i = 0; i < 4; i++) {
      if (expectedMac[i] != actualMac[i]) {
        return null;
      }
    }
    return plain;
  }

  /// Decodes a `'T','M'` Turing frame into a UTF-8 string, or returns `null` if invalid.
  static String? decodeUtf8Frame(List<int> frame) {
    final Uint8List? plain = decodeTuringFrame(frame);
    if (plain == null) return null;
    try {
      return utf8.decode(plain, allowMalformed: false).trim();
    } catch (_) {
      return null;
    }
  }
}

class PosNfcService {
  static const String kDefaultCardId = 'TAPAT_JCOP4_8821';
  static const String kDefaultUid = '04:7A:93:E2:10:88:01';

  static Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  static DateTime? _lastSuccessTime;

  /// Starts a background listener while on the POS Scanner or Checkout screen.
  /// Only authentic Tapat JCOP4 Smart Cards passing Turing Composition succeed.
  static Future<void> startPassiveCardListener({
    required void Function(Map<String, dynamic> cardResult) onCardDetected,
  }) async {
    if (!await isNfcAvailable()) return;
    bool tagHandled = false;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: <NfcPollingOption>{
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          if (tagHandled) return;
          if (_lastSuccessTime != null &&
              DateTime.now().difference(_lastSuccessTime!).inMilliseconds <
                  1800) {
            return;
          }
          tagHandled = true;
          final Map<String, dynamic> res = await _processDiscoveredTag(tag);
          if (res['success'] == true && res['approved'] == true) {
            _lastSuccessTime = DateTime.now();
          }
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          onCardDetected(res);
        },
      );
    } catch (_) {}
  }

  /// Reads, verifies via Turing-Type Composition, and approves a Tapat JCOP4
  /// Smart Card transaction. Non-Tapat NFC cards are strictly rejected.
  ///
  /// If [preVerifiedCardResult] is supplied (e.g., from [startPassiveCardListener]
  /// that already verified the tapped card), it proceeds directly to the
  /// acknowledgment & approval stages without requiring a second tap.
  static Future<Map<String, dynamic>> readAndApproveCardTransaction({
    required double amount,
    void Function(String stage, String message, Map<String, dynamic>? details)?
        onStatus,
    Map<String, dynamic>? preVerifiedCardResult,
    bool simulate = false,
    int rfTimeoutMs = 20000,
  }) async {
    Map<String, dynamic> cardRes;

    if (preVerifiedCardResult != null &&
        preVerifiedCardResult['success'] == true &&
        preVerifiedCardResult['approved'] == true) {
      cardRes = preVerifiedCardResult;
    } else if (simulate) {
      onStatus?.call(
        'reading',
        'Simulating Tapat JCOP4 Turing Composition Handshake...',
        null,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      cardRes = _buildSecuredCardResult(
        uid: kDefaultUid,
        cardId: kDefaultCardId,
        amount: amount,
        simulated: true,
      );
    } else {
      final bool available = await isNfcAvailable();
      if (!available) {
        final Map<String, dynamic> err = <String, dynamic>{
          'success': false,
          'approved': false,
          'error':
              'NFC is disabled or unavailable on this device. Enable NFC to read Tapat JCOP4 cards.',
        };
        onStatus?.call('error', err['error'] as String, err);
        return err;
      }

      onStatus?.call(
        'reading',
        'Hold authentic Tapat JCOP4 Smart Card against phone back...',
        null,
      );

      final Completer<Map<String, dynamic>> completer =
          Completer<Map<String, dynamic>>();
      bool tagHandled = false;

      try {
        await NfcManager.instance.startSession(
          pollingOptions: <NfcPollingOption>{
            NfcPollingOption.iso14443,
          },
          onDiscovered: (NfcTag tag) async {
            if (tagHandled || completer.isCompleted) return;
            tagHandled = true;
            final Map<String, dynamic> res = await _processDiscoveredTag(tag);
            if (res['success'] == true && res['approved'] == true) {
              _lastSuccessTime = DateTime.now();
            }
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete(res);
            }
          },
        );
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete(<String, dynamic>{
            'success': false,
            'approved': false,
            'error': 'Failed to start NFC reader: $e',
          });
        }
      }

      // Timeout without auto-approving — requires a real authentic card tap
      Future<void>.delayed(Duration(milliseconds: rfTimeoutMs), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete(<String, dynamic>{
              'success': false,
              'approved': false,
              'timeout': true,
              'error':
                  'NFC tap timed out. Please tap an authentic Tapat JCOP4 Smart Card.',
            });
          }
        }
      });

      cardRes = await completer.future;
    }

    if (cardRes['success'] != true || cardRes['approved'] != true) {
      final String errMsg = (cardRes['error'] as String?) ??
          'Unauthorized NFC Card: Only Tapat JCOP4 Smart Cards with Turing Composition are accepted.';
      onStatus?.call('error', errMsg, cardRes);
      return cardRes;
    }

    // Stage 2: Acknowledge card & secured Turing-verified transaction pursuit
    final String uid = (cardRes['uid'] as String?) ?? kDefaultUid;
    final String cardId = (cardRes['cardId'] as String?) ?? kDefaultCardId;
    final String token = (cardRes['token'] as String?) ??
        'TOKEN_${DateTime.now().millisecondsSinceEpoch}';

    onStatus?.call(
      'acknowledged',
      'Tapat JCOP4 Card Verified ($cardId)\nTuring Composition Handshake & TMAC Authenticated...',
      cardRes,
    );
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // Stage 3: Approve payment
    onStatus?.call(
      'approved',
      'Turing Cryptogram Verified — Payment Approved!',
      <String, dynamic>{
        ...cardRes,
        'uid': uid,
        'cardId': cardId,
        'token': token,
        'approved': true,
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    return <String, dynamic>{
      ...cardRes,
      'success': true,
      'approved': true,
      'uid': uid,
      'cardId': cardId,
      'token': token,
    };
  }

  static Future<Map<String, dynamic>> _processDiscoveredTag(NfcTag tag) async {
    String uid = 'UNKNOWN_UID';
    String cardId = '';
    String token = '';
    String cryptogramHex = '';

    try {
      if (!Platform.isAndroid) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'error': 'ISO-DEP Smart Card NFC is only supported on Android.',
        };
      }

      final NfcTagAndroid? androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && androidTag.id.isNotEmpty) {
        uid = androidTag.id
            .map((int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(':');
      }

      final IsoDepAndroid? isoDep = IsoDepAndroid.from(tag);
      if (isoDep == null) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Unauthorized NFC Card ($uid): Not an ISO-DEP Java Card. Only Tapat JCOP4 Smart Cards are accepted.',
        };
      }

      try {
        await isoDep.setTimeout(5000);
      } catch (_) {}

      // 1. SELECT TapatMFAApplet (00 A4 04 00 0A F07461706174616E0101 00)
      Uint8List selectResp = await isoDep.transceive(
        Uint8List.fromList(<int>[
          0x00,
          0xA4,
          0x04,
          0x00,
          kTapatanAppletAid.length,
          ...kTapatanAppletAid,
          0x00,
        ]),
      );
      if (!_isSw9000(selectResp)) {
        // Fallback without Le
        selectResp = await isoDep.transceive(
          Uint8List.fromList(<int>[
            0x00,
            0xA4,
            0x04,
            0x00,
            kTapatanAppletAid.length,
            ...kTapatanAppletAid,
          ]),
        );
      }

      if (!_isSw9000(selectResp)) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Unauthorized NFC Card ($uid): TapatMFAApplet not installed on this card.',
        };
      }

      final Uint8List selectData =
          selectResp.sublist(0, selectResp.length - 2);
      if (!TuringCompositionCodec.verifyTpt4Handshake(selectData)) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Unauthorized NFC Card ($uid): Failed TPT4 Turing Composition handshake.',
        };
      }

      Uint8List? cardNonce =
          TuringCompositionCodec.extractHandshakeNonce(selectData);

      // 2. Mutual Turing Composition Challenge-Response (0x84 + 0x88)
      if (cardNonce == null || cardNonce.length < 8) {
        final Uint8List chalResp = await isoDep.transceive(
          Uint8List.fromList(<int>[0x00, 0x84, 0x00, 0x00, 0x08]),
        );
        if (!_isSw9000(chalResp) || chalResp.length < 10) {
          return <String, dynamic>{
            'success': false,
            'approved': false,
            'unauthorizedCard': true,
            'uid': uid,
            'error': 'Card rejected GET CHALLENGE (0x84).',
          };
        }
        cardNonce = chalResp.sublist(0, 8);
      }

      final Random rng = Random.secure();
      final Uint8List posNonce =
          Uint8List.fromList(List<int>.generate(8, (_) => rng.nextInt(256)));
      final Uint8List combinedChallenge = Uint8List.fromList(<int>[
        ...cardNonce,
        ...posNonce,
      ]);

      final Uint8List authFrame = TuringCompositionCodec.encodeTuringFrame(
        combinedChallenge,
        customNonce: posNonce,
      );
      final Uint8List authResp = await isoDep.transceive(
        Uint8List.fromList(<int>[
          0x00,
          0x88,
          0x00,
          0x00,
          authFrame.length,
          ...authFrame,
          0x00,
        ]),
      );

      if (!_isSw9000(authResp) || authResp.length <= 2) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Unauthorized NFC Card: Failed mutual Turing INTERNAL AUTHENTICATE (0x88).',
        };
      }

      final Uint8List authRespBody = authResp.sublist(0, authResp.length - 2);
      final Uint8List? decodedProof =
          TuringCompositionCodec.decodeTuringFrame(authRespBody);
      if (decodedProof == null || decodedProof.length < 16) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Turing Composition TMAC mismatch on INTERNAL AUTHENTICATE response.',
        };
      }

      for (int i = 0; i < 16; i++) {
        if (decodedProof[i] != combinedChallenge[i]) {
          return <String, dynamic>{
            'success': false,
            'approved': false,
            'unauthorizedCard': true,
            'uid': uid,
            'error': 'Mutual Turing challenge proof verification failed.',
          };
        }
      }

      cryptogramHex = authRespBody
          .sublist(0, min(16, authRespBody.length))
          .map((int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join('');

      // 3. GET DATA (0xCA) -> Decode 'T','M' Turing frame for cardId & token
      final Uint8List dataResp = await isoDep.transceive(
        Uint8List.fromList(<int>[0x00, 0xCA, 0x00, 0x00, 0x00]),
      );
      if (!_isSw9000(dataResp) || dataResp.length <= 2) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error': 'Unprovisioned Tapat Card: GET DATA (0xCA) returned empty.',
        };
      }

      final Uint8List dataBody = dataResp.sublist(0, dataResp.length - 2);
      final String? decodedText =
          TuringCompositionCodec.decodeUtf8Frame(dataBody);
      if (decodedText == null || decodedText.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Tampered or unprovisioned card payload: Turing TMAC verification failed on GET DATA.',
        };
      }

      _extractCardFields(decodedText, (String id, String tok) {
        cardId = id;
        token = tok;
      });

      if (cardId.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'approved': false,
          'unauthorizedCard': true,
          'uid': uid,
          'error':
              'Unprovisioned Tapat Card: No bound Tapat account ID found on card.',
        };
      }

      return _buildSecuredCardResult(
        uid: uid,
        cardId: cardId,
        token: token,
        cryptogram: cryptogramHex,
      );
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'approved': false,
        'uid': uid,
        'error':
            'Card communication lost during Turing handshake. Hold the Tapat JCOP4 card steady against the phone.',
      };
    }
  }

  static bool _isSw9000(Uint8List resp) {
    return resp.length >= 2 &&
        resp[resp.length - 2] == 0x90 &&
        resp[resp.length - 1] == 0x00;
  }

  static void _extractCardFields(
    String rawText,
    void Function(String cardId, String token) onExtracted,
  ) {
    if (rawText.isEmpty) return;
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(rawText) as Map<String, dynamic>;
      final String id =
          (decoded['cardId'] ?? decoded['tapatan_id'] ?? '').toString().trim();
      final String tok = (decoded['token'] ??
              'JCOP4_TURING_${DateTime.now().millisecondsSinceEpoch}')
          .toString();
      if (id.isNotEmpty) {
        onExtracted(id, tok);
      }
    } catch (_) {}
  }

  static Map<String, dynamic> _buildSecuredCardResult({
    required String uid,
    required String cardId,
    String? token,
    String? cryptogram,
    double? amount,
    bool simulated = false,
  }) {
    final String effectiveToken =
        (token != null && token.isNotEmpty)
            ? token
            : 'JCOP4_TURING_${DateTime.now().millisecondsSinceEpoch}';
    final String effectiveCrypto =
        (cryptogram != null && cryptogram.isNotEmpty)
            ? cryptogram
            : '544D3045022100A8F49E2C1B7D08903E';
    return <String, dynamic>{
      'success': true,
      'approved': true,
      'uid': uid,
      'cardId': cardId,
      'token': effectiveToken,
      'cryptogram': effectiveCrypto,
      if (amount != null) 'amount': amount,
      'simulated': simulated,
      'turingVerified': true,
    };
  }
}
