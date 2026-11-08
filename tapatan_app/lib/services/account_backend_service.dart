import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_provider.dart';
import '../utils/lucide_icons.dart';

/// Centralized, configurable rules for Bantay / tap@tan Account Management.
/// Mirrors `tapatan_backend/config/account_rules.json` and can be configured
/// either in-app or synchronized with the dedicated Node.js backend.
class AccountManagementConfig {
  final String backendUrl;
  final bool useRemoteBackend;
  final double initialWalletBalance;
  final int pinMinLength;
  final int pinMaxLength;
  final int maxPinRetries;
  final bool requirePinOnEmailLogin;
  final bool strictCardToAccountBinding;
  final bool allowCardRebindOnSignup;
  final bool syncCardHolderNameWithAccount;

  const AccountManagementConfig({
    this.backendUrl = '',
    this.useRemoteBackend = false,
    this.initialWalletBalance = 5000.0,
    this.pinMinLength = 4,
    this.pinMaxLength = 6,
    this.maxPinRetries = 5,
    this.requirePinOnEmailLogin = true,
    this.strictCardToAccountBinding = true,
    this.allowCardRebindOnSignup = true,
    this.syncCardHolderNameWithAccount = true,
  });

  AccountManagementConfig copyWith({
    String? backendUrl,
    bool? useRemoteBackend,
    double? initialWalletBalance,
    int? pinMinLength,
    int? pinMaxLength,
    int? maxPinRetries,
    bool? requirePinOnEmailLogin,
    bool? strictCardToAccountBinding,
    bool? allowCardRebindOnSignup,
    bool? syncCardHolderNameWithAccount,
  }) {
    return AccountManagementConfig(
      backendUrl: backendUrl ?? this.backendUrl,
      useRemoteBackend: useRemoteBackend ?? this.useRemoteBackend,
      initialWalletBalance: initialWalletBalance ?? this.initialWalletBalance,
      pinMinLength: pinMinLength ?? this.pinMinLength,
      pinMaxLength: pinMaxLength ?? this.pinMaxLength,
      maxPinRetries: maxPinRetries ?? this.maxPinRetries,
      requirePinOnEmailLogin:
          requirePinOnEmailLogin ?? this.requirePinOnEmailLogin,
      strictCardToAccountBinding:
          strictCardToAccountBinding ?? this.strictCardToAccountBinding,
      allowCardRebindOnSignup:
          allowCardRebindOnSignup ?? this.allowCardRebindOnSignup,
      syncCardHolderNameWithAccount:
          syncCardHolderNameWithAccount ?? this.syncCardHolderNameWithAccount,
    );
  }

  Map<String, dynamic> toJson() => {
        'backendUrl': backendUrl,
        'useRemoteBackend': useRemoteBackend,
        'initialWalletBalance': initialWalletBalance,
        'pinMinLength': pinMinLength,
        'pinMaxLength': pinMaxLength,
        'maxPinRetries': maxPinRetries,
        'requirePinOnEmailLogin': requirePinOnEmailLogin,
        'strictCardToAccountBinding': strictCardToAccountBinding,
        'allowCardRebindOnSignup': allowCardRebindOnSignup,
        'syncCardHolderNameWithAccount': syncCardHolderNameWithAccount,
      };

  factory AccountManagementConfig.fromJson(Map<String, dynamic> json) {
    return AccountManagementConfig(
      backendUrl: (json['backendUrl'] ?? '').toString().trim(),
      useRemoteBackend: json['useRemoteBackend'] == true,
      initialWalletBalance:
          (json['initialWalletBalance'] as num?)?.toDouble() ?? 5000.0,
      pinMinLength: (json['pinMinLength'] as num?)?.toInt() ?? 4,
      pinMaxLength: (json['pinMaxLength'] as num?)?.toInt() ?? 6,
      maxPinRetries: (json['maxPinRetries'] as num?)?.toInt() ?? 5,
      requirePinOnEmailLogin: json['requirePinOnEmailLogin'] != false,
      strictCardToAccountBinding: json['strictCardToAccountBinding'] != false,
      allowCardRebindOnSignup: json['allowCardRebindOnSignup'] != false,
      syncCardHolderNameWithAccount:
          json['syncCardHolderNameWithAccount'] != false,
    );
  }
}

/// Persistent stored account record in the multi-account database.
class AccountRecord {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String pinSalt;
  final String pinHash;
  final double balance;
  final String cardId;
  final String jcopCardUid;
  final String activeCardId;
  final List<CardData> virtualCards;
  final List<TransactionData> transactions;
  final int pinRetriesLeft;
  final String cardLifecycleState;
  final String createdAt;
  final String lastLoginAt;
  final String updatedAt;

  const AccountRecord({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.pinSalt,
    required this.pinHash,
    required this.balance,
    this.cardId = '',
    this.jcopCardUid = '',
    this.activeCardId = '',
    this.virtualCards = const [],
    this.transactions = const [],
    this.pinRetriesLeft = 5,
    this.cardLifecycleState = 'ENROLLED',
    required this.createdAt,
    required this.lastLoginAt,
    required this.updatedAt,
  });

