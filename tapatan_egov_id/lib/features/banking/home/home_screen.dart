import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/banking_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _balanceHidden = false;

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(bankingProvider);
    final fmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(bank, fmt)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // eGov Security Status
                _EGovStatusBar(bank: bank),
                const SizedBox(height: 24),

                // Quick actions
                Row(
                  children: [
                    _QuickAction(icon: Icons.add_rounded, label: 'Top Up', color: const Color(0xFF10B981), onTap: () => _showTopUp(context, ref)),
                    const SizedBox(width: 12),
                    _QuickAction(icon: Icons.send_rounded, label: 'Send', color: const Color(0xFF3B82F6), onTap: () {}),
                    const SizedBox(width: 12),
                    _QuickAction(icon: Icons.receipt_long_rounded, label: 'Bills', color: const Color(0xFFF59E0B), onTap: () {}),
                    const SizedBox(width: 12),
                    _QuickAction(icon: Icons.more_horiz_rounded, label: 'More', color: const Color(0xFF8B5CF6), onTap: () {}),
                  ],
                ),
                const SizedBox(height: 28),

                Text('Recent Transactions',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),

                if (bank.transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text('No transactions yet', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else
                  ...bank.transactions.map((tx) => _TxCard(tx: tx)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BankingState bank, NumberFormat fmt) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF001854), Color(0xFF003087), Color(0xFF080F1E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: Text(bank.name.isNotEmpty ? bank.name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good ${_greeting()}, ${bank.name.split(' ').first}',
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
                        Text('eGov Verified Account',
                          style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0030A0), Color(0xFF0050C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x440050C8), blurRadius: 30, offset: Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Total Balance', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                          child: Icon(_balanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _balanceHidden ? '₱ •••,•••.••' : fmt.format(bank.balance),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _BalanceStat('Sent', bank.totalSent, const Color(0xFFF87171)),
                        const SizedBox(width: 20),
                        _BalanceStat('Received', bank.totalReceived, const Color(0xFF34D399)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  void _showTopUp(BuildContext context, WidgetRef ref) {
    final amtCtrl = TextEditingController(text: '1000');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1A30),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Top Up Balance', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Logged on eGovChain automatically', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                prefixText: '₱ ', prefixStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 20),
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 28),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                if (amt > 0) {
                  ref.read(bankingProvider.notifier).topUp(amt);
                  Navigator.pop(ctx);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text('Top Up', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _BalanceStat(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        Text('₱${amount.toStringAsFixed(0)}', style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EGovStatusBar extends StatelessWidget {
  final BankingState bank;
  const _EGovStatusBar({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: Color(0xFF34D399), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'eGov Verified · PSN ${bank.philsysNumber} · SSO Active',
              style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('SECURE', style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final BankTransaction tx;
  const _TxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isOut = tx.amount < 0;
    final color = isOut ? const Color(0xFFF87171) : const Color(0xFF34D399);
    final icon = tx.type == TxType.bills ? Icons.receipt_long_rounded
        : tx.type == TxType.topup ? Icons.add_circle_outline_rounded
        : isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Row(
                  children: [
                    Text(tx.subtitle, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                    if (tx.riskLevel != 'LOW') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (tx.riskLevel == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tx.riskLevel, style: GoogleFonts.inter(
                          color: tx.riskLevel == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    if (tx.chainBlockHash.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.link_rounded, size: 10, color: Color(0xFF10B981)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isOut ? '-' : '+'}₱${tx.amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
