import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Turing-Type Multi-Tape State-Transition Composition Codec
/// (\mathcal{T} = \delta_{MAC} \circ \delta_{tape} \circ \delta_{init}).
///
/// Mutually encodes, decodes, and authenticates APDU payloads between
/// the mobile terminal and TapatMFAApplet on the physical JCOP4 smart card.
/// Any non-Tapat card or forged/unencoded payload fails verification.
class TuringCompositionCodec {
  static const int headerLength = 14; // 'T', 'M' (2B) + Nonce (8B) + TMAC (4B)

  /// Shared 16-byte Hardware Key ("TAPAT_TURING_KEY") matching TapatMFAApplet.java
  static const List<int> turingKey = [
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
    // Also accept a valid 'T','M' Turing frame if SELECT P2=0x01 was used
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
    final state = Uint8List(8);
    for (int j = 0; j < 8; j++) {
      final k1 = turingKey[j] & 0xFF;
      final k2 = turingKey[j + 8] & 0xFF;
      final n = nonce[j] & 0xFF;
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
    final data = Uint8List.fromList(input);
    final state = initTuringTape(nonce);

    for (int i = 0; i < data.length; i++) {
      final idx = i & 7;
      final s = state[idx] & 0xFF;
      final sNext = state[(idx + 3) & 7] & 0xFF;
      final k = turingKey[i & 15] & 0xFF;
      final n = nonce[idx] & 0xFF;
      final ki = ((s + sNext + k + i + 0x5A) ^ n) & 0xFF;

      final inByte = data[i] & 0xFF;
      final outByte = (inByte ^ ki) & 0xFF;
      final plain = encode ? inByte : outByte;
      data[i] = outByte;

      final k2 = turingKey[(i + plain) & 15] & 0xFF;
      state[idx] = (((s ^ plain) + k2 + ki) ^ (plain << 2)) & 0xFF;
    }

    final mac = Uint8List.fromList([
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
    final rng = Random.secure();
    final nonce = customNonce != null
        ? Uint8List.fromList(customNonce.take(8).toList())
        : Uint8List.fromList(List<int>.generate(8, (_) => rng.nextInt(256)));

    final (cipher, mac) = runTuringTape(plain, nonce, encode: true);
    final frame = Uint8List(headerLength + cipher.length);
    frame[0] = 0x54; // 'T'
    frame[1] = 0x4D; // 'M'
    frame.setRange(2, 10, nonce);
    frame.setRange(10, 14, mac);
    frame.setRange(14, 14 + cipher.length, cipher);
    return frame;
  }

  /// Encodes a UTF-8 JSON string into a Turing frame.
  static Uint8List encodeJsonFrame(String jsonStr) {
    return encodeTuringFrame(utf8.encode(jsonStr));
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
    final nonce = frame.sublist(2, 10);
    final expectedMac = frame.sublist(10, 14);
    final cipher = frame.sublist(14);

    final (plain, actualMac) = runTuringTape(cipher, nonce, encode: false);
    for (int i = 0; i < 4; i++) {
      if (expectedMac[i] != actualMac[i]) {
        return null; // Forged or corrupted Turing frame
      }
    }
    return plain;
  }

  /// Decodes a `'T','M'` Turing frame into a UTF-8 string, or returns `null` if invalid.
  static String? decodeUtf8Frame(List<int> frame) {
    final plain = decodeTuringFrame(frame);
    if (plain == null) return null;
    try {
      return utf8.decode(plain, allowMalformed: false).trim();
    } catch (_) {
      return null;
    }
  }
}