  AccountRecord copyWith({
    String? name,
    String? email,
    String? phone,
    String? pinSalt,
    String? pinHash,
    double? balance,
    String? cardId,
    String? jcopCardUid,
    String? activeCardId,
    List<CardData>? virtualCards,
    List<TransactionData>? transactions,
    int? pinRetriesLeft,
    String? cardLifecycleState,
    String? lastLoginAt,
    String? updatedAt,
  }) {
    return AccountRecord(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      balance: balance ?? this.balance,
      cardId: cardId ?? this.cardId,
      jcopCardUid: jcopCardUid ?? this.jcopCardUid,
      activeCardId: activeCardId ?? this.activeCardId,
      virtualCards: virtualCards ?? this.virtualCards,
      transactions: transactions ?? this.transactions,
      pinRetriesLeft: pinRetriesLeft ?? this.pinRetriesLeft,
      cardLifecycleState: cardLifecycleState ?? this.cardLifecycleState,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'pinSalt': pinSalt,
        'pinHash': pinHash,
        'balance': balance,
        'cardId': cardId,
        'jcopCardUid': jcopCardUid,
        'activeCardId': activeCardId,
        'virtualCards': virtualCards.map((c) => c.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'pinRetriesLeft': pinRetriesLeft,
        'cardLifecycleState': cardLifecycleState,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
        'updatedAt': updatedAt,
      };

  factory AccountRecord.fromJson(
    Map<String, dynamic> json, {
    String fallbackSalt = '',
    String fallbackPinHash = '',
  }) {
    final rawName = (json['name'] ?? '').toString().trim();
    final rawBalance = (json['balance'] as num?)?.toDouble() ?? 0.0;
    final rawCards = (json['virtualCards'] as List?)
            ?.map((e) => CardData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <CardData>[];
    final rawTx = (json['transactions'] as List?)
            ?.map((e) =>
                TransactionData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <TransactionData>[];
    final nowIso = DateTime.now().toIso8601String();

    return AccountRecord(
      id: (json['id'] ?? 'acc_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      name: rawName,
      email: (json['email'] ?? '').toString().trim().toLowerCase(),
      phone: (json['phone'] ?? '').toString().trim(),
      pinSalt: (json['pinSalt'] ?? fallbackSalt).toString(),
      pinHash: (json['pinHash'] ?? fallbackPinHash).toString(),
      balance: rawBalance,
      cardId: (json['cardId'] ?? '').toString().trim(),
      jcopCardUid: (json['jcopCardUid'] ?? '').toString().trim().toUpperCase(),
      activeCardId: (json['activeCardId'] ?? '').toString().trim(),
      virtualCards: rawCards,
      transactions: rawTx,
      pinRetriesLeft: (json['pinRetriesLeft'] as num?)?.toInt() ?? 5,
      cardLifecycleState:
          (json['cardLifecycleState'] ?? 'ENROLLED').toString(),
      createdAt: (json['createdAt'] ?? nowIso).toString(),
      lastLoginAt: (json['lastLoginAt'] ?? nowIso).toString(),
      updatedAt: (json['updatedAt'] ?? nowIso).toString(),
    );
  }
}

class AccountSummary {
  final String name;
  final String email;
  final String cardId;
  final String jcopCardUid;
  final double balance;
  final int transactionCount;
  final String lastLoginAt;

  const AccountSummary({
    required this.name,
    required this.email,
    required this.cardId,
    required this.jcopCardUid,
    required this.balance,
    required this.transactionCount,
    required this.lastLoginAt,
  });
}

class AccountAuthResult {
  final bool success;
  final AccountRecord? account;
  final String? error;

  const AccountAuthResult({
    required this.success,
    this.account,
    this.error,
  });
}

/// Persistent Multi-Account Database + Optional Remote HTTP Sync Client.
///
/// Guarantees:
/// 1. Account profile, hashed PIN, bound card ID/UID, wallet balance, virtual cards,
///    and full transaction history are persisted in an on-device file database
///    (`tapatan_accounts_db_v2.json`) + `SharedPreferences` mirror, and synced
///    with `tapatan_backend` when configured.
/// 2. Signing out ONLY clears the active session pointer (`tapatan_active_session_email`)
///    and NEVER deletes account data or transaction history.
/// 3. Legacy `"Richard"` / `"richard@tapat.ph"` placeholders are stripped and blocked
///    from overwriting real accounts or card holder names.
class AccountBackendService {
  static const String _kDbPrefsKey = 'tapatan_accounts_db_v2';
  static const String _kConfigPrefsKey = 'tapatan_account_config_v2';
  static const String _kActiveEmailKey = 'tapatan_active_session_email';
  static const String _kLastEmailKey = 'tapatan_last_signed_in_email';
  static const String _kMigrationDoneKey = 'tapatan_v2_migrated';
  static const String _kDbFileName = 'tapatan_accounts_db_v2.json';

  static const Set<String> _blockedPlaceholderEmails = {
    'richard@tapat.ph',
  };

  static const Set<String> _blockedPlaceholderNames = {
    'richard',
    'cardholder',
  };

  static bool _initialized = false;
  static Map<String, AccountRecord> _accountsCache = {};
  static AccountManagementConfig _configCache = const AccountManagementConfig();

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<File?> _getDbFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_kDbFileName');
    } catch (_) {
      return null;
    }
  }

  static ({String salt, String hash}) _hashPin(String pin, {String? salt}) {
    final effectiveSalt = salt ?? _generateSalt();
    final digest =
        sha256.convert(utf8.encode('$effectiveSalt:${pin.trim()}')).toString();
    return (salt: effectiveSalt, hash: digest);
  }

  static String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _verifyPin(String pin, AccountRecord account) {
    if (account.pinSalt.isEmpty || account.pinHash.isEmpty) return false;
    final computed = _hashPin(pin, salt: account.pinSalt).hash;
    return computed == account.pinHash;
  }

  static CardData buildDefaultCardForAccount({
    required String name,
    required String cardId,
    required double balance,
  }) {
    final cleanId = cardId.trim();
    final suffix = cleanId.length >= 4
        ? cleanId.substring(cleanId.length - 4)
        : '8821';
    final cleanHolder = name.trim().isNotEmpty
        ? name.trim().toUpperCase()
        : 'TAPAT MEMBER';
    return CardData(
      id: 'card-tapat-primary',
      provider: 'Tapat JCOP4',
      cardNumber: '4532 •••• •••• $suffix',
      holderName: cleanHolder,
      expiry: '12/28',
      cvv: '882',
      type: 'visa',
      colors: const [Color(0xFF0369A1), Color(0xFF0891B2)],
      balance: balance,
    );
  }

  /// Ensures all virtual cards on an account have an accurate holderName
  /// (never a stale `"RICHARD"` / `"CARDHOLDER"` fallback) and synced balance.
  static List<CardData> sanitizeAndSyncCards(
    AccountRecord account,
    AccountManagementConfig config,
  ) {
    final realUpper = account.name.trim().toUpperCase();
    var cards = List<CardData>.from(account.virtualCards);
    if (cards.isEmpty && realUpper.isNotEmpty) {
      cards = [
        buildDefaultCardForAccount(
          name: account.name,
          cardId: account.cardId,
          balance: account.balance,
        ),
      ];
    }

    final activeId = account.activeCardId.isNotEmpty
        ? account.activeCardId
        : (cards.isNotEmpty ? cards.first.id : '');

    return List<CardData>.generate(cards.length, (i) {
      final c = cards[i];
      final rawHolder = c.holderName.trim();
      final isStalePlaceholder = rawHolder.isEmpty ||
          _blockedPlaceholderNames.contains(rawHolder.toLowerCase());
      final shouldUseAccountName = config.syncCardHolderNameWithAccount ||
          isStalePlaceholder ||
          c.id == 'card-tapat-primary';
      final isActiveOrSingle = c.id == activeId || cards.length == 1;

      final suffix = account.cardId.length >= 4
          ? account.cardId.substring(account.cardId.length - 4)
          : '';
      final updatedNumber =
          (c.id == 'card-tapat-primary' && suffix.isNotEmpty)
              ? '4532 •••• •••• $suffix'
              : c.cardNumber;

      return c.copyWith(
        cardNumber: updatedNumber,
        holderName:
            (shouldUseAccountName && realUpper.isNotEmpty) ? realUpper : rawHolder,
        balance: isActiveOrSingle ? account.balance : c.balance,
      );
    });
  }

  /// Initializes the persistent database, loads configuration, and migrates any
  /// real legacy account while purging stale `"Richard"` placeholders.
  static Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Load config
    final rawCfg = prefs.getString(_kConfigPrefsKey);
    if (rawCfg != null && rawCfg.isNotEmpty) {
      try {
        _configCache = AccountManagementConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawCfg) as Map),
        );
      } catch (_) {}
    }

