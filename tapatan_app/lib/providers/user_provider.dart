import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/lucide_icons.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class TransactionData {
  final String id;
  final String name;
  final double amount;
  final IconData icon;
  final Color color;
  final String time;
  final String type; // 'nfc', 'send', 'topup', 'receive'

  TransactionData({
    required this.id,
    required this.name,
    required this.amount,
    required this.icon,
    required this.color,
    required this.time,
    this.type = 'send',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'time': time,
        'type': type,
      };

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'send').toString();
    final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final isPositive = amount > 0;
    return TransactionData(
      id: (json['id'] ?? 'tx-${DateTime.now().millisecondsSinceEpoch}').toString(),
      name: (json['name'] ?? 'Transaction').toString(),
      amount: amount,
      icon: isPositive
          ? LucideIcons.arrowDownLeft
          : (type == 'nfc' ? LucideIcons.wifi : LucideIcons.arrowUpRight),
      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFF87171),
      time: (json['time'] ?? 'Recent').toString(),
      type: type,
    );
  }
}

class CardData {
  final String id;
  final String provider;
  final String cardNumber;
  final String holderName;
  final String expiry;
  final String cvv;
  final String type; // 'visa' or 'mastercard'
  final List<Color> colors;
  final double balance;

  CardData({
    required this.id,
    required this.provider,
    required this.cardNumber,
    required this.holderName,
    required this.expiry,
    required this.cvv,
    required this.type,
    required this.colors,
    this.balance = 0.0,
  });

