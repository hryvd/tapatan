import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jcop_apdu_service.dart';

// ── Card Identity ──────────────────────────────────────────────────────────

/// The permanent identity record stored in the TapatMFAApplet EEPROM.
class CardIdentity {
  final String cardId;     // e.g. "CARD_..."
  final String owner;      // registered user email
  final String name;       // registered cardholder name
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

  /// Global single-action lock so a single physical tap is never processed
  /// twice as two separate actions (e.g., sign-in + another sign-in).
  static bool _isBusy = false;
  static DateTime? _lastSuccessTime;

  static Future<void> stopSession({
    String? alertMessage,
    String? errorMessage,
  }) async {
    _isBusy = false;
    try {
      await NfcManager.instance.stopSession(
        alertMessageIos: alertMessage,
        errorMessageIos: errorMessage,
      );
    } catch (_) {}
  }

  static String get _holdCardInstruction => Platform.isIOS
      ? 'top of your iPhone'
      : 'back of the phone';

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
  /// over ISO-DEP in a single fast round-trip (`SELECT 0xA4` -> `"TPT4"` handshake
  /// -> `GET DATA 0xCA` -> `'T','M'` Turing frame + 4-byte `TMAC` verification).
  /// Any non-Tapat NFC card (MIFARE, NTAG, EMV bank card, etc.) is immediately rejected.
  /// Enforces a single-shot tag lock (`tagHandled`) so one tap never fires twice.
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

    if (_isBusy) {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
    }
    _isBusy = true;