    // 2. Load persistent accounts DB (prefer on-disk file, fallback to SharedPreferences)
    Map<String, dynamic>? decodedDb;
    final dbFile = await _getDbFile();
    if (dbFile != null && await dbFile.exists()) {
      try {
        final content = await dbFile.readAsString();
        if (content.trim().isNotEmpty) {
          decodedDb = Map<String, dynamic>.from(jsonDecode(content) as Map);
        }
      } catch (_) {}
    }

    if (decodedDb == null) {
      final prefsDbStr = prefs.getString(_kDbPrefsKey);
      if (prefsDbStr != null && prefsDbStr.isNotEmpty) {
        try {
          decodedDb = Map<String, dynamic>.from(jsonDecode(prefsDbStr) as Map);
        } catch (_) {}
      }
    }

    final loaded = <String, AccountRecord>{};
    if (decodedDb != null && decodedDb['accounts'] is Map) {
      final map = Map<String, dynamic>.from(decodedDb['accounts'] as Map);
      for (final entry in map.entries) {
        try {
          final emailKey = normalizeEmail(entry.key);
          if (_blockedPlaceholderEmails.contains(emailKey)) continue;
          final rec = AccountRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (rec.email.isEmpty ||
              _blockedPlaceholderEmails.contains(rec.email)) {
            continue;
          }
          final syncedCards = sanitizeAndSyncCards(rec, _configCache);
          loaded[rec.email] = rec.copyWith(
            virtualCards: syncedCards,
            activeCardId: rec.activeCardId.isNotEmpty
                ? rec.activeCardId
                : (syncedCards.isNotEmpty ? syncedCards.first.id : ''),
          );
        } catch (_) {}
      }
    }

    _accountsCache = loaded;

