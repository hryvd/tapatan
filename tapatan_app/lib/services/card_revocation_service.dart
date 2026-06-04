import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CardRevocationService {
  static const String revocationKey = "snfc_revoked_cards";
  static const String useCountKey = "snfc_card_use_count";
  static const String lastTapKey = "snfc_card_last_tap";
  static const String cardPinKey = "snfc_card_pin";

  // ── Revocation ────────────────────────────────────────────────────────────────

  static Future<List<String>> getRevokedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(revocationKey);
    if (raw != null) {
      try {
        List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<bool> isRevoked(String cardUid) async {
    final list = await getRevokedCards();
    return list.contains(cardUid);
  }

  static Future<void> revokeCard(String cardUid) async {
    final list = await getRevokedCards();
    if (!list.contains(cardUid)) {
      list.push(cardUid);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(revocationKey, jsonEncode(list));
    }
  }

  static Future<void> unRevokeCard(String cardUid) async {
    final list = await getRevokedCards();
    list.remove(cardUid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(revocationKey, jsonEncode(list));
  }

  // ── Card Health ───────────────────────────────────────────────────────────────

  static Future<void> incrementUseCount(String cardId) async {
    final counts = await getUseCounts();
    counts[cardId] = (counts[cardId] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(useCountKey, jsonEncode(counts));
  }

  static Future<int> getUseCount(String cardId) async {
    final counts = await getUseCounts();
    return counts[cardId] ?? 0;
  }

  static Future<Map<String, int>> getUseCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(useCountKey);
    if (raw != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(raw);
        return decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }
    return {};
  }

  static Future<void> recordLastTap(String cardId) async {
    final taps = await getLastTaps();
    taps[cardId] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastTapKey, jsonEncode(taps));
  }

  static Future<int?> getLastTap(String cardId) async {
    final taps = await getLastTaps();
    return taps[cardId];
  }

  static Future<Map<String, int>> getLastTaps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(lastTapKey);
    if (raw != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(raw);
        return decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }
    return {};
  }

  // ── Card PIN Fallback ─────────────────────────────────────────────────────────

  static String simpleHash(String pin) {
    int hash = 0;
    for (int i = 0; i < pin.length; i++) {
      hash = ((hash << 5) - hash + pin.codeUnitAt(i)) | 0;
    }
    return hash.toRadixString(16);
  }

  static Future<void> setCardPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cardPinKey, simpleHash(pin));
  }

  static Future<bool> verifyCardPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(cardPinKey);
    if (stored == null) return false;
    return stored == simpleHash(pin);
  }

  static Future<bool> hasCardPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(cardPinKey);
  }
}

extension ListExtension<T> on List<T> {
  void push(T element) => add(element);
}
