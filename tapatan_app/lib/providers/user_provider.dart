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

  UserState({
    this.name = '',
    this.email = '',
    this.balance = 0.0,
    this.transactions = const [],
    this.virtualCards = const [],
    this.activeCardId = '',
    this.cardArmed = false,
    this.sessionTxnDone = false,
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

  UserState copyWith({
    String? name,
    String? email,
    double? balance,
    List<TransactionData>? transactions,
    List<CardData>? virtualCards,
    String? activeCardId,
    bool? cardArmed,
    bool? sessionTxnDone,
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
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(UserState()) {
    _loadFromPrefs();
  }


  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;

    if (!isRegistered) {
      // No account — keep state completely empty
      state = UserState();
      return;
    }

    final name = prefs.getString('snfc_name') ?? '';
    final email = prefs.getString('snfc_email') ?? '';
    final balance = prefs.getDouble('snfc_balance') ?? 0.0;

    state = state.copyWith(
      name: name,
      email: email,
      balance: balance,
      virtualCards: const [],
      activeCardId: '',
      transactions: const [],
    );
  }

  Future<void> setUserData(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('snfc_name', name);
    await prefs.setString('snfc_email', email);

    // New account starts clean — no cards, no transactions, ₱0 balance
    state = state.copyWith(
      name: name,
      email: email,
      balance: 0.0,
      virtualCards: const [],
      activeCardId: '',
      transactions: const [],
      cardArmed: false,
      sessionTxnDone: false,
    );
    await prefs.setDouble('snfc_balance', 0.0);
  }

  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('snfc_balance', state.balance);
  }

  void topUp(double amount) {
    if (amount <= 0) return;
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
      balance: state.balance + amount,
      transactions: [newTx, ...state.transactions],
    );
    _saveBalance();
  }

  void sendMoney(double amount, {String recipient = 'Transfer', String type = 'send'}) {
    if (amount <= 0 || state.balance < amount) return;
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
      balance: state.balance - amount,
      transactions: [newTx, ...state.transactions],
      sessionTxnDone: type == 'nfc' ? true : state.sessionTxnDone,
      cardArmed: type == 'nfc' ? false : state.cardArmed,
    );
    _saveBalance();
  }

  void receiveAmount(double amount, {String sender = 'Transfer'}) {
    if (amount <= 0) return;
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
      balance: state.balance + amount,
      transactions: [newTx, ...state.transactions],
    );
    _saveBalance();
  }

  void addVirtualCard(CardData card) {
    state = state.copyWith(
      virtualCards: [...state.virtualCards, card],
    );
  }

  void deleteCard(String id) {
    final newCards = state.virtualCards.where((c) => c.id != id).toList();
    String newActiveId = state.activeCardId;
    if (newActiveId == id && newCards.isNotEmpty) {
      newActiveId = newCards.first.id;
    }
    state = state.copyWith(virtualCards: newCards, activeCardId: newActiveId);
  }

  void setActiveCard(String id) {
    state = state.copyWith(activeCardId: id);
  }

  void armCard() {
    state = state.copyWith(cardArmed: true, sessionTxnDone: false);
  }

  void completeTransaction() {
    state = state.copyWith(cardArmed: false, sessionTxnDone: true);
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('snfc_registered');
    await prefs.remove('snfc_name');
    await prefs.remove('snfc_email');
    await prefs.remove('snfc_balance');
    state = UserState();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
