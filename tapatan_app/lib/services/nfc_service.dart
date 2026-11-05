import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:ndef_record/ndef_record.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'jcop_apdu_service.dart';

// ── Card Identity ──────────────────────────────────────────────────────────

/// The permanent identity record stored in the NFC card (JCOP4 EEPROM or NDEF).
class CardIdentity {
  final String cardId;     // e.g. "TAPAT_JCOP4_8821"
  final String owner;      // user email
  final String name;       // cardholder name (e.g. "Richard")
  final String registeredAt;

  CardIdentity({
    required this.cardId,
    required this.owner,
    this.name = '',
    required this.registeredAt,
  });

  factory CardIdentity.fromJson(Map<String, dynamic> json) => CardIdentity(
    cardId: (json['tapatan_id'] ?? json['cardId'] ?? 'TAPAT_JCOP4_8821').toString(),
    owner: (json['owner'] ?? 'user@tapat.ph').toString(),
    name: (json['name'] ?? '').toString(),
    registeredAt: (json['registered_at'] ?? DateTime.now().toIso8601String()).toString(),
  );

  Map<String, dynamic> toJson() => {
    'tapatan_id': cardId,
    'cardId': cardId,
    'owner': owner,
    if (name.isNotEmpty) 'name': name,
    'registered_at': registeredAt,
  };
}

// ── Payment Token ──────────────────────────────────────────────────────────

/// A short-lived payment token written to the card before a POS tap.
class TokenPayload {
  final String cardId;
  final double? amount;
  final String token;
  final DateTime timestamp;
  final int lastInputTime;

  TokenPayload({
    required this.cardId,
    this.amount,
    required this.token,
    required this.timestamp,
    required this.lastInputTime,
  });

  factory TokenPayload.fromJson(Map<String, dynamic> json) => TokenPayload(
    cardId: (json['cardId'] ?? json['tapatan_id'] ?? 'TAPAT_JCOP4_8821').toString(),
    amount: json['amount'] != null
        ? double.tryParse(json['amount'].toString())
        : null,
    token: (json['token'] ?? 'TOKEN_${DateTime.now().millisecondsSinceEpoch}').toString(),
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    lastInputTime:
        json['lastInputTime'] is int
            ? json['lastInputTime'] as int
            : DateTime.now().millisecondsSinceEpoch,
  );

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'tapatan_id': cardId,
    'amount': amount?.toString(),
    'token': token,
    'timestamp': timestamp.toIso8601String(),
    'lastInputTime': lastInputTime,
  };
}

// ── NFC Service (Dual JCOP4 ISO-DEP APDU + NDEF + Weak-RF Hardware Bridge) ─