    // 3. One-time migration from legacy single-user SharedPreferences
    final migrated = prefs.getBool(_kMigrationDoneKey) ?? false;
    if (!migrated) {
      final legacyEmail = normalizeEmail(prefs.getString('snfc_email') ?? '');
      final legacyName = (prefs.getString('snfc_name') ?? '').trim();
      final isLegacyRichard =
          _blockedPlaceholderEmails.contains(legacyEmail) ||
              _blockedPlaceholderNames.contains(legacyName.toLowerCase());

      if (isLegacyRichard) {
        // Purge stale Richard placeholder keys so they never resurface
        await prefs.remove('snfc_name');
        await prefs.remove('snfc_email');
        await prefs.remove('snfc_registered');
        await prefs.remove('snfc_cards_json');
      } else if (legacyEmail.isNotEmpty &&
          legacyName.isNotEmpty &&
          !_accountsCache.containsKey(legacyEmail)) {
        final legacyPin = (prefs.getString('snfc_pin') ?? '123456').trim();
        final hashed = _hashPin(legacyPin.length >= 4 ? legacyPin : '123456');
        final legacyBalance = prefs.getDouble('snfc_balance') ?? 0.0;
        final legacyCardId = prefs.getString('snfc_card_id') ?? '';
        final legacyUid =
            (prefs.getString('snfc_jcop_uid') ?? '').toUpperCase();

        List<TransactionData> legacyTx = [];
        final txStr = prefs.getString('snfc_transactions_json');
        if (txStr != null && txStr.isNotEmpty) {
          try {
            legacyTx = (jsonDecode(txStr) as List)
                .map((e) => TransactionData.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList();
          } catch (_) {}
        }

        List<CardData> legacyCards = [];
        final cardsStr = prefs.getString('snfc_cards_json');
        if (cardsStr != null && cardsStr.isNotEmpty) {
          try {
            legacyCards = (jsonDecode(cardsStr) as List)
                .map((e) =>
                    CardData.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          } catch (_) {}
        }

        final nowIso = DateTime.now().toIso8601String();
        var migratedRecord = AccountRecord(
          id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
          name: legacyName,
          email: legacyEmail,
          pinSalt: hashed.salt,
          pinHash: hashed.hash,
          balance: legacyBalance,
          cardId: legacyCardId,
          jcopCardUid: legacyUid,
          activeCardId: prefs.getString('snfc_active_card_id') ?? '',
          virtualCards: legacyCards,
          transactions: legacyTx,
          createdAt: nowIso,
          lastLoginAt: nowIso,
          updatedAt: nowIso,
        );
        final synced = sanitizeAndSyncCards(migratedRecord, _configCache);
        migratedRecord = migratedRecord.copyWith(
          virtualCards: synced,
          activeCardId: migratedRecord.activeCardId.isNotEmpty
              ? migratedRecord.activeCardId
              : (synced.isNotEmpty ? synced.first.id : ''),
        );
        _accountsCache[legacyEmail] = migratedRecord;

        if (prefs.getBool('snfc_registered') == true) {
          await prefs.setString(_kActiveEmailKey, legacyEmail);
          await prefs.setString(_kLastEmailKey, legacyEmail);
        }
      }

      await prefs.setBool(_kMigrationDoneKey, true);
      await _persistDatabase();
    }

    _initialized = true;
  }

  static Future<void> _persistDatabase() async {
    final payload = jsonEncode({
      'version': 2,
      'updatedAt': DateTime.now().toIso8601String(),
      'accounts': _accountsCache.map((k, v) => MapEntry(k, v.toJson())),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDbPrefsKey, payload);

    final dbFile = await _getDbFile();
    if (dbFile != null) {
      try {
        final tmp = File('${dbFile.path}.tmp');
        await tmp.writeAsString(payload, flush: true);
        await tmp.rename(dbFile.path);
      } catch (_) {
        try {
          await dbFile.writeAsString(payload, flush: true);
        } catch (_) {}
      }
    }
  }

  static Future<AccountManagementConfig> getConfig() async {
    await initialize();
    return _configCache;
  }

  static Future<AccountManagementConfig> updateConfig(
    AccountManagementConfig nextConfig,
  ) async {
    await initialize();
    _configCache = nextConfig;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigPrefsKey, jsonEncode(nextConfig.toJson()));

    if (nextConfig.useRemoteBackend && nextConfig.backendUrl.isNotEmpty) {
      unawaited(_remoteRequest(
        'PUT',
        '/api/config',
        body: nextConfig.toJson(),
      ));
    }
    return _configCache;
  }

  /// Tests connectivity with the Node.js `tapatan_backend` server and pulls its rules.
  static Future<Map<String, dynamic>> testRemoteConnection(String url) async {
    final cleanBase = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanBase.isEmpty) {
      return {'success': false, 'error': 'Please enter a backend URL.'};
    }
    final res = await _remoteRequest(
      'GET',
      '/api/health',
      overrideBaseUrl: cleanBase,
    );
    if (res != null && res['success'] == true) {
      return res;
    }
    return {
      'success': false,
      'error':
          'Could not reach $cleanBase/api/health. Verify the server is running and reachable.',
    };
  }

