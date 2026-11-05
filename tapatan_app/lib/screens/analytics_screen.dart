import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../utils/lucide_icons.dart';
import '../providers/user_provider.dart';

// ── Analytics Screen ──────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _isWeek = true;

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF34D399);
  static const _amber = Color(0xFFF59E0B);

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthWeeks = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];

  List<String> get _barLabels => _isWeek ? _weekDays : _monthWeeks;

  List<double> _computeBars(UserState user) {
    final totalExp = user.totalExpenses;
    if (_isWeek) {
      if (totalExp <= 0) return const [0, 0, 0, 0, 0, 0, 0];
      return [
        totalExp * 0.10,
        totalExp * 0.08,
        totalExp * 0.15,
        totalExp * 0.12,
        totalExp * 0.20,
        totalExp * 0.15,
        totalExp * 0.20,
      ];
    } else {
      if (totalExp <= 0) return const [0, 0, 0, 0];
      return [
        totalExp * 0.20,
        totalExp * 0.25,
        totalExp * 0.20,
        totalExp * 0.35,
      ];
    }
  }

  double _computeNfcSpent(UserState user) => user.transactions
      .where((t) => t.amount < 0 && t.type == 'nfc')
      .fold(0.0, (s, t) => s + t.amount.abs());

  double _computeTransferSpent(UserState user) => user.transactions
      .where((t) => t.amount < 0 && t.type != 'nfc')
      .fold(0.0, (s, t) => s + t.amount.abs());

  double _computeSarESpent(UserState user) => user.transactions
      .where((t) =>
          t.amount < 0 &&
          (t.name.toLowerCase().contains('sari') ||
              t.name.toLowerCase().contains('sar-e') ||
              t.name.toLowerCase().contains('aling nena')))
      .fold(0.0, (s, t) => s + t.amount.abs());

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final barData = _computeBars(user);
    final maxBar = barData.reduce((a, b) => a > b ? a : b);
    final totalSpent = user.totalExpenses;
    final totalIncome = user.totalIncome;
    final nfcSpent = _computeNfcSpent(user);
    final transferSpent = _computeTransferSpent(user);
    final sarESpending = _computeSarESpent(user);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Analytics', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  // Period selector
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        _PeriodButton(label: 'Week', active: _isWeek, onTap: () => setState(() => _isWeek = true)),
                        _PeriodButton(label: 'Month', active: !_isWeek, onTap: () => setState(() => _isWeek = false)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Available Money Sync Banner ───────────────────────
                _GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Money (${user.name.isNotEmpty ? user.name : "Account"})',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${user.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _green.withOpacity(0.35)),
                        ),
                        child: const Text(
                          'Synced',
                          style: TextStyle(
                            color: _green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Summary row ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: _isWeek ? 'Total Spent' : 'Monthly Spent',
                        value: '₱${totalSpent.toStringAsFixed(2)}',
                        icon: LucideIcons.arrowUpRight,
                        color: const Color(0xFFF87171),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: _isWeek ? 'Total Income' : 'Monthly Income',
                        value: '₱${totalIncome.toStringAsFixed(2)}',
                        icon: LucideIcons.arrowDownLeft,
                        color: _green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Bar chart ─────────────────────────────────────────
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spending Overview', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _isWeek ? 'Day-by-day breakdown' : 'Week-by-week breakdown',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxBar > 0 ? maxBar * 1.3 : 100.0,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: Colors.white.withOpacity(0.06),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= _barLabels.length) return const SizedBox.shrink();
                                    return Text(
                                      _barLabels[i],
                                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
                                    );
                                  },
                                  reservedSize: 24,
                                ),
                              ),
                            ),
                            barGroups: List.generate(barData.length, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: barData[i],
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0369A1), Color(0xFF06B6D4)],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: _isWeek ? 22 : 40,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Breakdown by category ─────────────────────────────
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('By Category', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _CategoryRow(
                        icon: LucideIcons.wifi,
                        label: 'NFC Pay',
                        amount: nfcSpent,
                        color: _teal,
                        total: totalSpent,
                      ),
                      const SizedBox(height: 12),
                      _CategoryRow(
                        icon: LucideIcons.arrowUpRight,
                        label: 'Transfers',
                        amount: transferSpent,
                        color: const Color(0xFF8B5CF6),
                        total: totalSpent,
                      ),
                      const SizedBox(height: 12),
                      _CategoryRow(
                        icon: LucideIcons.store,
                        label: 'Sar-E Purchases',
                        amount: sarESpending,
                        color: _amber,
                        total: totalSpent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sar-E spending section ────────────────────────────
                _GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _amber.withOpacity(0.3)),
                        ),
                        child: Icon(LucideIcons.store, color: _amber, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sar-E Purchases', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(
                              _isWeek ? 'This week' : 'This month',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${sarESpending.toStringAsFixed(2)}',
                        style: TextStyle(color: _amber, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── NFC pay count ─────────────────────────────────────
                _GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _teal.withOpacity(0.3)),
                        ),
                        child: Icon(LucideIcons.nfc, color: _teal, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NFC Transactions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('${user.nfcPayCount} taps total', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(
                        '${user.nfcPayCount}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Button ─────────────────────────────────────────────────────────

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)])
              : null,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0369A1).withOpacity(0.18),
            const Color(0xFF0891B2).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Glass Card ────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0369A1).withOpacity(0.18),
            const Color(0xFF0891B2).withOpacity(0.10),
            const Color(0xFF06B6D4).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.22)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0369A1).withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  final double total;

  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
            Text(
              '₱${amount.toStringAsFixed(0)}',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