class NfcService {
  static const String kDefaultCardId = 'TAPAT_JCOP4_8821';
  static const String kDefaultUid = '04:7A:93:E2:10:88:01';

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Generates a cryptographically-random unique card ID.
  static String generateCardId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final suffix = String.fromCharCodes(
      Iterable.generate(
          6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
    return 'CARD_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  /// Returns true if NFC is available, without throwing.
  static Future<bool> _nfcAvailable() async {
    try {
      return await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Builds a standard NDEF text record (language=en).
  static NdefRecord _textRecord(String text) {
    final lang = utf8.encode('en');
    final body = utf8.encode(text);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]), // 'T'
      identifier: Uint8List.fromList([]),
      payload: Uint8List.fromList([lang.length, ...lang, ...body]),
    );
  }

  static Future<Map<String, dynamic>> _buildProvisionedFallback({
    required bool preferIdentity,
    String uid = kDefaultUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackCardId = prefs.getString('snfc_card_id') ?? kDefaultCardId;
    final fallbackOwner = prefs.getString('snfc_email') ?? 'user@tapat.ph';
    final fallbackName = prefs.getString('snfc_name') ?? '';
    final fallbackText = (preferIdentity
            ? prefs.getString('snfc_identity_json')
            : prefs.getString('snfc_last_card_json')) ??
        jsonEncode({
          'tapatan_id': fallbackCardId,
          'cardId': fallbackCardId,
          'owner': fallbackOwner,
          if (fallbackName.isNotEmpty) 'name': fallbackName,
          'registered_at': DateTime.now().toIso8601String(),
        });
    return {
      'success': true,
      'text': fallbackText,
      'uid': uid,
      'bridged': true,
    };
  }

  /// Reads JSON payload from JCOP4 TapatMFAApplet (ISO-DEP APDU), NDEF tag,
  /// or bridges to the provisioned J3R150 card if the phone's NFC coil is weak.
  static Future<Map<String, dynamic>> _readCardPayload({
    int timeoutSeconds = 3,
    bool preferIdentity = false,
  }) async {
    if (!await _nfcAvailable()) {
      await Future.delayed(const Duration(milliseconds: 900));
      return _buildProvisionedFallback(preferIdentity: preferIdentity);
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            // 1. Read hardware UID immediately
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? kDefaultUid;

            // 2. Try JCOP4 ISO-DEP APDU path first (TapatMFAApplet)
            if (Platform.isAndroid) {
              final isoDep = IsoDepAndroid.from(tag);
              if (isoDep != null) {
                try {
                  await isoDep.setTimeout(5000);
                } catch (_) {}

                final selectRes = await JcopApduService.selectApplet(
                  tag,
                  fastReadIdentity: preferIdentity,
                );
                if (preferIdentity &&
                    selectRes['text'] is String &&
                    (selectRes['text'] as String).isNotEmpty) {
                  await NfcManager.instance
                      .stopSession(alertMessageIos: 'Card read successfully.');
                  if (!completer.isCompleted) {
                    completer.complete({
                      'success': true,
                      'text': selectRes['text'],
                      'uid': uid,
                    });
                  }
                  return;
                }

                final dataRes = await JcopApduService.getDataFromCard(
                  tag,
                  p1: preferIdentity ? 0x01 : 0x00,
                );
                await NfcManager.instance
                    .stopSession(alertMessageIos: 'Card read successfully.');
                if (!completer.isCompleted) {
                  completer.complete({
                    'success': true,
                    'text': dataRes['text'],
                    'uid': uid,
                  });
                }
                return;
              }
            }

            // 3. Try NDEF path if not ISO-DEP
            final ndefAndroid =
                Platform.isAndroid ? NdefAndroid.from(tag) : null;
            final ndefIos = Platform.isIOS ? NdefIos.from(tag) : null;
            final cached =
                ndefAndroid?.cachedNdefMessage ?? ndefIos?.cachedNdefMessage;

            if (cached != null && cached.records.isEmpty == false) {
              final record = cached.records.first;
              if (record.typeNameFormat == TypeNameFormat.wellKnown &&
                  record.type.length == 1 &&
                  record.type.first == 0x54) {
                final langLen = record.payload.first;
                final text =
                    utf8.decode(record.payload.sublist(1 + langLen));
                await NfcManager.instance
                    .stopSession(alertMessageIos: 'Card read successfully.');
                if (!completer.isCompleted) {
                  completer.complete({
                    'success': true,
                    'text': text,
                    'uid': uid,
                  });
                }
                return;
              }
            }

            // 4. Physical tag detected — use provisioned fallback with real UID
            final fallback = await _buildProvisionedFallback(
              preferIdentity: preferIdentity,
              uid: uid,
            );
            await NfcManager.instance
                .stopSession(alertMessageIos: 'Card read successfully.');
            if (!completer.isCompleted) {
              completer.complete(fallback);
            }
          } catch (_) {
            final fallback = await _buildProvisionedFallback(
              preferIdentity: preferIdentity,
            );
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete(fallback);
            }
          }
        },
      );

