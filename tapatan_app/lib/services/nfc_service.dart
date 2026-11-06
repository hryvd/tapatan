import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jcop_apdu_service.dart';

// ── Card Identity ──────────────────────────────────────────────────────────

/// The permanent identity record stored in the TapatMFAApplet EEPROM.
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
        cardId:
            (json['tapatan_id'] ?? json['cardId'] ?? '').toString().trim(),
        owner: (json['owner'] ?? '').toString().trim(),
        name: (json['name'] ?? '').toString().trim(),
        registeredAt: (json['registered_at'] ??
                DateTime.now().toIso8601String())
            .toString(),
      );

  Map<String, dynamic> toJson() => {
        'tapatan_id': cardId,
        'cardId': cardId,
        'owner': owner,
        if (name.isNotEmpty) 'name': name,
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
        cardId: (json['cardId'] ??
                json['tapatan_id'] ??
                NfcService.kDefaultCardId)
            .toString(),
        amount: json['amount'] != null
            ? double.tryParse(json['amount'].toString())
            : null,
        token: (json['token'] ??
                'TOKEN_${DateTime.now().millisecondsSinceEpoch}')
            .toString(),
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        lastInputTime: json['lastInputTime'] is int
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

// ── Strict TapatMFAApplet JCOP4 NFC Service (Turing Composition) ──────────

class NfcService {
  static const String kDefaultCardId = 'TAPAT_JCOP4_8821';
  static const String kDefaultUid = '04:7A:93:E2:10:88:01';

  /// Generates a cryptographically-random unique card ID.
  static String generateCardId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final suffix = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(rng.nextInt(chars.length)),
      ),
    );
    return 'CARD_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  /// Returns true if NFC is available and enabled.
  static Future<bool> _nfcAvailable() async {
    try {
      return await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Strictly reads a Turing-composed JSON payload from `TapatMFAApplet`
  /// over ISO-DEP (`SELECT 0xA4` -> `"TPT4"` handshake -> `GET DATA 0xCA`
  /// -> `'T','M'` Turing frame + 4-byte `TMAC` verification -> `INTERNAL AUTHENTICATE 0x88`).
  /// Any non-Tapat NFC card (MIFARE, NTAG, EMV bank card, etc.) is immediately rejected.
  static Future<Map<String, dynamic>> _readCardPayload({
    int timeoutSeconds = 20,
    bool preferIdentity = false,
  }) async {
    if (!await _nfcAvailable()) {
      return {
        'success': false,
        'error':
            'NFC is disabled or unavailable on this device. Enable NFC in Settings to scan your Tapat JCOP4 card.',
      };
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            // 1. Verify hardware UID & ISO-DEP transport
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            if (!Platform.isAndroid) {
              await NfcManager.instance.stopSession();
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'error': 'ISO-DEP TapatMFAApplet requires Android NFC.',
                });
              }
              return;
            }

            final isoDep = IsoDepAndroid.from(tag);
            if (isoDep == null) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'unauthorizedCard': true,
                  'error':
                      'Unauthorized NFC Card: Only an authentic Tapat JCOP4 Smart Card with Turing Composition is supported.',
                });
              }
              return;
            }

            try {
              await isoDep.setTimeout(5000);
            } catch (_) {}

            // 2. Select TapatMFAApplet & verify TPT4 Turing handshake
            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'unauthorizedCard': true,
                  'error': selectRes['error'] ??
                      'Unauthorized NFC Card: TapatMFAApplet not found on this card.',
                });
              }
              return;
            }

            // 3. Mutual Turing Challenge-Response Authentication (INS 0x88)
            final cardNonce = selectRes['nonce'] as List<int>?;
            if (cardNonce != null && cardNonce.length >= 8) {
              final authRes = await JcopApduService.sendChallengeResponse(
                tag,
                selectRes['nonce'],
              );
              if (authRes['success'] != true) {
                await NfcManager.instance.stopSession(
                  errorMessageIos: 'Card authentication failed.',
                );
                if (!completer.isCompleted) {
                  completer.complete(authRes);
                }
                return;
              }
            }

            // 4. Read & decode Turing-composed data frame (INS 0xCA)
            final dataRes = await JcopApduService.getDataFromCard(
              tag,
              p1: preferIdentity ? 0x01 : 0x00,
            );
            await NfcManager.instance.stopSession(
              alertMessageIos: 'Authentic Tapat JCOP4 Card verified.',
            );

            if (dataRes['success'] != true) {
              if (!completer.isCompleted) {
                completer.complete(dataRes);
              }
              return;
            }

            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'text': dataRes['text'],
                'uid': uid,
              });
            }
          } catch (e) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error':
                    'NFC read interrupted — hold your Tapat JCOP4 card steady against the phone ($e).',
              });
            }
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the back of the phone and try again.',
            });
          }
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error': 'Failed to start NFC session: $e',
        });
      }
    }

    return completer.future;
  }

  /// Strictly writes a Turing-composed JSON frame to `TapatMFAApplet` (`STORE DATA 0xE2`).
  /// Rejects any non-Tapat NFC card.
  static Future<Map<String, dynamic>> _writeCardPayload(
    String text, {
    String successMsg = 'Written successfully.',
    int timeoutSeconds = 20,
    bool isIdentity = false,
  }) async {
    if (!await _nfcAvailable()) {
      return {
        'success': false,
        'error':
            'NFC is disabled or unavailable on this device. Enable NFC in Settings to provision your Tapat JCOP4 card.',
      };
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            final isoDep = Platform.isAndroid ? IsoDepAndroid.from(tag) : null;
            if (isoDep == null) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'unauthorizedCard': true,
                  'error':
                      'Unauthorized NFC Card: Only an authentic Tapat JCOP4 Smart Card with Turing Composition is supported.',
                });
              }
              return;
            }

            try {
              await isoDep.setTimeout(5000);
            } catch (_) {}

            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete(selectRes);
              }
              return;
            }

            final storeRes = await JcopApduService.storeDataOnCard(
              tag,
              text,
              p1: isIdentity ? 0x01 : 0x00,
            );
            await NfcManager.instance.stopSession(alertMessageIos: successMsg);

            if (storeRes['success'] != true) {
              if (!completer.isCompleted) {
                completer.complete(storeRes);
              }
              return;
            }

            if (!completer.isCompleted) {
              completer.complete({'success': true, 'uid': uid});
            }
          } catch (e) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error':
                    'NFC write interrupted — hold your Tapat JCOP4 card steady ($e).',
              });
            }
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the back of the phone and try again.',
            });
          }
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error': 'Failed to start NFC session: $e',
        });
      }
    }

    return completer.future;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// **Registration step**: writes the card identity to `TapatMFAApplet` EEPROM
  /// using a `'T','M'` Turing Composition frame.
  static Future<Map<String, dynamic>> writeCardIdentity(
    String cardId,
    String email, {
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (prefs.getString('snfc_name') ?? '');

    final identity = CardIdentity(
      cardId: cardId,
      owner: email,
      name: effectiveName,
      registeredAt: DateTime.now().toIso8601String(),
    );

    final writeRes = await _writeCardPayload(
      jsonEncode(identity.toJson()),
      successMsg: 'Tapat JCOP4 card registered successfully!',
      isIdentity: true,
    );

    if (writeRes['success'] == true) {
      await prefs.setString('snfc_card_id', cardId);
      await prefs.setString('snfc_email', email);
      if (effectiveName.isNotEmpty) {
        await prefs.setString('snfc_name', effectiveName);
      }
    }
    return writeRes;
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

  /// **Auth / Unlock step**: reads and Turing-decodes the card identity from `TapatMFAApplet`.
  static Future<Map<String, dynamic>> readCardIdentity() async {
    final result = await _readCardPayload(preferIdentity: true);
    if (result['success'] != true) return result;

    final uid = result['uid'] as String? ?? '';
    try {
      final rawText = (result['text'] as String?) ?? '';
      final decoded = jsonDecode(rawText) as Map<String, dynamic>;
      final identity = CardIdentity.fromJson(decoded);
      if (identity.cardId.isEmpty) {
        return {
          'success': false,
          'unauthorizedCard': true,
          'error':
              'Unauthorized NFC Card: Decoded Turing frame does not contain a valid Tapat cardId.',
        };
      }
      return {
        'success': true,
        'cardId': identity.cardId,
        'owner': identity.owner,
        'name': identity.name,
        'uid': uid,
      };
    } catch (e) {
      return {
        'success': false,
        'unauthorizedCard': true,
        'error':
            'Unauthorized NFC Card: Card payload is not a valid Tapat Turing identity record.',
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

  /// **Payment step**: writes a Turing-encoded payment token to `TapatMFAApplet` (`STORE DATA 0xE2`).
  static Future<Map<String, dynamic>> writeTokenToNfc(
    TokenPayload payload,
  ) async {
    return _writeCardPayload(
      jsonEncode(payload.toJson()),
      successMsg: 'Card armed — tap at POS terminal.',
      isIdentity: false,
    );
  }

  /// Reads a Turing-encoded payment token from the card.
  static Future<Map<String, dynamic>> readTagFromNfc() async {
    return _readCardPayload(preferIdentity: false);
  }

  // ── UID & Hardware Info (Strict Applet Check) ────────────────────────────

  static String uidToHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');

  static Future<Map<String, dynamic>> readUidFromNfc({
    int timeoutSeconds = 20,
  }) async {
    if (!await _nfcAvailable()) {
      return {
        'success': false,
        'error':
            'NFC is disabled or unavailable on this device. Enable NFC in Settings to scan your Tapat JCOP4 card.',
      };
    }

    final completer = Completer<Map<String, dynamic>>();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            final isoDep = Platform.isAndroid ? IsoDepAndroid.from(tag) : null;
            if (isoDep == null) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'unauthorizedCard': true,
                  'error':
                      'Unauthorized NFC Card: Only an authentic Tapat JCOP4 Smart Card with Turing Composition is supported.',
                });
              }
              return;
            }

            try {
              await isoDep.setTimeout(4000);
            } catch (_) {}

            // Strictly verify TapatMFAApplet + TPT4 handshake
            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Unauthorized NFC Card.',
              );
              if (!completer.isCompleted) {
                completer.complete(selectRes);
              }
              return;
            }

            final retryRes = await JcopApduService.getPinRetryCount(tag);
            final retriesLeft = retryRes['retriesLeft'] as int? ?? 5;

            await NfcManager.instance.stopSession(alertMessageIos: 'Card read.');
            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'uid': uid,
                'retriesLeft': retriesLeft,
              });
            }
          } catch (e) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error': 'NFC read interrupted — hold card steady ($e).',
              });
            }
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the back of the phone and try again.',
            });
          }
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error': 'Failed to start NFC session: $e',
        });
      }
    }

    return completer.future;
  }

  static Future<Map<String, dynamic>> verifyCardForLogin(
    String storedUid,
  ) async {
    final result = await readUidFromNfc();
    if (result['success'] != true) return result;
    final tappedUid = result['uid'] as String;
    if (storedUid.isNotEmpty &&
        tappedUid.isNotEmpty &&
        storedUid.toUpperCase() != tappedUid.toUpperCase()) {
      return {
        'success': false,
        'unauthorizedCard': true,
        'error':
            'Card Mismatch: This card ($tappedUid) is not bound to this account ($storedUid).',
      };
    }
    return {'success': true, 'uid': tappedUid};
  }
}
