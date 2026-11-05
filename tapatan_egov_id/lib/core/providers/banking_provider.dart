import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/egov_api.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum TxType { transfer, bills, topup, receive }
enum ApprovalStatus { pending, approved, rejected }

class BankTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final TxType type;
  final DateTime timestamp;
  final String riskLevel; // LOW / MEDIUM / HIGH
  final String chainBlockHash;

  BankTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.riskLevel = 'LOW',
    this.chainBlockHash = '',
  });
}

class ApprovalRequest {
  final String id;
  final String action;
  final String description;
  final double amount;
  final String approvalCode;
  final DateTime createdAt;
  ApprovalStatus status;

  ApprovalRequest({
    required this.id,
    required this.action,
    required this.description,
    required this.amount,
    required this.approvalCode,
    required this.createdAt,
    this.status = ApprovalStatus.pending,
  });
}

// ─── Banking State ────────────────────────────────────────────────────────────

class BankingState {
  final bool isRegistered;
  final bool isLoggedIn;
  final String name;
  final String philsysNumber;
  final String ssoToken;
  final double balance;
  final List<BankTransaction> transactions;
  final List<ApprovalRequest> approvals;
  final List<Map<String, dynamic>> chainEvents;
  final int confidenceScore;

  const BankingState({
    this.isRegistered = false,
    this.isLoggedIn = false,
    this.name = '',
    this.philsysNumber = '',
    this.ssoToken = '',
    this.balance = 0.0,
    this.transactions = const [],
    this.approvals = const [],
    this.chainEvents = const [],
    this.confidenceScore = 0,
  });

  int get pendingApprovalCount =>
      approvals.where((a) => a.status == ApprovalStatus.pending).length;

  double get totalSent => transactions
      .where((t) => t.amount < 0)
      .fold(0.0, (s, t) => s + t.amount.abs());

  double get totalReceived => transactions
      .where((t) => t.amount > 0)
      .fold(0.0, (s, t) => s + t.amount);