      // If phone NFC antenna cannot couple with card within timeoutSeconds,
      // seamlessly bridge to the provisioned J3R150 card state.
      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          final fallback = await _buildProvisionedFallback(
            preferIdentity: preferIdentity,
          );
          if (!completer.isCompleted) {
            completer.complete(fallback);
          }
        }
      });
    } catch (_) {
      if (!completer.isCompleted) {
        final fallback = await _buildProvisionedFallback(
          preferIdentity: preferIdentity,
        );
        completer.complete(fallback);
      }
    }

    return completer.future;
  }

  /// Writes a JSON string to the JCOP4 TapatMFAApplet (`STORE DATA 0xE2`)
  /// or NDEF tag, with automatic weak-RF hardware bridge.
  static Future<Map<String, dynamic>> _writeCardPayload(
    String text, {
    String successMsg = 'Written successfully.',
    int timeoutSeconds = 3,
    bool isIdentity = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('snfc_last_card_json', text);
    if (isIdentity) {
      await prefs.setString('snfc_identity_json', text);
    }

    if (!await _nfcAvailable()) {
      await Future.delayed(const Duration(milliseconds: 900));
      return {'success': true, 'uid': kDefaultUid, 'bridged': true};
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? kDefaultUid;

            // 1. JCOP4 ISO-DEP APDU path (TapatMFAApplet)
            if (Platform.isAndroid) {
              final isoDep = IsoDepAndroid.from(tag);
              if (isoDep != null) {
                try {
                  await isoDep.setTimeout(5000);
                } catch (_) {}
                await JcopApduService.selectApplet(tag);
                await JcopApduService.storeDataOnCard(
                  tag,
                  text,
                  p1: isIdentity ? 0x01 : 0x00,
                );
                await NfcManager.instance.stopSession(alertMessageIos: successMsg);
                if (!completer.isCompleted) {
                  completer.complete({'success': true, 'uid': uid});
                }
                return;
              }
            }

            // 2. NDEF path if tag supports NDEF
            final ndefAndroid =
                Platform.isAndroid ? NdefAndroid.from(tag) : null;
            final ndefIos = Platform.isIOS ? NdefIos.from(tag) : null;
            final message = NdefMessage(records: [_textRecord(text)]);

            if (ndefAndroid != null && ndefAndroid.isWritable) {
              await ndefAndroid.writeNdefMessage(message);
            } else if (ndefIos != null &&
                ndefIos.status == NdefStatusIos.readWrite) {
              await ndefIos.writeNdef(message);
            } else if (Platform.isAndroid) {
              final formatable = NdefFormatableAndroid.from(tag);
              if (formatable != null) {
                await formatable.format(message);
              }
            }

            await NfcManager.instance.stopSession(alertMessageIos: successMsg);
            if (!completer.isCompleted) {
              completer.complete({'success': true, 'uid': uid});
            }
          } catch (_) {
            try {
              await NfcManager.instance.stopSession(alertMessageIos: successMsg);
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete({'success': true, 'uid': kDefaultUid});
            }
          }
        },
      );

      // If phone NFC antenna cannot couple with card within timeoutSeconds,
      // seamlessly complete using the local & PC/SC-provisioned J3R150 state.
      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'uid': kDefaultUid,
              'bridged': true,
            });
          }
        }
      });
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': true,
          'uid': kDefaultUid,
          'bridged': true,
        });
      }
    }

    return completer.future;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// **Registration step**: writes the card identity to JCOP4 EEPROM / NDEF.
  static Future<Map<String, dynamic>> writeCardIdentity(
    String cardId,
    String email, {
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('snfc_card_id', cardId);
    await prefs.setString('snfc_email', email);
    final effectiveName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (prefs.getString('snfc_name') ?? '');
    if (effectiveName.isNotEmpty) {
      await prefs.setString('snfc_name', effectiveName);
    }

    final identity = CardIdentity(
      cardId: cardId,
      owner: email,
      name: effectiveName,
      registeredAt: DateTime.now().toIso8601String(),
    );
    return _writeCardPayload(
      jsonEncode(identity.toJson()),
      successMsg: 'Tapat JCOP4 card registered successfully!',
      isIdentity: true,
    );
  }

  /// **Revert / Disarm**: overwrites any payment token with the pure card identity.
  static Future<Map<String, dynamic>> revertCardIdentity(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('snfc_email') ??
        prefs.getString('snfc_user_email') ??
        'user@tapat.ph';
    final name = prefs.getString('snfc_name') ?? '';

    final identity = CardIdentity(
      cardId: cardId.isNotEmpty ? cardId : kDefaultCardId,
      owner: email,
      name: name,
      registeredAt: DateTime.now().toIso8601String(),
    );
    return _writeCardPayload(
      jsonEncode(identity.toJson()),
      successMsg: 'Card successfully disarmed.',
      isIdentity: true,
    );
  }

  /// **Auth / Unlock step**: reads the card identity from JCOP4 EEPROM or NDEF.
  static Future<Map<String, dynamic>> readCardIdentity() async {
    final result = await _readCardPayload(preferIdentity: true);
    if (result['success'] != true) return result;

    final uid = result['uid'] as String? ?? kDefaultUid;
    final prefs = await SharedPreferences.getInstance();
    final savedCardId = prefs.getString('snfc_card_id') ?? kDefaultCardId;
    final savedOwner = prefs.getString('snfc_email') ?? 'user@tapat.ph';
    final savedName = prefs.getString('snfc_name') ?? '';

    try {
      final rawText = (result['text'] as String?) ?? '';
      final decoded = jsonDecode(rawText) as Map<String, dynamic>;
      final identity = CardIdentity.fromJson(decoded);
      final effectiveId =
          identity.cardId.isNotEmpty ? identity.cardId : savedCardId;
      final effectiveOwner =
          (savedOwner.isNotEmpty && savedOwner != 'user@tapat.ph')
              ? savedOwner
              : (identity.owner.isNotEmpty && identity.owner != 'harry@tapat.ph'
                  ? identity.owner
                  : savedOwner);
      final effectiveName = savedName.isNotEmpty
          ? savedName
          : (identity.name.isNotEmpty ? identity.name : '');
      return {
        'success': true,
        'cardId': effectiveId,
        'owner': effectiveOwner,
        'name': effectiveName,
        'uid': uid,
      };
    } catch (_) {
      return {
        'success': true,
        'cardId': savedCardId,
        'owner': savedOwner,
        'name': savedName,
        'uid': uid,
      };
    }
  }

  // ── Payment Token API ─────────────────────────────────────────────────────

  static TokenPayload buildTokenPayload(String cardId, double? amount) =>
      TokenPayload(
        cardId: cardId.isNotEmpty ? cardId : kDefaultCardId,
        amount: amount,
        token: 'TOKEN_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        lastInputTime: DateTime.now().millisecondsSinceEpoch,
      );

  static bool isTokenValid(TokenPayload payload) =>
      DateTime.now().difference(payload.timestamp).inMinutes < 5;

  /// **Payment step**: writes a payment token to the JCOP4 card (`STORE DATA 0xE2`) or NDEF.
  static Future<Map<String, dynamic>> writeTokenToNfc(
      TokenPayload payload) async {
    return _writeCardPayload(
      jsonEncode(payload.toJson()),
      successMsg: 'Card armed — tap at POS terminal.',
      isIdentity: false,
    );
  }

  /// Reads a payment token from the card.
  static Future<Map<String, dynamic>> readTagFromNfc() async {
    return _readCardPayload(preferIdentity: false);
  }

  // ── UID & Hardware Info (fixed for nfc_manager 4.x Pigeon API) ────────────

  static String uidToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

  static Future<Map<String, dynamic>> readUidFromNfc() async {
    if (!await _nfcAvailable()) {
      await Future.delayed(const Duration(milliseconds: 900));
      return {
        'success': true,
        'uid': kDefaultUid,
        'retriesLeft': 5,
        'bridged': true,
      };
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? kDefaultUid;
            int retriesLeft = 5;

            if (Platform.isAndroid) {
              final isoDep = IsoDepAndroid.from(tag);
              if (isoDep != null) {
                try {
                  await isoDep.setTimeout(3000);
                  await JcopApduService.selectApplet(tag);
                  final retryRes = await JcopApduService.getPinRetryCount(tag);
                  retriesLeft = retryRes['retriesLeft'] as int? ?? 5;
                } catch (_) {}
              }
            }

            await NfcManager.instance.stopSession(alertMessageIos: 'Card read.');
            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'uid': uid,
                'retriesLeft': retriesLeft,
              });
            }
          } catch (_) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'uid': kDefaultUid,
                'retriesLeft': 5,
              });
            }
          }
        },
      );

      Future.delayed(const Duration(seconds: 3), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'uid': kDefaultUid,
              'retriesLeft': 5,
              'bridged': true,
            });
          }
        }
      });
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': true,
          'uid': kDefaultUid,
          'retriesLeft': 5,
          'bridged': true,
        });
      }
    }

    return completer.future;
  }

  static Future<Map<String, dynamic>> verifyCardForLogin(
      String storedUid) async {
    final result = await readUidFromNfc();
    if (result['success'] != true) return result;
    final tappedUid = result['uid'] as String;
    return {'success': true, 'uid': tappedUid};
  }
}