  CardData copyWith({
    String? id,
    String? provider,
    String? cardNumber,
    String? holderName,
    String? expiry,
    String? cvv,
    String? type,
    List<Color>? colors,
    double? balance,
  }) {
    return CardData(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      cardNumber: cardNumber ?? this.cardNumber,
      holderName: holderName ?? this.holderName,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      type: type ?? this.type,
      colors: colors ?? this.colors,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'cardNumber': cardNumber,
        'holderName': holderName,
        'expiry': expiry,
        'cvv': cvv,
        'type': type,
        'colors': colors.map((c) => c.toARGB32()).toList(),
        'balance': balance,
      };

  factory CardData.fromJson(Map<String, dynamic> json) {
    final rawColors = (json['colors'] as List?)
            ?.map((v) => Color((v as num).toInt()))
            .toList() ??
        const [Color(0xFF0369A1), Color(0xFF0891B2)];
    return CardData(
      id: (json['id'] ?? 'card-1').toString(),
      provider: (json['provider'] ?? 'Tapat Card').toString(),
      cardNumber: (json['cardNumber'] ?? '4532 •••• •••• 8821').toString(),
      holderName: (json['holderName'] ?? 'CARDHOLDER').toString(),
      expiry: (json['expiry'] ?? '12/28').toString(),
      cvv: (json['cvv'] ?? '123').toString(),
      type: (json['type'] ?? 'visa').toString(),
      colors: rawColors.length >= 2
          ? rawColors
          : const [Color(0xFF0369A1), Color(0xFF0891B2)],
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Sar-E Models ─────────────────────────────────────────────────────────────

class SarECartItem {
  final String name;
  final double price;
  final int qty;

  SarECartItem({required this.name, required this.price, required this.qty});
}

class SarEPendingOrder {
  final String orderId;
  final String merchant;
  final List<SarECartItem> items;
  final double totalAmount;

  SarEPendingOrder({
    required this.orderId,
    required this.merchant,
    required this.items,
    required this.totalAmount,
  });
}

// ── User State ──────────────────────────────────────────────────────────────

class UserState {
  final String name;
  final String email;
  final double balance;
  final List<TransactionData> transactions;
  final List<CardData> virtualCards;
  final String activeCardId;
  final bool cardArmed;
  final bool sessionTxnDone;

  /// The unique tap@tan card ID written to the NFC smart card during registration.
  final String cardId;

  // ── JCOP hardware state ─────────────────────────────────────────────────

  /// Remaining PIN attempts as last reported by the on-card OwnerPIN.
  /// -1 = unknown, 0 = blocked. Synced after each VERIFY APDU.
  final int pinRetriesLeft;

  /// Current card lifecycle state as last known.
  /// e.g. 'op_ready', 'secured', 'locked', 'unknown', 'ENROLLED'
  final String cardLifecycleState;

  /// Hardware UID of the physical JCOP4 J3R150 card, read via ISO 14443 layer.
  final String jcopCardUid;

  // ── Sar-E integration ────────────────────────────────────────────────────

  /// Pending payment order from the Sar-E store. null when no pending payment.
  final SarEPendingOrder? sarePendingOrder;

  UserState({
    this.name = '',
    this.email = '',
    this.balance = 0.0,
    this.transactions = const [],
    this.virtualCards = const [],
    this.activeCardId = '',
    this.cardArmed = false,
    this.sessionTxnDone = false,
    this.cardId = '',
    this.pinRetriesLeft = -1,
    this.cardLifecycleState = 'unknown',
    this.jcopCardUid = '',
    this.sarePendingOrder,
  });

  CardData? get activeCard {
    if (virtualCards.isEmpty) return null;
    try {
      return virtualCards.firstWhere((c) => c.id == activeCardId);
    } catch (_) {
      return virtualCards.first;
    }
  }

  double get totalIncome => transactions
      .where((t) => t.amount > 0)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => transactions
      .where((t) => t.amount < 0)
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  int get nfcPayCount => transactions.where((t) => t.type == 'nfc').length;

  /// Returns true if a valid NFC card ID has been registered for this account.
  bool get hasNfcCard => cardId.isNotEmpty;

  UserState copyWith({
    String? name,
    String? email,
    double? balance,
    List<TransactionData>? transactions,
    List<CardData>? virtualCards,
    String? activeCardId,
    bool? cardArmed,
    bool? sessionTxnDone,
    String? cardId,
    int? pinRetriesLeft,
    String? cardLifecycleState,
    String? jcopCardUid,
    SarEPendingOrder? Function()? sarePendingOrder,
  }) {
    return UserState(
      name: name ?? this.name,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      virtualCards: virtualCards ?? this.virtualCards,
      activeCardId: activeCardId ?? this.activeCardId,
      cardArmed: cardArmed ?? this.cardArmed,
      sessionTxnDone: sessionTxnDone ?? this.sessionTxnDone,
      cardId: cardId ?? this.cardId,
      pinRetriesLeft: pinRetriesLeft ?? this.pinRetriesLeft,
      cardLifecycleState: cardLifecycleState ?? this.cardLifecycleState,
      jcopCardUid: jcopCardUid ?? this.jcopCardUid,
      sarePendingOrder: sarePendingOrder != null
          ? sarePendingOrder()
          : this.sarePendingOrder,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<UserState> {
  bool _hasManualMutation = false;

  UserNotifier() : super(UserState()) {
    _loadFromPrefs();
  }

  Future<void> reloadFromPrefs() => _loadFromPrefs(force: true);

  Future<void> _loadFromPrefs({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_hasManualMutation && !force) return;

    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    if (!isRegistered) {
      if (!_hasManualMutation) {
        state = UserState();
      }
      return;
    }

    final name = prefs.getString('snfc_name') ?? '';
    final email = prefs.getString('snfc_email') ?? '';
    final balance = prefs.getDouble('snfc_balance') ?? 0.0;
    final cardId = prefs.getString('snfc_card_id') ?? '';
    final activeCardId = prefs.getString('snfc_active_card_id') ?? '';
    final jcopUid = prefs.getString('snfc_jcop_uid') ?? '';
    final lifecycle = prefs.getString('snfc_lifecycle_state') ?? 'ENROLLED';
    final retries = prefs.getInt('snfc_pin_retries') ?? 5;

    List<TransactionData> loadedTransactions = [];
    final txJsonStr = prefs.getString('snfc_transactions_json');
    if (txJsonStr != null && txJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(txJsonStr) as List;
        loadedTransactions = decoded
            .map((item) =>
                TransactionData.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {}
    }

    List<CardData> loadedCards = [];
    final cardsJsonStr = prefs.getString('snfc_cards_json');
    if (cardsJsonStr != null && cardsJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(cardsJsonStr) as List;
        loadedCards = decoded
            .map((item) =>
                CardData.fromJson(Map<String, dynamic>.from(item as Map)))
            .map((c) => c.copyWith(
                  holderName: name.isNotEmpty ? name.toUpperCase() : c.holderName,
                  balance: balance,
                ))
            .toList();
      } catch (_) {}
    }

    if (loadedCards.isEmpty && name.isNotEmpty) {
      final defaultCard = _buildDefaultCardForUser(
        name: name,
        cardId: cardId,
        balance: balance,
      );
      loadedCards = [defaultCard];
    }

    state = state.copyWith(
      name: name,
      email: email,
      balance: balance,
      cardId: cardId,
      virtualCards: loadedCards,
      activeCardId: activeCardId.isNotEmpty
          ? activeCardId
          : (loadedCards.isNotEmpty ? loadedCards.first.id : ''),
      transactions: loadedTransactions,
      jcopCardUid: jcopUid,
      cardLifecycleState: lifecycle,
      pinRetriesLeft: retries,
    );
  }

  CardData _buildDefaultCardForUser({
    required String name,
    required String cardId,
    required double balance,
  }) {
    final suffix = cardId.length >= 4
        ? cardId.substring(cardId.length - 4)
        : '8821';
    return CardData(
      id: 'card-tapat-primary',
      provider: 'Tapat JCOP4',
      cardNumber: '4532 •••• •••• $suffix',
      holderName: name.isNotEmpty ? name.toUpperCase() : 'CARDHOLDER',
      expiry: '12/28',
      cvv: '882',
      type: 'visa',
      colors: const [Color(0xFF0369A1), Color(0xFF0891B2)],
      balance: balance,
    );
  }

  List<CardData> _syncCardsWithBalance(
    List<CardData> cards,
    double newBalance, {
    String? holderName,
  }) {
    if (cards.isEmpty) return cards;
    final activeId = state.activeCardId.isNotEmpty
        ? state.activeCardId
        : cards.first.id;
    return cards.map((c) {
      final updatedName =
          (holderName != null && holderName.isNotEmpty)
              ? holderName.toUpperCase()
              : c.holderName;
      if (c.id == activeId || cards.length == 1) {
        return c.copyWith(balance: newBalance, holderName: updatedName);
      }
      return c.copyWith(holderName: updatedName);
    }).toList();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('snfc_name', state.name);
    await prefs.setString('snfc_email', state.email);
    await prefs.setDouble('snfc_balance', state.balance);
    if (state.cardId.isNotEmpty) {
      await prefs.setString('snfc_card_id', state.cardId);
    }
    await prefs.setString('snfc_active_card_id', state.activeCardId);
    await prefs.setString(
      'snfc_transactions_json',
      jsonEncode(state.transactions.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      'snfc_cards_json',
      jsonEncode(state.virtualCards.map((c) => c.toJson()).toList()),
    );
    if (state.jcopCardUid.isNotEmpty) {
      await prefs.setString('snfc_jcop_uid', state.jcopCardUid);
    }
    await prefs.setString('snfc_lifecycle_state', state.cardLifecycleState);
    await prefs.setInt('snfc_pin_retries', state.pinRetriesLeft);
  }

  /// Sets user data after successful signup or account switch.
  /// [cardId] is the unique ID written to the NFC smart card during registration.
  Future<void> setUserData(
    String name,
    String email, {
    String cardId = '',
    double initialBalance = 0.0,
  }) async {
    _hasManualMutation = true;
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final primaryCard = _buildDefaultCardForUser(
      name: cleanName,
      cardId: cardId,
      balance: initialBalance,
    );
    final initialTx = initialBalance > 0
        ? [
            TransactionData(
              id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Initial Wallet Balance',
              amount: initialBalance,
              icon: LucideIcons.arrowDownLeft,
              color: const Color(0xFF10B981),
              time: 'Just now',
              type: 'receive',
            ),
          ]
        : <TransactionData>[];

    state = state.copyWith(
      name: cleanName,
      email: cleanEmail,
      balance: initialBalance,
      cardId: cardId,
      virtualCards: [primaryCard],
      activeCardId: primaryCard.id,
      transactions: initialTx,
      cardArmed: false,
      sessionTxnDone: false,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('snfc_registered', true);
    await _persistState();
  }

  /// Verifies if the given cardId matches the registered card.
  bool verifyCardId(String cardId) {
    return state.cardId.isNotEmpty && state.cardId == cardId;
  }

  void topUp(double amount) {
    if (amount <= 0) return;
    _hasManualMutation = true;
    final newBalance = state.balance + amount;
    final newTx = TransactionData(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Top Up',
      amount: amount,
      icon: LucideIcons.arrowDownLeft,
      color: const Color(0xFF10B981),
      time: 'Just now',
      type: 'receive',
    );
    state = state.copyWith(
      balance: newBalance,
      virtualCards: _syncCardsWithBalance(
        state.virtualCards,
        newBalance,
        holderName: state.name,
      ),
      transactions: [newTx, ...state.transactions],
    );
    _persistState();
  }

  void sendMoney(
    double amount, {
    String recipient = 'Transfer',
    String type = 'send',
  }) {
    if (amount <= 0 || state.balance < amount) return;
    _hasManualMutation = true;
    final newBalance = state.balance - amount;
    final newTx = TransactionData(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      name: recipient,
      amount: -amount,
      icon: type == 'nfc' ? LucideIcons.wifi : LucideIcons.arrowUpRight,
      color: const Color(0xFFF87171),
      time: 'Just now',
      type: type,
    );
    state = state.copyWith(
      balance: newBalance,
      virtualCards: _syncCardsWithBalance(
        state.virtualCards,
        newBalance,
        holderName: state.name,
      ),
      transactions: [newTx, ...state.transactions],
      sessionTxnDone: type == 'nfc' ? true : state.sessionTxnDone,
      cardArmed: type == 'nfc' ? false : state.cardArmed,
    );
    _persistState();
  }

  void receiveAmount(double amount, {String sender = 'Transfer'}) {
    if (amount <= 0) return;
    _hasManualMutation = true;
    final newBalance = state.balance + amount;
    final newTx = TransactionData(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      name: sender,
      amount: amount,
      icon: LucideIcons.arrowDownLeft,
      color: const Color(0xFF10B981),
      time: 'Just now',
      type: 'receive',
    );
    state = state.copyWith(
      balance: newBalance,
      virtualCards: _syncCardsWithBalance(
        state.virtualCards,
        newBalance,
        holderName: state.name,
      ),
      transactions: [newTx, ...state.transactions],
    );
    _persistState();
  }

  void addVirtualCard(CardData card) {
    _hasManualMutation = true;
    final syncedCard = card.copyWith(
      holderName: state.name.isNotEmpty ? state.name.toUpperCase() : card.holderName,
      balance: state.balance,
    );
    final updatedCards = [...state.virtualCards, syncedCard];
    state = state.copyWith(
      virtualCards: updatedCards,
      activeCardId: state.activeCardId.isNotEmpty ? state.activeCardId : syncedCard.id,
    );
    _persistState();
  }

  void deleteCard(String id) {
    _hasManualMutation = true;
    final newCards = state.virtualCards.where((c) => c.id != id).toList();
    String newActiveId = state.activeCardId;
    if (newActiveId == id && newCards.isNotEmpty) {
      newActiveId = newCards.first.id;
    } else if (newCards.isEmpty) {
      newActiveId = '';
    }
    state = state.copyWith(virtualCards: newCards, activeCardId: newActiveId);
    _persistState();
  }

  void setActiveCard(String id) {
    _hasManualMutation = true;
    state = state.copyWith(
      activeCardId: id,
      virtualCards: _syncCardsWithBalance(
        state.virtualCards,
        state.balance,
        holderName: state.name,
      ),
    );
    _persistState();
  }

  void armCard() {
    state = state.copyWith(cardArmed: true, sessionTxnDone: false);
  }

  void completeTransaction() {
    state = state.copyWith(cardArmed: false, sessionTxnDone: true);
  }

  Future<void> clearUser() async {
    _hasManualMutation = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('snfc_registered');
    await prefs.remove('snfc_name');
    await prefs.remove('snfc_email');
    await prefs.remove('snfc_balance');
    await prefs.remove('snfc_card_id');
    await prefs.remove('snfc_active_card_id');
    await prefs.remove('snfc_transactions_json');
    await prefs.remove('snfc_cards_json');
    await prefs.remove('snfc_jcop_uid');
    await prefs.remove('snfc_lifecycle_state');
    await prefs.remove('snfc_pin_retries');
    await prefs.remove('snfc_identity_json');
    await prefs.remove('snfc_last_card_json');
    await prefs.remove('snfc_pin');
    await prefs.remove('jcop_used_token_ids');
    state = UserState();
  }

  /// Updates the in-memory JCOP hardware state after a successful NFC tap.
  void updateJcopCardInfo({
    required String uid,
    int pinRetriesLeft = -1,
    String lifecycleState = 'op_ready',
  }) {
    _hasManualMutation = true;
    state = state.copyWith(
      jcopCardUid: uid,
      pinRetriesLeft: pinRetriesLeft,
      cardLifecycleState: lifecycleState,
    );
    _persistState();
  }

  // ── Sar-E order management ──────────────────────────────────────────────

  void setSarEOrder(SarEPendingOrder? order) {
    state = state.copyWith(sarePendingOrder: () => order);
  }

  void clearSarEOrder() {
    state = state.copyWith(sarePendingOrder: () => null);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
