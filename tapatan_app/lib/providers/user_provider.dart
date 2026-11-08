import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/account_backend_service.dart';
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
      id: (json['id'] ?? 'tx-${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
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
    final rawHolder = (json['holderName'] ?? '').toString().trim();
    final safeHolder =
        (rawHolder.isEmpty || rawHolder.toLowerCase() == 'richard')
            ? 'TAPAT MEMBER'
            : rawHolder;
    return CardData(
      id: (json['id'] ?? 'card-1').toString(),
      provider: (json['provider'] ?? 'Tapat JCOP4').toString(),
      cardNumber: (json['cardNumber'] ?? '4532 •••• •••• 8821').toString(),
      holderName: safeHolder,
      expiry: (json['expiry'] ?? '12/28').toString(),
      cvv: (json['cvv'] ?? '882').toString(),
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
    CardData chosen;
    try {
      chosen = virtualCards.firstWhere((c) => c.id == activeCardId);
    } catch (_) {
      chosen = virtualCards.first;
    }
    if (name.trim().isNotEmpty) {
      return chosen.copyWith(holderName: name.trim().toUpperCase());
    }
    return chosen;
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
    _loadActiveSession();
  }

  Future<void> reloadFromPrefs() => _loadActiveSession(force: true);

  Future<void> _loadActiveSession({bool force = false}) async {
    if (_hasManualMutation && !force) return;
    final activeAccount = await AccountBackendService.getActiveSessionAccount();
    if (activeAccount == null) {
      if (!_hasManualMutation || force) {
        state = UserState();
      }
      return;
    }
    await applyAuthenticatedAccount(activeAccount, armed: state.cardArmed);
  }

  /// Hydrates [UserState] from an authenticated [AccountRecord] in the
  /// persistent account database, guaranteeing real cardholder names and
  /// complete transaction history.
  Future<void> applyAuthenticatedAccount(
    AccountRecord account, {
    bool armed = false,
  }) async {
    _hasManualMutation = true;
    final cfg = await AccountBackendService.getConfig();
    final syncedCards =
        AccountBackendService.sanitizeAndSyncCards(account, cfg);

    state = UserState(
      name: account.name,
      email: account.email,
      balance: account.balance,
      transactions: account.transactions,
      virtualCards: syncedCards,
      activeCardId: account.activeCardId.isNotEmpty
          ? account.activeCardId
          : (syncedCards.isNotEmpty ? syncedCards.first.id : ''),
      cardArmed: armed,
      sessionTxnDone: false,
      cardId: account.cardId,
      pinRetriesLeft: account.pinRetriesLeft,
      cardLifecycleState: account.cardLifecycleState,
      jcopCardUid: account.jcopCardUid,
    );
  }

  List<CardData> _syncCardsWithBalance(
    List<CardData> cards,
    double newBalance, {
    String? holderName,
  }) {
    final cleanUpper = (holderName ?? state.name).trim().toUpperCase();
    if (cards.isEmpty && cleanUpper.isNotEmpty) {
      return [
        AccountBackendService.buildDefaultCardForAccount(
          name: holderName ?? state.name,
          cardId: state.cardId,
          balance: newBalance,
        ),
      ];
    }
    if (cards.isEmpty) return cards;

    final activeId = state.activeCardId.isNotEmpty
        ? state.activeCardId
        : cards.first.id;
    return cards.map((c) {
      final resolvedHolder = cleanUpper.isNotEmpty ? cleanUpper : c.holderName;
      if (c.id == activeId || cards.length == 1) {
        return c.copyWith(balance: newBalance, holderName: resolvedHolder);
      }
      return c.copyWith(holderName: resolvedHolder);
    }).toList();
  }

  Future<void> _persistState() async {
    await AccountBackendService.syncAccountFromUserState(state);
    if (state.email.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('snfc_name', state.name);
      await prefs.setString('snfc_email', state.email);
      if (state.cardId.isNotEmpty) {
        await prefs.setString('snfc_card_id', state.cardId);
      }
      if (state.jcopCardUid.isNotEmpty) {
        await prefs.setString('snfc_jcop_uid', state.jcopCardUid);
      }
    }
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
    final cleanInputHolder = card.holderName.trim();
    final effectiveHolder = (cleanInputHolder.isNotEmpty &&
            cleanInputHolder.toLowerCase() != 'richard' &&
            cleanInputHolder.toLowerCase() != 'cardholder')
        ? cleanInputHolder.toUpperCase()
        : (state.name.isNotEmpty ? state.name.toUpperCase() : 'TAPAT MEMBER');
    final syncedCard = card.copyWith(
      holderName: effectiveHolder,
      balance: state.balance,
    );
    final updatedCards = [...state.virtualCards, syncedCard];
    state = state.copyWith(
      virtualCards: updatedCards,
      activeCardId:
          state.activeCardId.isNotEmpty ? state.activeCardId : syncedCard.id,
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

  /// Signs out of the active session while keeping 100% of the account's
  /// profile, balance, cards, and transaction history stored in the database.
  Future<void> signOut() async {
    _hasManualMutation = true;
    await AccountBackendService.syncAccountFromUserState(state);
    await AccountBackendService.signOut();
    state = UserState();
  }

  /// Preserved for caller compatibility — signs out safely without deleting
  /// stored database records.
  Future<void> clearUser() => signOut();

  /// Updates the cardholder's profile name and persists it across virtual
  /// cards and the account database.
  void updateProfileName(String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'richard') return;
    _hasManualMutation = true;
    state = state.copyWith(
      name: trimmed,
      virtualCards: _syncCardsWithBalance(
        state.virtualCards,
        state.balance,
        holderName: trimmed,
      ),
    );
    _persistState();
  }

  /// Updates the in-memory JCOP hardware state after a successful NFC tap.
  void updateJcopCardInfo({
    required String uid,
    String? cardId,
    int pinRetriesLeft = -1,
    String lifecycleState = 'op_ready',
  }) {
    _hasManualMutation = true;
    state = state.copyWith(
      jcopCardUid: uid,
      cardId: (cardId != null && cardId.isNotEmpty) ? cardId : state.cardId,
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