  BankingState copyWith({
    bool? isRegistered,
    bool? isLoggedIn,
    String? name,
    String? philsysNumber,
    String? ssoToken,
    double? balance,
    List<BankTransaction>? transactions,
    List<ApprovalRequest>? approvals,
    List<Map<String, dynamic>>? chainEvents,
    int? confidenceScore,
  }) {
    return BankingState(
      isRegistered: isRegistered ?? this.isRegistered,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      philsysNumber: philsysNumber ?? this.philsysNumber,
      ssoToken: ssoToken ?? this.ssoToken,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      approvals: approvals ?? this.approvals,
      chainEvents: chainEvents ?? this.chainEvents,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}

// ─── Result Types ─────────────────────────────────────────────────────────────

class RegisterResult {
  final bool success;
  final String? errorMessage;
  final String? psn;
  final int? confidenceScore;
  final List<Map<String, dynamic>> apiLogs;
  RegisterResult({required this.success, this.errorMessage, this.psn, this.confidenceScore, this.apiLogs = const []});
}

class LoginResult {
  final bool success;
  final String? errorMessage;
  final bool anomalyDetected;
  final List<Map<String, dynamic>> apiLogs;
  LoginResult({required this.success, this.errorMessage, this.anomalyDetected = false, this.apiLogs = const []});
}

class TransferResult {
  final bool success;
  final bool needsApproval;
  final String? approvalId;
  final String? errorMessage;
  final String riskLevel;
  final List<Map<String, dynamic>> apiLogs;
  TransferResult({
    required this.success,
    this.needsApproval = false,
    this.approvalId,
    this.errorMessage,
    this.riskLevel = 'LOW',
    this.apiLogs = const [],
  });
}


// ─── Notifier ─────────────────────────────────────────────────────────────────

class BankingNotifier extends StateNotifier<BankingState> {
  BankingNotifier() : super(const BankingState()) {
    _loadFromPrefs();
  }

  final _uuid = const Uuid();

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getBool('egov_registered') ?? false;
    if (!registered) return;

    state = state.copyWith(
      isRegistered: true,
      name: prefs.getString('egov_name') ?? '',
      philsysNumber: prefs.getString('egov_psn') ?? '',
      ssoToken: prefs.getString('egov_sso_token') ?? '',
      balance: prefs.getDouble('egov_balance') ?? 5000.0,
      confidenceScore: prefs.getInt('egov_confidence') ?? 97,
    );
  }

  // ── REGISTER ───────────────────────────────────────────────────────────────
  
  Future<Map<String, dynamic>> connectSSO() async {
    // This is now handled by deep link in UI, but kept here for fallback API if needed
    return {'success': false, 'error': 'Use deep link in UI'};
  }

  Future<RegisterResult> register({
    required String name,
    required String philsysNumber,
    required String pin,
    required String ssoToken,
    required List<Map<String, dynamic>> initialLogs,
  }) async {
    // Authentication, Liveness, and eVerify were already done by the eGov app via deep link.
    // We just save the authenticated result locally.
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('egov_registered', true);
    await prefs.setString('egov_name', name);
    await prefs.setString('egov_psn', philsysNumber);
    await prefs.setString('egov_pin', pin);
    await prefs.setString('egov_sso_token', ssoToken);
    await prefs.setDouble('egov_balance', 5000.0); // starter balance

    state = state.copyWith(
      isRegistered: true,
      isLoggedIn: true,
      name: name,
      philsysNumber: philsysNumber,
      ssoToken: ssoToken,
      balance: 5000.0,
      confidenceScore: 100,
    );

    return RegisterResult(success: true, psn: philsysNumber, confidenceScore: 100, apiLogs: initialLogs);
  }

  Future<void> forceRegister({
    required String name,
    required String philsysNumber,
    required String pin,
    required String ssoToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('egov_registered', true);
    await prefs.setString('egov_name', name);
    await prefs.setString('egov_psn', philsysNumber);
    await prefs.setString('egov_pin', pin);
    await prefs.setString('egov_sso_token', ssoToken);
    await prefs.setDouble('egov_balance', 5000.0);

    state = state.copyWith(
      isRegistered: true,
      isLoggedIn: true,
      name: name,
      philsysNumber: philsysNumber,
      ssoToken: ssoToken,
      balance: 5000.0,
      confidenceScore: 100,
    );
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────────

  Future<LoginResult> login({
    required String philsysNumber,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPsn = prefs.getString('egov_psn') ?? '';
    final storedPin = prefs.getString('egov_pin') ?? '';
    final apiLogs = <Map<String, dynamic>>[];

    if (philsysNumber != storedPsn || pin != storedPin) {
      return LoginResult(success: false, errorMessage: 'Invalid PhilSys number or PIN', apiLogs: apiLogs);
    }

    // Step 1: SSO validate (Mocked for deep link architecture)
    final storedToken = prefs.getString('egov_sso_token') ?? '';

    state = state.copyWith(
      isLoggedIn: true,
      name: prefs.getString('egov_name') ?? '',
      philsysNumber: philsysNumber,
      ssoToken: storedToken,
      balance: prefs.getDouble('egov_balance') ?? 5000.0,
      confidenceScore: prefs.getInt('egov_confidence') ?? 97,
      chainEvents: [
        ...state.chainEvents,
        {'type': 'LOGIN', 'hash': 'MOCK_LOGIN_HASH', 'time': DateTime.now().toIso8601String()},
      ],
    );

    return LoginResult(success: true, anomalyDetected: false, apiLogs: apiLogs);
  }


  // ── TRANSFER ───────────────────────────────────────────────────────────────

  Future<TransferResult> initiateTransfer({
    required String recipientName,
    required String recipientAccount,
    required double amount,
  }) async {
    if (amount <= 0 || state.balance < amount) {
      return TransferResult(success: false, errorMessage: 'Insufficient balance or invalid amount');
    }

    // Step 1: eGovAI risk check
    final aiRes = await EGovAiService.analyzeRisk(
      philsysNumber: state.philsysNumber,
      requestType: 'PAYMENT_AUTH',
      context: {
        'amount': amount,
        'recipient': recipientAccount,
        'hour': DateTime.now().hour,
      },
    );
    final riskLevel = aiRes.data['riskLevel'] as String? ?? 'LOW';
    final recommendation = aiRes.data['approvalRecommendation'] as String? ?? 'APPROVE';

    if (recommendation == 'CHALLENGE' && riskLevel == 'HIGH') {
      // HIGH risk → block transaction
      await EGovChainService.logEvent(
        eventType: 'TRANSFER_BLOCKED',
        actor: state.philsysNumber,
        metadata: {'amount': amount, 'recipient': recipientAccount, 'riskLevel': riskLevel},
      );
      return TransferResult(
        success: false,
        riskLevel: riskLevel,
        errorMessage: 'Transaction blocked by eGovAI: high-risk pattern detected.',
      );
    }

    if (riskLevel == 'MEDIUM') {
      // MEDIUM risk → eMessage approval required
      final msgRes = await EMessageService.sendApprovalRequest(
        philsysNumber: state.philsysNumber,
        action: 'PAYMENT_APPROVAL',
        requester: 'Tapatan Bank · ₱${amount.toStringAsFixed(2)} → $recipientName',
        payload: {'amount': amount, 'recipient': recipientAccount, 'currency': 'PHP'},
      );

      final approvalId = _uuid.v4();
      final approval = ApprovalRequest(
        id: approvalId,
        action: 'Transfer to $recipientName',
        description: '₱${amount.toStringAsFixed(2)} to $recipientAccount',
        amount: amount,
        approvalCode: msgRes.data['approvalCode'] as String? ?? '000000',
        createdAt: DateTime.now(),
      );

      state = state.copyWith(approvals: [approval, ...state.approvals]);

      return TransferResult(
        success: true,
        needsApproval: true,
        approvalId: approvalId,
        riskLevel: riskLevel,
      );
    }

    // LOW risk → execute immediately
    return await _executeTransfer(
      recipientName: recipientName,
      recipientAccount: recipientAccount,
      amount: amount,
      riskLevel: riskLevel,
    );
  }

  Future<TransferResult> approveAndExecuteTransfer({
    required String approvalId,
    required String recipientName,
    required String recipientAccount,
    required double amount,
  }) async {
    // Mark approval as approved
    final updatedApprovals = state.approvals.map((a) {
      if (a.id == approvalId) {
        a.status = ApprovalStatus.approved;
        return a;
      }
      return a;
    }).toList();
    state = state.copyWith(approvals: updatedApprovals);

    return await _executeTransfer(
      recipientName: recipientName,
      recipientAccount: recipientAccount,
      amount: amount,
      riskLevel: 'MEDIUM',
    );
  }

  Future<TransferResult> _executeTransfer({
    required String recipientName,
    required String recipientAccount,
    required double amount,
    required String riskLevel,
  }) async {
    // eGovChain log
    final chainRes = await EGovChainService.logEvent(
      eventType: 'TRANSFER',
      actor: state.philsysNumber,
      metadata: {
        'amount': amount,
        'recipientName': recipientName,
        'recipientAccount': recipientAccount,
        'riskLevel': riskLevel,
        'currency': 'PHP',
      },
    );

    final tx = BankTransaction(
      id: _uuid.v4(),
      title: 'Sent to $recipientName',
      subtitle: recipientAccount,
      amount: -amount,
      type: TxType.transfer,
      timestamp: DateTime.now(),
      riskLevel: riskLevel,
      chainBlockHash: chainRes.data['blockHash'] as String? ?? '',
    );

    final newBalance = state.balance - amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('egov_balance', newBalance);

    state = state.copyWith(
      balance: newBalance,
      transactions: [tx, ...state.transactions],
      chainEvents: [
        ...state.chainEvents,
        {'type': 'TRANSFER', 'hash': chainRes.data['blockHash'] ?? '', 'amount': amount, 'time': DateTime.now().toIso8601String()},
      ],
    );

    return TransferResult(success: true, riskLevel: riskLevel);
  }

  // ── BILLS PAYMENT ──────────────────────────────────────────────────────────

  Future<TransferResult> payBill({
    required String billerName,
    required String accountNumber,
    required double amount,
  }) async {
    if (amount <= 0 || state.balance < amount) {
      return TransferResult(success: false, errorMessage: 'Insufficient balance');
    }

    // eGovAI check
    final aiRes = await EGovAiService.analyzeRisk(
      philsysNumber: state.philsysNumber,
      requestType: 'BILL_PAYMENT',
      context: {'biller': billerName, 'amount': amount},
    );
    final riskLevel = aiRes.data['riskLevel'] as String? ?? 'LOW';

    if (riskLevel == 'MEDIUM' || riskLevel == 'HIGH') {
      final msgRes = await EMessageService.sendApprovalRequest(
        philsysNumber: state.philsysNumber,
        action: 'BILL_PAYMENT',
        requester: '$billerName · ₱${amount.toStringAsFixed(2)}',
        payload: {'amount': amount, 'biller': billerName, 'account': accountNumber},
      );
      final approvalId = _uuid.v4();
      final approval = ApprovalRequest(
        id: approvalId,
        action: 'Pay $billerName',
        description: '₱${amount.toStringAsFixed(2)} · Acct: $accountNumber',
        amount: amount,
        approvalCode: msgRes.data['approvalCode'] as String? ?? '000000',
        createdAt: DateTime.now(),
      );
      state = state.copyWith(approvals: [approval, ...state.approvals]);
      return TransferResult(success: true, needsApproval: true, approvalId: approvalId, riskLevel: riskLevel);
    }

    // Execute directly
    final chainRes = await EGovChainService.logEvent(
      eventType: 'BILL_PAYMENT',
      actor: state.philsysNumber,
      metadata: {'biller': billerName, 'amount': amount, 'account': accountNumber},
    );

    final tx = BankTransaction(
      id: _uuid.v4(),
      title: billerName,
      subtitle: 'Account: $accountNumber',
      amount: -amount,
      type: TxType.bills,
      timestamp: DateTime.now(),
      riskLevel: riskLevel,
      chainBlockHash: chainRes.data['blockHash'] as String? ?? '',
    );

    final newBalance = state.balance - amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('egov_balance', newBalance);

    state = state.copyWith(
      balance: newBalance,
      transactions: [tx, ...state.transactions],
    );
    return TransferResult(success: true, riskLevel: riskLevel);
  }

  // ── TOP UP ─────────────────────────────────────────────────────────────────

  Future<void> topUp(double amount) async {
    if (amount <= 0) return;
    await EGovChainService.logEvent(
      eventType: 'DEPOSIT',
      actor: state.philsysNumber,
      metadata: {'amount': amount, 'source': 'GCash/Bank Transfer'},
    );
    final newBalance = state.balance + amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('egov_balance', newBalance);

    final tx = BankTransaction(
      id: _uuid.v4(),
      title: 'Top Up',
      subtitle: 'Balance loaded',
      amount: amount,
      type: TxType.topup,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(balance: newBalance, transactions: [tx, ...state.transactions]);
  }

  // ── APPROVAL ACTIONS ────────────────────────────────────────────────────────

  void rejectApproval(String approvalId) {
    final updatedApprovals = state.approvals.map((a) {
      if (a.id == approvalId) {
        a.status = ApprovalStatus.rejected;
        return a;
      }
      return a;
    }).toList();
    state = state.copyWith(approvals: updatedApprovals);
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await EGovChainService.logEvent(
      eventType: 'LOGOUT',
      actor: state.philsysNumber,
      metadata: {'app': 'TAPATAN-BANK'},
    );
    state = state.copyWith(isLoggedIn: false);
  }

  // ── FULL CLEAR (dev) ───────────────────────────────────────────────────────

  Future<void> clearAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const BankingState();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final bankingProvider = StateNotifierProvider<BankingNotifier, BankingState>(
  (ref) => BankingNotifier(),
);
