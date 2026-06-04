import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../utils/lucide_icons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onArmCard;
  final Function(String)? onOpenOverlay;
  final Function(String)? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onArmCard,
    this.onOpenOverlay,
    this.onNavigateTab,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showBalance = true;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning â˜€ï¸';
    if (hour < 17) return 'Good afternoon ðŸŒ¤ï¸';
    return 'Good evening ðŸŒ™';
  }

  void _showTopUpModal(BuildContext context) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF031424), Color(0xFF020B18)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
            ),
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                final quickAmounts = [100, 500, 1000, 5000];
                double? selectedQuick;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Top Up Balance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                            child: Icon(LucideIcons.x, size: 16, color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Quick-select or enter custom amount', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    const SizedBox(height: 20),
                    // Quick amounts
                    Row(
                      children: quickAmounts.map((a) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                amountCtrl.text = a.toString();
                                setModalState(() => selectedQuick = a.toDouble());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: selectedQuick == a
                                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                      : null,
                                  color: selectedQuick != a ? Colors.white.withOpacity(0.06) : null,
                                  border: Border.all(
                                    color: selectedQuick == a
                                        ? const Color(0xFF10B981)
                                        : Colors.white.withOpacity(0.10),
                                  ),
                                ),
                                child: Text('â‚±$a', textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selectedQuick == a ? Colors.white : Colors.white.withOpacity(0.6),
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                  )),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Custom amount
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text('â‚± ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18)),
                          Expanded(
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0.00',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount != null && amount > 0) {
                          ref.read(userProvider.notifier).topUp(amount);
                          Navigator.pop(ctx);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x5010B981), blurRadius: 20, offset: Offset(0, 8))],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.arrowDownLeft, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Top Up Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showReceiveModal(BuildContext context, UserState user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF031424), Color(0xFF020B18)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Receive Money', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                    child: Icon(LucideIcons.x, size: 16, color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.qrCode, size: 64, color: Colors.white.withOpacity(0.6)),
                    const SizedBox(height: 4),
                    Text('QR Code', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCOUNT NAME', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(user.name.isNotEmpty ? user.name : 'Your Name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('ACCOUNT EMAIL', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(user.email.isNotEmpty ? user.email : 'your@email.com', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showHistoryModal(BuildContext context, UserState user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF120832), Color(0xFF0A0020)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${user.transactions.length} entries', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: user.transactions.isEmpty ? 1 : user.transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (user.transactions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(LucideIcons.activity, size: 40, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 8),
                              Text('No transactions yet', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                            ],
                          ),
                        ),
                      );
                    }
                    final tx = user.transactions[i];
                    return _buildTxRow(tx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTxRow(TransactionData tx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: tx.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tx.icon, color: tx.color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(tx.time, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${tx.amount > 0 ? "+" : ""}â‚±${tx.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: tx.amount > 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Section builders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatusBanner(UserState user) {
    final Color dotColor = user.sessionTxnDone
        ? const Color(0xFFF59E0B)
        : user.cardArmed
            ? const Color(0xFF34D399)
            : Colors.white.withOpacity(0.25);
    final Color textColor = user.sessionTxnDone
        ? const Color(0xFFF59E0B)
        : user.cardArmed
            ? const Color(0xFF34D399)
            : Colors.white.withOpacity(0.35);
    final Color borderColor = user.sessionTxnDone
        ? const Color(0xFFF59E0B).withOpacity(0.3)
        : user.cardArmed
            ? const Color(0xFF34D399).withOpacity(0.3)
            : Colors.white.withOpacity(0.07);
    final String label = user.sessionTxnDone
        ? 'Java Card  Â·  Transaction used â€” re-tap to rearm'
        : user.cardArmed
            ? 'Java Card  Â·  Armed â€” 1 transaction ready'
            : 'Java Card  Â·  Not activated';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: (user.cardArmed || user.sessionTxnDone)
            ? dotColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: (user.cardArmed || user.sessionTxnDone)
                  ? [BoxShadow(color: dotColor, blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
          ),
          Icon(LucideIcons.wifi, size: 12, color: textColor),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(UserState user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              user.name.isNotEmpty ? user.name : 'Welcome',
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Stack(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
                border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.3)),
              ),
              child: Icon(LucideIcons.bell, size: 18, color: Colors.white.withOpacity(0.8)),
            ),
            Positioned(
              top: 2, right: 2,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0891B2),
                  border: Border.all(color: const Color(0xFF020B18), width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnableTransactionCTA() {
    return GestureDetector(
      onTap: widget.onArmCard,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x700369A1), Color(0x600891B2), Color(0x5006B6D4)],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0369A1).withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: Colors.white.withOpacity(0.12),
              ),
              child: const Icon(LucideIcons.shield, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enable Transaction',
                      style: TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Tap Java Card to arm for payment',
                      style:
                          TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 18, color: Colors.white.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(UserState user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x700369A1), Color(0x580891B2), Color(0x4006B6D4)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0369A1).withOpacity(0.22),
              blurRadius: 36,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Balance',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              GestureDetector(
                onTap: () => setState(() => _showBalance = !_showBalance),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.08)),
                  child: Icon(
                      _showBalance ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 14,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Align(
              key: ValueKey(_showBalance),
              alignment: Alignment.centerLeft,
              child: Text(
                _showBalance
                    ? '\u20b1 ${user.balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}'
                    : '\u20b1 \u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildBalanceStat(
                  icon: LucideIcons.trendingUp,
                  label: 'Income',
                  value: '+\u20b1${_formatAmount(user.totalIncome)}',
                  color: const Color(0xFF34D399)),
              const SizedBox(width: 12),
              Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 12),
              _buildBalanceStat(
                  icon: LucideIcons.arrowUpRight,
                  label: 'Expenses',
                  value: user.totalExpenses > 0
                      ? '-\u20b1${_formatAmount(user.totalExpenses)}'
                      : '\u20b10.00',
                  color: const Color(0xFFF87171)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCardRow(CardData card) {
    return GestureDetector(
      onTap: () => widget.onNavigateTab?.call('cards'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0369A1).withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [card.colors[0], card.colors[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(LucideIcons.wifi, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${card.provider} Active',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${card.cardNumber} \u00b7 Ready for NFC',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 11)),
                ],
              ),
            ),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF34D399),
                boxShadow: [BoxShadow(color: Color(0xFF34D399), blurRadius: 6, spreadRadius: 1)],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight,
                size: 14, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context, UserState user) {
    final items = [
      ('Send',    LucideIcons.arrowUpRight, const Color(0xFF0369A1), const Color(0xFF0284C7),
          () => widget.onOpenOverlay?.call('send')),
      ('Receive', LucideIcons.arrowDownLeft, const Color(0xFF0891B2), const Color(0xFF06B6D4),
          () => _showReceiveModal(context, user)),
      ('NFC Pay', LucideIcons.wifi,          const Color(0xFF0E7490), const Color(0xFF0891B2),
          () => widget.onOpenOverlay?.call('nfc')),
      ('Top Up',  LucideIcons.plus,          const Color(0xFF0F766E), const Color(0xFF14B8A6),
          () => _showTopUpModal(context)),
    ];
    return Row(
      children: List.generate(items.length, (i) {
        final (label, icon, from, to, tap) = items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
            child: _buildQuickAction(label, icon, from, to, tap),
          ),
        );
      }),
    );
  }

  Widget _buildSpendingSection(UserState user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Spending',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF0891B2).withOpacity(0.3)),
                ),
                child: const Text('This week',
                    style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMiniSpendingChart(user),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, UserState user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Activity',
                style: TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => _showHistoryModal(context, user),
              child: Row(
                children: [
                  const Text('See all',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight,
                      size: 13, color: Colors.white.withOpacity(0.4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (user.transactions.isEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.activity,
                    size: 36, color: Colors.white.withOpacity(0.18)),
                const SizedBox(height: 10),
                Text('No transactions yet',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13)),
                const SizedBox(height: 4),
                Text('Start by topping up or sending money',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.22), fontSize: 11)),
              ],
            ),
          )
        else
          ...user.transactions.take(3).map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTxRow(tx),
              )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final activeCard = user.activeCard;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [

          // 1. Java Card status chip
          _buildStatusBanner(user),
          const SizedBox(height: 16),

          // 2. Greeting + bell
          _buildGreetingHeader(user),
          const SizedBox(height: 16),

          // 3. Enable Transaction CTA â€” only when not armed
          if (!user.cardArmed) ...[
            _buildEnableTransactionCTA(),
            const SizedBox(height: 14),
          ],

          // 4. Balance card
          _buildBalanceCard(user),
          const SizedBox(height: 14),

          // 5. Active card pill â€” only when a card exists
          if (activeCard != null) ...[
            _buildActiveCardRow(activeCard),
            const SizedBox(height: 14),
          ],

          // 6. Quick actions (Send / Receive / NFC Pay / Top Up)
          _buildQuickActionsRow(context, user),
          const SizedBox(height: 16),

          // 7. Weekly spending chart
          _buildSpendingSection(user),
          const SizedBox(height: 16),

          // 8. Recent activity list + empty state
          _buildRecentActivity(context, user),

        ],
      ),
    );
  }

  Widget _buildBalanceStat({required IconData icon, required String label, required String value, required Color color}) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.18)),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10)),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color from, Color to, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [from.withOpacity(0.3), to.withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.10),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }


  Widget _buildMiniSpendingChart(UserState user) {
    // Derive spending from last 7 days grouped by day-of-week
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final amounts = <double>[0, 0, 0, 0, 0, 0, 0];

    // Use real transaction data only
    for (final tx in user.transactions) {
      if (tx.amount < 0) {
        final dayIdx = DateTime.now().weekday - 1;
        if (dayIdx >= 0 && dayIdx < 7) {
          amounts[dayIdx] += tx.amount.abs();
        }
      }
    }

    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 75,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final barHeight = maxAmount > 0 ? (amounts[i] / maxAmount) * 60.0 : 10.0;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(days[i], style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }
}