  static Future<Map<String, dynamic>?> _remoteRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? overrideBaseUrl,
  }) async {
    final base = (overrideBaseUrl ?? _configCache.backendUrl)
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    if (overrideBaseUrl == null && !_configCache.useRemoteBackend) return null;

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1800);
    try {
      final uri = Uri.parse('$base$path');
      final req = await client.openUrl(method, uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (body != null) {
        req.add(utf8.encode(jsonEncode(body)));
      }
      final resp =
          await req.close().timeout(const Duration(milliseconds: 2500));
      final text = await resp.transform(utf8.decoder).join();
      if (text.trim().isEmpty) return null;
      final decoded = Map<String, dynamic>.from(jsonDecode(text) as Map);
      decoded['_httpStatus'] = resp.statusCode;
      return decoded;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Returns currently signed-in account (if an active session is open).
  static Future<AccountRecord?> getActiveSessionAccount() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final activeEmail = normalizeEmail(prefs.getString(_kActiveEmailKey) ?? '');
    if (activeEmail.isEmpty) return null;

    // Pull freshest copy from remote backend if enabled
    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final encoded = Uri.encodeComponent(activeEmail);
      final remote = await _remoteRequest('GET', '/api/accounts/$encoded');
      if (remote != null &&
          remote['success'] == true &&
          remote['account'] is Map) {
        final existing = _accountsCache[activeEmail];
        final merged = AccountRecord.fromJson(
          Map<String, dynamic>.from(remote['account'] as Map),
          fallbackSalt: existing?.pinSalt ?? '',
          fallbackPinHash: existing?.pinHash ?? '',
        );
        final syncedCards = sanitizeAndSyncCards(merged, _configCache);
        _accountsCache[activeEmail] = merged.copyWith(virtualCards: syncedCards);
        await _persistDatabase();
      }
    }

    final acc = _accountsCache[activeEmail];
    if (acc == null) {
      await prefs.remove(_kActiveEmailKey);
      return null;
    }
    return acc;
  }

  /// Returns the most recently signed-in email (for convenient email pre-fill after Sign Out).
  static Future<String> getLastSignedInEmail() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final last = normalizeEmail(prefs.getString(_kLastEmailKey) ?? '');
    if (last.isNotEmpty && _accountsCache.containsKey(last)) {
      return last;
    }
    final summaries = await listSavedAccounts();
    return summaries.isNotEmpty ? summaries.first.email : '';
  }

  /// Lists all registered accounts stored in the database (most recent login first).
  static Future<List<AccountSummary>> listSavedAccounts() async {
    await initialize();
    final list = _accountsCache.values
        .map(
          (a) => AccountSummary(
            name: a.name,
            email: a.email,
            cardId: a.cardId,
            jcopCardUid: a.jcopCardUid,
            balance: a.balance,
            transactionCount: a.transactions.length,
            lastLoginAt: a.lastLoginAt,
          ),
        )
        .toList();
    list.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
    return list;
  }

  static Future<void> _setActiveSession(AccountRecord account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveEmailKey, account.email);
    await prefs.setString(_kLastEmailKey, account.email);
    // Keep minimal current-session mirrors for NFC helper compatibility
    await prefs.setBool('snfc_registered', true);
    await prefs.setString('snfc_name', account.name);
    await prefs.setString('snfc_email', account.email);
    if (account.cardId.isNotEmpty) {
      await prefs.setString('snfc_card_id', account.cardId);
    }
    if (account.jcopCardUid.isNotEmpty) {
      await prefs.setString('snfc_jcop_uid', account.jcopCardUid);
    }
  }

  /// Signs out of the active session WITHOUT deleting any account record,
  /// balance, card, or transaction history from the database!
  static Future<void> signOut() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveEmailKey);
    await prefs.setBool('snfc_registered', false);
    await prefs.remove('snfc_name');
    await prefs.remove('snfc_email');
    await prefs.remove('snfc_balance');
    await prefs.remove('snfc_card_id');
    await prefs.remove('snfc_active_card_id');
    await prefs.remove('snfc_transactions_json');
    await prefs.remove('snfc_cards_json');
    await prefs.remove('snfc_pin');
  }

  /// Registers a new persistent account and binds its Tapat JCOP4 card.
  static Future<AccountAuthResult> registerAccount({
    required String name,
    required String email,
    String phone = '',
    required String pin,
    String cardId = '',
    String jcopCardUid = '',
  }) async {
    await initialize();
    final cleanName = name.trim();
    final cleanEmail = normalizeEmail(email);
    final cleanPhone = phone.trim();
    final cleanPin = pin.trim();
    final cleanCardId = cardId.trim();
    final cleanUid = jcopCardUid.trim().toUpperCase();

    if (cleanName.length < 2) {
      return const AccountAuthResult(
        success: false,
        error: 'Please enter your full name (at least 2 characters).',
      );
    }
    if (_blockedPlaceholderNames.contains(cleanName.toLowerCase()) ||
        _blockedPlaceholderEmails.contains(cleanEmail)) {
      return const AccountAuthResult(
        success: false,
        error: 'Please enter your real name and email address.',
      );
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      return const AccountAuthResult(
        success: false,
        error: 'Please enter a valid email address.',
      );
    }
    if (cleanPin.length < _configCache.pinMinLength ||
        cleanPin.length > _configCache.pinMaxLength) {
      return AccountAuthResult(
        success: false,
        error:
            'PIN must be ${_configCache.pinMinLength} to ${_configCache.pinMaxLength} digits.',
      );
    }

    // Try remote backend registration first if configured
    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final remote = await _remoteRequest(
        'POST',
        '/api/accounts/register',
        body: {
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'pin': cleanPin,
          'cardId': cleanCardId,
          'jcopCardUid': cleanUid,
          'initialBalance': _configCache.initialWalletBalance,
        },
      );
      if (remote != null) {
        if (remote['success'] != true) {
          return AccountAuthResult(
            success: false,
            error: (remote['error'] ?? 'Registration failed on backend.')
                .toString(),
          );
        }
        final hashed = _hashPin(cleanPin);
        var remoteRec = AccountRecord.fromJson(
          Map<String, dynamic>.from(remote['account'] as Map),
          fallbackSalt: hashed.salt,
          fallbackPinHash: hashed.hash,
        );
        final synced = sanitizeAndSyncCards(remoteRec, _configCache);
        remoteRec = remoteRec.copyWith(
          virtualCards: synced,
          activeCardId: remoteRec.activeCardId.isNotEmpty
              ? remoteRec.activeCardId
              : synced.first.id,
        );
        _unbindCardFromOtherLocalAccounts(
          keepEmail: cleanEmail,
          cardId: cleanCardId,
          jcopCardUid: cleanUid,
        );
        _accountsCache[cleanEmail] = remoteRec;
        await _persistDatabase();
        await _setActiveSession(remoteRec);
        return AccountAuthResult(success: true, account: remoteRec);
      }
    }

    if (_accountsCache.containsKey(cleanEmail)) {
      return AccountAuthResult(
        success: false,
        error:
            'An account for "$cleanEmail" already exists. Please Sign In to restore your account & history.',
      );
    }

    // Check card binding policy across local DB
    if (cleanCardId.isNotEmpty || cleanUid.isNotEmpty) {
      for (final other in _accountsCache.values) {
        final sameId = cleanCardId.isNotEmpty &&
            cleanCardId != 'TAPAT_JCOP4_8821' &&
            other.cardId == cleanCardId;
        final sameUid = cleanUid.isNotEmpty &&
            cleanUid != '04:7A:93:E2:10:88:01' &&
            other.jcopCardUid.isNotEmpty &&
            other.jcopCardUid.toUpperCase() == cleanUid;
        if ((sameId || sameUid) && !_configCache.allowCardRebindOnSignup) {
          return AccountAuthResult(
            success: false,
            error: 'This Tapat card is already bound to ${other.email}.',
          );
        }
      }
      _unbindCardFromOtherLocalAccounts(
        keepEmail: cleanEmail,
        cardId: cleanCardId,
        jcopCardUid: cleanUid,
      );
    }

    final hashed = _hashPin(cleanPin);
    final startBalance = _configCache.initialWalletBalance;
    final primaryCard = buildDefaultCardForAccount(
      name: cleanName,
      cardId: cleanCardId,
      balance: startBalance,
    );
    final initialTx = startBalance > 0
        ? [
            TransactionData(
              id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Initial Wallet Balance',
              amount: startBalance,
              icon: LucideIcons.arrowDownLeft,
              color: const Color(0xFF10B981),
              time: 'Account Created',
              type: 'receive',
            ),
          ]
        : <TransactionData>[];

    final nowIso = DateTime.now().toIso8601String();
    final record = AccountRecord(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      pinSalt: hashed.salt,
      pinHash: hashed.hash,
      balance: startBalance,
      cardId: cleanCardId,
      jcopCardUid: cleanUid,
      activeCardId: primaryCard.id,
      virtualCards: [primaryCard],
      transactions: initialTx,
      pinRetriesLeft: _configCache.maxPinRetries,
      cardLifecycleState: cleanCardId.isNotEmpty ? 'ENROLLED' : 'unknown',
      createdAt: nowIso,
      lastLoginAt: nowIso,
      updatedAt: nowIso,
    );

    _accountsCache[cleanEmail] = record;
    await _persistDatabase();
    await _setActiveSession(record);

    return AccountAuthResult(success: true, account: record);
  }

  static void _unbindCardFromOtherLocalAccounts({
    required String keepEmail,
    required String cardId,
    required String jcopCardUid,
  }) {
    for (final key in _accountsCache.keys.toList()) {
      if (key == keepEmail) continue;
      final acc = _accountsCache[key]!;
      final clearId = cardId.isNotEmpty && acc.cardId == cardId;
      final clearUid = jcopCardUid.isNotEmpty &&
          acc.jcopCardUid.toUpperCase() == jcopCardUid;
      if (clearId || clearUid) {
        _accountsCache[key] = acc.copyWith(
          cardId: clearId ? '' : acc.cardId,
          jcopCardUid: clearUid ? '' : acc.jcopCardUid,
        );
      }
    }
  }

  /// Authenticates an existing account by `email` + `pin` and restores its exact
  /// wallet balance, virtual cards (with real holder name), and transaction history.
  static Future<AccountAuthResult> loginWithEmailPin({
    required String email,
    required String pin,
  }) async {
    await initialize();
    final cleanEmail = normalizeEmail(email);
    final cleanPin = pin.trim();

    if (cleanEmail.isEmpty) {
      return const AccountAuthResult(
        success: false,
        error: 'Please enter your registered email address.',
      );
    }

    if (_configCache.requirePinOnEmailLogin &&
        cleanPin.length < _configCache.pinMinLength) {
      return AccountAuthResult(
        success: false,
        error:
            'Please enter your ${_configCache.pinMinLength} to ${_configCache.pinMaxLength}-digit PIN.',
      );
    }

    // 1. Check remote backend if enabled
    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final remote = await _remoteRequest(
        'POST',
        '/api/accounts/login',
        body: {'email': cleanEmail, 'pin': cleanPin},
      );
      if (remote != null) {
        if (remote['success'] != true) {
          return AccountAuthResult(
            success: false,
            error: (remote['error'] ?? 'Sign in failed.').toString(),
          );
        }
        final hashed = _hashPin(cleanPin);
        var remoteRec = AccountRecord.fromJson(
          Map<String, dynamic>.from(remote['account'] as Map),
          fallbackSalt: hashed.salt,
          fallbackPinHash: hashed.hash,
        );
        final synced = sanitizeAndSyncCards(remoteRec, _configCache);
        remoteRec = remoteRec.copyWith(virtualCards: synced);
        _accountsCache[cleanEmail] = remoteRec;
        await _persistDatabase();
        await _setActiveSession(remoteRec);
        return AccountAuthResult(success: true, account: remoteRec);
      }
    }

    // 2. Authenticate against persistent on-device database
    final existing = _accountsCache[cleanEmail];
    if (existing == null) {
      return AccountAuthResult(
        success: false,
        error:
            'No registered account found for "$cleanEmail". Please check your email or tap Create Account.',
      );
    }

    if (_configCache.requirePinOnEmailLogin) {
      if (existing.pinRetriesLeft == 0) {
        return const AccountAuthResult(
          success: false,
          error: 'Account PIN is locked due to too many failed attempts.',
        );
      }
      if (!_verifyPin(cleanPin, existing)) {
        final left = max(0, existing.pinRetriesLeft - 1);
        _accountsCache[cleanEmail] = existing.copyWith(
          pinRetriesLeft: left,
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _persistDatabase();
        return AccountAuthResult(
          success: false,
          error:
              'Incorrect PIN for ${existing.email} ($left attempt(s) remaining).',
        );
      }
    }

    final nowIso = DateTime.now().toIso8601String();
    final syncedCards = sanitizeAndSyncCards(existing, _configCache);
    final updated = existing.copyWith(
      pinRetriesLeft: _configCache.maxPinRetries,
      virtualCards: syncedCards,
      activeCardId: existing.activeCardId.isNotEmpty
          ? existing.activeCardId
          : (syncedCards.isNotEmpty ? syncedCards.first.id : ''),
      lastLoginAt: nowIso,
      updatedAt: nowIso,
    );

    _accountsCache[cleanEmail] = updated;
    await _persistDatabase();
    await _setActiveSession(updated);

    return AccountAuthResult(success: true, account: updated);
  }

  /// Authenticates via a physical Tapat JCOP4 smart card tap.
  /// Resolves strictly against registered accounts in the database (by `cardId`,
  /// `jcopCardUid`, or verified registered `owner` email) — NEVER creates or
  /// falls back to `"Richard"`.
  static Future<AccountAuthResult> loginWithCard({
    required String cardId,
    required String uid,
    String ownerEmail = '',
    String cardName = '',
  }) async {
    await initialize();
    final cleanCardId = cardId.trim();
    final cleanUid = uid.trim().toUpperCase();
    final rawEmail = normalizeEmail(ownerEmail);
    final cleanEmail =
        _blockedPlaceholderEmails.contains(rawEmail) ? '' : rawEmail;

    // 1. Remote backend lookup if enabled
    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final remote = await _remoteRequest(
        'POST',
        '/api/accounts/login-card',
        body: {
          'cardId': cleanCardId,
          'uid': cleanUid,
          'owner': cleanEmail,
          'name': cardName,
        },
      );
      if (remote != null) {
        if (remote['success'] != true) {
          return AccountAuthResult(
            success: false,
            error: (remote['error'] ?? 'Card is not bound to an account.')
                .toString(),
          );
        }
        final existing = _accountsCache[
            normalizeEmail((remote['account'] as Map)['email']?.toString() ?? '')];
        var remoteRec = AccountRecord.fromJson(
          Map<String, dynamic>.from(remote['account'] as Map),
          fallbackSalt: existing?.pinSalt ?? '',
          fallbackPinHash: existing?.pinHash ?? '',
        );
        final synced = sanitizeAndSyncCards(remoteRec, _configCache);
        remoteRec = remoteRec.copyWith(virtualCards: synced);
        _accountsCache[remoteRec.email] = remoteRec;
        await _persistDatabase();
        await _setActiveSession(remoteRec);
        return AccountAuthResult(success: true, account: remoteRec);
      }
    }

    // 2. Local persistent DB lookup
    AccountRecord? matched;
    final allAccounts = _accountsCache.values.toList();

    // Priority 1: Unique provisioned cardId
    if (cleanCardId.isNotEmpty && cleanCardId != 'TAPAT_JCOP4_8821') {
      for (final a in allAccounts) {
        if (a.cardId == cleanCardId) {
          matched = a;
          break;
        }
      }
    }

    // Priority 2: Physical JCOP4 hardware UID
    if (matched == null &&
        cleanUid.isNotEmpty &&
        cleanUid != '04:7A:93:E2:10:88:01') {
      for (final a in allAccounts) {
        if (a.jcopCardUid.isNotEmpty &&
            a.jcopCardUid.toUpperCase() == cleanUid) {
          matched = a;
          break;
        }
      }
    }

    // Priority 3: Provisioned owner email on card (must exist in DB and not be blocked)
    if (matched == null && cleanEmail.isNotEmpty) {
      matched = _accountsCache[cleanEmail];
    }

    // Priority 4: Simulated/demo cardId explicitly bound to a registered account
    if (matched == null && cleanCardId == 'TAPAT_JCOP4_8821') {
      for (final a in allAccounts) {
        if (a.cardId == 'TAPAT_JCOP4_8821') {
          matched = a;
          break;
        }
      }
    }

    if (matched == null) {
      return const AccountAuthResult(
        success: false,
        error:
            'This Tapat card is not bound to any registered account yet. Sign in with your Email & PIN or Create Account.',
      );
    }

    final nowIso = DateTime.now().toIso8601String();
    var updated = matched.copyWith(
      jcopCardUid: cleanUid.isNotEmpty ? cleanUid : matched.jcopCardUid,
      cardId: (cleanCardId.isNotEmpty && cleanCardId != 'TAPAT_JCOP4_8821')
          ? cleanCardId
          : matched.cardId,
      cardLifecycleState: 'ENROLLED',
      lastLoginAt: nowIso,
      updatedAt: nowIso,
    );
    final syncedCards = sanitizeAndSyncCards(updated, _configCache);
    updated = updated.copyWith(virtualCards: syncedCards);

    _accountsCache[updated.email] = updated;
    await _persistDatabase();
    await _setActiveSession(updated);

    return AccountAuthResult(success: true, account: updated);
  }

  /// Persists any wallet mutation (top-up, payment, virtual card add/delete,
  /// card UID update) directly into the signed-in user's database record.
  static Future<void> syncAccountFromUserState(UserState state) async {
    await initialize();
    final email = normalizeEmail(state.email);
    if (email.isEmpty || _blockedPlaceholderEmails.contains(email)) return;

    final existing = _accountsCache[email];
    if (existing == null) return;

    final nowIso = DateTime.now().toIso8601String();
    var updated = existing.copyWith(
      name: state.name.trim().isNotEmpty ? state.name.trim() : existing.name,
      balance: state.balance,
      cardId: state.cardId.isNotEmpty ? state.cardId : existing.cardId,
      jcopCardUid: state.jcopCardUid.isNotEmpty
          ? state.jcopCardUid.toUpperCase()
          : existing.jcopCardUid,
      activeCardId: state.activeCardId,
      virtualCards: state.virtualCards,
      transactions: state.transactions,
      pinRetriesLeft:
          state.pinRetriesLeft >= 0 ? state.pinRetriesLeft : existing.pinRetriesLeft,
      cardLifecycleState: state.cardLifecycleState,
      updatedAt: nowIso,
    );
    updated = updated.copyWith(
      virtualCards: sanitizeAndSyncCards(updated, _configCache),
    );

    _accountsCache[email] = updated;
    await _persistDatabase();

    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final encoded = Uri.encodeComponent(email);
      unawaited(_remoteRequest(
        'PUT',
        '/api/accounts/$encoded/sync',
        body: {
          'name': updated.name,
          'balance': updated.balance,
          'cardId': updated.cardId,
          'jcopCardUid': updated.jcopCardUid,
          'activeCardId': updated.activeCardId,
          'virtualCards': updated.virtualCards.map((c) => c.toJson()).toList(),
          'transactions': updated.transactions.map((t) => t.toJson()).toList(),
          'cardLifecycleState': updated.cardLifecycleState,
          'pinRetriesLeft': updated.pinRetriesLeft,
        },
      ));
    }
  }

  /// Changes the account PIN after verifying `currentPin`.
  static Future<AccountAuthResult> changePin({
    required String email,
    required String currentPin,
    required String newPin,
  }) async {
    await initialize();
    final cleanEmail = normalizeEmail(email);
    final existing = _accountsCache[cleanEmail];
    if (existing == null) {
      return const AccountAuthResult(
        success: false,
        error: 'No active account found.',
      );
    }

    if (newPin.trim().length < _configCache.pinMinLength ||
        newPin.trim().length > _configCache.pinMaxLength) {
      return AccountAuthResult(
        success: false,
        error:
            'New PIN must be ${_configCache.pinMinLength} to ${_configCache.pinMaxLength} digits.',
      );
    }

    if (_configCache.useRemoteBackend && _configCache.backendUrl.isNotEmpty) {
      final encoded = Uri.encodeComponent(cleanEmail);
      final remote = await _remoteRequest(
        'POST',
        '/api/accounts/$encoded/change-pin',
        body: {'currentPin': currentPin.trim(), 'newPin': newPin.trim()},
      );
      if (remote != null && remote['success'] != true) {
        return AccountAuthResult(
          success: false,
          error: (remote['error'] ?? 'Failed to change PIN.').toString(),
        );
      }
    } else {
      if (!_verifyPin(currentPin, existing)) {
        return const AccountAuthResult(
          success: false,
          error: 'Current PIN is incorrect.',
        );
      }
    }

    final hashed = _hashPin(newPin.trim());
    final updated = existing.copyWith(
      pinSalt: hashed.salt,
      pinHash: hashed.hash,
      pinRetriesLeft: _configCache.maxPinRetries,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _accountsCache[cleanEmail] = updated;
    await _persistDatabase();

    return AccountAuthResult(success: true, account: updated);
  }
}