    final completer = Completer<Map<String, dynamic>>();
    bool tagHandled = false;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        alertMessageIos:
            'Hold the top of your iPhone near your Tapat JCOP4 Smart Card.',
        onSessionErrorIos: (NfcReaderSessionErrorIos err) {
          if (!tagHandled && !completer.isCompleted) {
            _isBusy = false;
            completer.complete({
              'success': false,
              'cancelled': true,
              'error': err.message.isNotEmpty
                  ? err.message
                  : 'NFC scan cancelled.',
            });
          }
        },
        onDiscovered: (NfcTag tag) async {
          // Single-action guard: ignore any duplicate discovery callbacks from the same tap
          if (tagHandled || completer.isCompleted) return;
          tagHandled = true;

          try {
            // 1. Verify hardware UID & ISO-DEP / ISO-7816 transport (Android & iOS)
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            if (!Platform.isAndroid && !Platform.isIOS) {
              await stopSession(
                errorMessage: 'NFC smart card requires Android or iOS.',
              );
              if (!completer.isCompleted) {
                completer.complete({
                  'success': false,
                  'error':
                      'ISO-7816 TapatMFAApplet requires Android or iOS NFC.',
                });
              }
              return;
            }

            if (!JcopApduService.isIso7816SupportedTag(tag)) {
              await stopSession(
                errorMessage: 'Unauthorized card — Tapat JCOP4 required.',
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

            await JcopApduService.configureTagTimeout(tag, timeoutMs: 5000);

            // 2. Fast-path SELECT with P2=0x01 when reading identity (1 APDU total!)
            if (preferIdentity) {
              final fastSelect = await JcopApduService.selectApplet(
                tag,
                fastReadIdentity: true,
              );
              if (fastSelect['success'] == true &&
                  (fastSelect['identityText'] as String?)?.isNotEmpty == true) {
                _lastSuccessTime = DateTime.now();
                await stopSession(
                  alertMessage: 'Tapat JCOP4 Verified ✓',
                );
                if (!completer.isCompleted) {
                  completer.complete({
                    'success': true,
                    'text': fastSelect['identityText'],
                    'uid': uid,
                  });
                }
                return;
              }
            }

            // 3. Standard SELECT TapatMFAApplet & verify TPT4 Turing handshake
            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await stopSession(
                errorMessage: 'Unauthorized NFC card.',
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

            // 4. Read & decode Turing-composed data frame (INS 0xCA)
            final dataRes = await JcopApduService.getDataFromCard(
              tag,
              p1: preferIdentity ? 0x01 : 0x00,
            );
            if (dataRes['success'] != true) {
              await stopSession(
                errorMessage: 'Card verification failed.',
              );
              if (!completer.isCompleted) {
                completer.complete(dataRes);
              }
              return;
            }

            await stopSession(
              alertMessage: 'Tapat JCOP4 Verified ✓',
            );

            _lastSuccessTime = DateTime.now();
            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'text': dataRes['text'],
                'uid': uid,
              });
            }
          } catch (e) {
            await stopSession(
              errorMessage: 'NFC read interrupted — hold card steady.',
            );
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error':
                    'NFC read interrupted — hold your Tapat JCOP4 card steady against the $_holdCardInstruction.',
              });
            }
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          await stopSession(
            errorMessage: 'No Tapat JCOP4 card detected.',
          );
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the $_holdCardInstruction.',
            });
          }
        }
      });
    } catch (e) {
      await stopSession();
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
  /// Rejects any non-Tapat NFC card and enforces a single-shot tag lock.
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

    if (_isBusy) {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
    }
    _isBusy = true;

    final completer = Completer<Map<String, dynamic>>();
    bool tagHandled = false;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        alertMessageIos: isIdentity
            ? 'Hold the top of your iPhone near your Tapat JCOP4 Card to register.'
            : 'Hold the top of your iPhone near your Tapat JCOP4 Card to arm payment.',
        onSessionErrorIos: (NfcReaderSessionErrorIos err) {
          if (!tagHandled && !completer.isCompleted) {
            _isBusy = false;
            completer.complete({
              'success': false,
              'cancelled': true,
              'error': err.message.isNotEmpty
                  ? err.message
                  : 'NFC write cancelled.',
            });
          }
        },
        onDiscovered: (NfcTag tag) async {
          if (tagHandled || completer.isCompleted) return;
          tagHandled = true;

          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            if (!JcopApduService.isIso7816SupportedTag(tag)) {
              await stopSession(
                errorMessage: 'Unauthorized card — Tapat JCOP4 required.',
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

            await JcopApduService.configureTagTimeout(tag, timeoutMs: 5000);

            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await stopSession(
                errorMessage: 'Unauthorized NFC card.',
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
            if (storeRes['success'] != true) {
              await stopSession(
                errorMessage: 'Failed to write to card.',
              );
              if (!completer.isCompleted) {
                completer.complete(storeRes);
              }
              return;
            }

            await stopSession(alertMessage: successMsg);

            _lastSuccessTime = DateTime.now();
            if (!completer.isCompleted) {
              completer.complete({'success': true, 'uid': uid});
            }
          } catch (e) {
            await stopSession(
              errorMessage: 'NFC write interrupted — hold card steady.',
            );
            if (!completer.isCompleted) {
              completer.complete({
                'success': false,
                'error':
                    'NFC write interrupted — hold your Tapat JCOP4 card steady.',
              });
            }
          }
        },
      );

      Future.delayed(Duration(seconds: timeoutSeconds), () async {
        if (!completer.isCompleted) {
          await stopSession(
            errorMessage: 'No Tapat JCOP4 card detected.',
          );
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the $_holdCardInstruction.',
            });
          }
        }
      });
    } catch (e) {
      await stopSession();
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
    // Prevent duplicate sign-in read if a successful tap just completed within 2.5 seconds
    if (_lastSuccessTime != null &&
        DateTime.now().difference(_lastSuccessTime!).inMilliseconds < 1500) {
      final prefs = await SharedPreferences.getInstance();
      return {
        'success': true,
        'duplicateSuppressed': true,
        'cardId': prefs.getString('snfc_card_id') ?? kDefaultCardId,
        'owner': prefs.getString('snfc_email') ?? 'user@tapat.ph',
        'name': prefs.getString('snfc_name') ?? 'Cardholder',
        'uid': prefs.getString('snfc_jcop_uid') ?? kDefaultUid,
      };
    }

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
      // Strip legacy factory-default placeholder identity ("richard@tapat.ph" / "Richard")
      // so unprovisioned or token-overwritten JCOP4 cards never masquerade as "Richard".
      final isFactoryPlaceholder = identity.cardId == kDefaultCardId &&
          (identity.owner.toLowerCase() == 'richard@tapat.ph' ||
              identity.name.toLowerCase() == 'richard');
      final cleanOwner = isFactoryPlaceholder ? '' : identity.owner;
      final cleanName = isFactoryPlaceholder ? '' : identity.name;

      return {
        'success': true,
        'cardId': identity.cardId,
        'owner': cleanOwner,
        'name': cleanName,
        'uid': uid,
        'isFactoryDefault': isFactoryPlaceholder,
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
    bool tagHandled = false;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        alertMessageIos:
            'Hold the top of your iPhone near your Tapat JCOP4 Smart Card.',
        onSessionErrorIos: (NfcReaderSessionErrorIos err) {
          if (!tagHandled && !completer.isCompleted) {
            completer.complete({
              'success': false,
              'cancelled': true,
              'error': err.message.isNotEmpty
                  ? err.message
                  : 'NFC scan cancelled.',
            });
          }
        },
        onDiscovered: (NfcTag tag) async {
          if (tagHandled || completer.isCompleted) return;
          tagHandled = true;

          try {
            final uidRes = await JcopApduService.readCardUid(tag);
            final uid = uidRes['uid'] as String? ?? '';

            if (!JcopApduService.isIso7816SupportedTag(tag)) {
              await stopSession(
                errorMessage: 'Unauthorized card — Tapat JCOP4 required.',
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

            await JcopApduService.configureTagTimeout(tag, timeoutMs: 4000);

            final selectRes = await JcopApduService.selectApplet(tag);
            if (selectRes['success'] != true) {
              await stopSession(
                errorMessage: 'Unauthorized NFC card.',
              );
              if (!completer.isCompleted) {
                completer.complete(selectRes);
              }
              return;
            }

            final retryRes = await JcopApduService.getPinRetryCount(tag);
            final retriesLeft = retryRes['retriesLeft'] as int? ?? 5;

            await stopSession(
              alertMessage: 'Tapat JCOP4 Verified ✓',
            );
            if (!completer.isCompleted) {
              completer.complete({
                'success': true,
                'uid': uid,
                'retriesLeft': retriesLeft,
              });
            }
          } catch (e) {
            await stopSession(
              errorMessage: 'NFC read interrupted — hold card steady.',
            );
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
          await stopSession(
            errorMessage: 'No Tapat JCOP4 card detected.',
          );
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error':
                  'No Tapat JCOP4 Smart Card detected — hold your card steady against the $_holdCardInstruction.',
            });
          }
        }
      });
    } catch (e) {
      await stopSession();
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
