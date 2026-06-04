import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:ndef_record/ndef_record.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';

class TokenPayload {
  final String cardId;
  final double? amount;
  final String token;
  final DateTime timestamp;
  final int lastInputTime;

  TokenPayload({required this.cardId, this.amount, required this.token, required this.timestamp, required this.lastInputTime});

  factory TokenPayload.fromJson(Map<String, dynamic> json) {
    return TokenPayload(
      cardId: json['cardId'] ?? '',
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      token: json['token'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      lastInputTime: json['lastInputTime'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'amount': amount?.toString(),
    'token': token,
    'timestamp': timestamp.toIso8601String(),
    'lastInputTime': lastInputTime,
  };
}

class NfcService {
  
  static TokenPayload buildTokenPayload(String cardId, double? amount) {
    return TokenPayload(
      cardId: cardId,
      amount: amount,
      token: "TOKEN_${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now(),
      lastInputTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool isTokenValid(TokenPayload payload) {
    final diff = DateTime.now().difference(payload.timestamp);
    return diff.inMinutes < 5;
  }

  static NdefRecord createTextRecord(String text) {
    List<int> languageCode = utf8.encode('en');
    List<int> textBytes = utf8.encode(text);
    
    List<int> payload = [languageCode.length];
    payload.addAll(languageCode);
    payload.addAll(textBytes);
    
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List.fromList([]),
      payload: Uint8List.fromList(payload)
    );
  }

  static Future<Map<String, dynamic>> writeTokenToNfc(TokenPayload payload) async {
    Completer<Map<String, dynamic>> completer = Completer();
    
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return {'success': false, 'error': 'NFC not available'};
      }

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            NdefAndroid? ndefAndroid = Platform.isAndroid ? NdefAndroid.from(tag) : null;
            NdefIos? ndefIos = Platform.isIOS ? NdefIos.from(tag) : null;

            if (ndefAndroid == null && ndefIos == null) {
              NfcManager.instance.stopSession(errorMessageIos: 'Tag is not NDEF formatted.');
              if (!completer.isCompleted) completer.complete({'success': false, 'error': 'Tag is not ndef'});
              return;
            }

            bool isWritable = false;
            if (ndefAndroid != null) {
              isWritable = ndefAndroid.isWritable;
            } else if (ndefIos != null) {
              isWritable = ndefIos.status == NdefStatusIos.readWrite;
            }
            if (!isWritable) {
              NfcManager.instance.stopSession(errorMessageIos: 'Tag is read-only.');
              if (!completer.isCompleted) completer.complete({'success': false, 'error': 'Tag is read only'});
              return;
            }

            String serialized = jsonEncode(payload.toJson());

            NdefMessage message = NdefMessage(records: [
              createTextRecord(serialized),
            ]);

            if (ndefAndroid != null) {
              await ndefAndroid.writeNdefMessage(message);
            } else if (ndefIos != null) {
              await ndefIos.writeNdef(message);
            }

            NfcManager.instance.stopSession(alertMessageIos: 'Token written to card successfully!');
            if (!completer.isCompleted) completer.complete({'success': true});
          } catch (e) {
            String errorMsg = e.toString();
            NfcManager.instance.stopSession(errorMessageIos: errorMsg);
            if (!completer.isCompleted) completer.complete({'success': false, 'error': errorMsg});
          }
      });
      
      // Wait timeout
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          NfcManager.instance.stopSession(errorMessageIos: 'Timeout');
          completer.complete({'success': false, 'error': 'Timeout'});
        }
      });
      
    } catch (e) {
      if (!completer.isCompleted) completer.complete({'success': false, 'error': e.toString()});
    }
    
    return completer.future;
  }

  static Future<Map<String, dynamic>> readTagFromNfc() async {
    Completer<Map<String, dynamic>> completer = Completer();
    
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return {'success': false, 'error': 'NFC not available'};
      }

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            NdefAndroid? ndefAndroid = Platform.isAndroid ? NdefAndroid.from(tag) : null;
            NdefIos? ndefIos = Platform.isIOS ? NdefIos.from(tag) : null;

            if (ndefAndroid == null && ndefIos == null) {
              NfcManager.instance.stopSession(errorMessageIos: 'Tag is not NDEF formatted.');
              if (!completer.isCompleted) completer.complete({'success': false, 'error': 'Tag is not ndef'});
              return;
            }

            NdefMessage? cachedMessage = ndefAndroid?.cachedNdefMessage ?? ndefIos?.cachedNdefMessage;
            
            if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
              var record = cachedMessage.records.first;
              
              if (record.typeNameFormat == TypeNameFormat.wellKnown && record.type.length == 1 && record.type.first == 0x54) {
                int languageCodeLength = record.payload.first;
                String text = utf8.decode(record.payload.sublist(1 + languageCodeLength));
                
                NfcManager.instance.stopSession(alertMessageIos: 'Card read successfully');
                if (!completer.isCompleted) completer.complete({'success': true, 'text': text});
                return;
              }
            }
            
            NfcManager.instance.stopSession(errorMessageIos: 'Empty card');
            if (!completer.isCompleted) completer.complete({'success': false, 'error': 'Empty card'});
          } catch (e) {
            NfcManager.instance.stopSession(errorMessageIos: e.toString());
            if (!completer.isCompleted) completer.complete({'success': false, 'error': e.toString()});
          }
      });
      
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          NfcManager.instance.stopSession(errorMessageIos: 'Timeout');
          completer.complete({'success': false, 'error': 'Timeout'});
        }
      });

    } catch (e) {
      if (!completer.isCompleted) completer.complete({'success': false, 'error': e.toString()});
    }
    
    return completer.future;
  }
}
