import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

// ── Analytics Screen ────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _timeframe = '7 Days';

  static const _timeframes = ['7 Days', '30 Days', 'Year'];

  static const _labels7Days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _labels30Days = ['W1', 'W2', 'W3', 'W4'];
  static const _labelsYear = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];

  List<String> get _currentLabels {
    switch (_timeframe) {
      case '30 Days':
        return _labels30Days;
      case 'Year':
        return _labelsYear;
      case '7 Days':
      default:
        return _labels7Days;
    }
  }

  // Baseline data shapes from React AnalyticsScreen.tsx
  List<double> _getSpendData(UserState user) {
    final exp = user.totalExpenses;
    switch (_timeframe) {
      case '30 Days':
        final base = [920.0, 1240.0, 780.0, 1105.0];
        if (exp <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * exp).toList();
      case 'Year':
        final base = [3900.0, 4100.0, 4600.0, 3800.0, 5200.0, 4700.0, 4400.0, 5100.0];
        if (exp <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * (exp * 2.8)).toList();
      case '7 Days':
      default:
        final base = [145.0, 88.0, 210.0, 13.0, 330.0, 175.0, 96.0];
        if (exp <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * exp).toList();
    }
  }

  List<double> _getIncomeData(UserState user) {
    final inc = user.totalIncome;
    switch (_timeframe) {
      case '30 Days':
        final base = [1500.0, 800.0, 2500.0, 1750.0];
        if (inc <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * inc).toList();
      case 'Year':
        final base = [5200.0, 4800.0, 6100.0, 5500.0, 7000.0, 6400.0, 5900.0, 6800.0];
        if (inc <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * (inc * 2.8)).toList();
      case '7 Days':
      default:
        final base = [0.0, 500.0, 0.0, 1000.0, 0.0, 250.0, 0.0];
        if (inc <= 0) return base;
        final baseSum = base.fold(0.0, (a, b) => a + b);
        return base.map((v) => (v / baseSum) * inc).toList();
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
              t.name.toLowerCase().contains('aling nena') ||
              t.name.toLowerCase().contains('coop') ||
              t.name.toLowerCase().contains('store')))
      .fold(0.0, (s, t) => s + t.amount.abs());

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final totalSpent = user.totalExpenses;
    final totalIncome = user.totalIncome;
    final nfcSpent = _computeNfcSpent(user);
    final transferSpent = _computeTransferSpent(user);
    final sarESpent = _computeSarESpent(user);

    final spendPoints = _getSpendData(user);
    final incomePoints = _getIncomeData(user);

    double maxVal = 100.0;
    for (final v in spendPoints) {
      if (v > maxVal) maxVal = v;
    }
    for (final v in incomePoints) {
      if (v > maxVal) maxVal = v;
    }
    maxVal = maxVal * 1.25;

    final verifiedTaps = user.nfcPayCount + 38;

    // Categories breakdown percentages
    final effectiveTotal = totalSpent > 0 ? totalSpent : 100.0;
    final catSarEPct = totalSpent > 0 ? ((sarESpent / effectiveTotal) * 100).round() : 46;
    final catNfcPct = totalSpent > 0 ? ((nfcSpent / effectiveTotal) * 100).round() : 22;
    final catTransferPct = totalSpent > 0 ? ((transferSpent / effectiveTotal) * 100).round() : 12;
    final catUtilsPct = (100 - (catSarEPct + catNfcPct + catTransferPct)).clamp(10, 30);

    final categories = [
      _CatData('Food & Sar-E', catSarEPct, const Color(0xFF22D3EE), sarESpent),
      _CatData('NFC Transit & Taps', catNfcPct, const Color(0xFF34D399), nfcSpent),
      _CatData('Utilities & Bills', catUtilsPct, const Color(0xFF818CF8), effectiveTotal * (catUtilsPct / 100)),
      _CatData('Transfers', catTransferPct, const Color(0xFFF59E0B), transferSpent),
    ];

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Title & Timeframe Selector ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.screenPad, 12, T.screenPad, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: T.h1),
                  const SizedBox(height: 12),

                  // Timeframe tabs: 7 Days / 30 Days / Year (Preserves Week/Month)
                  Glass(
                    kind: GlassKind.pill,
                    radius: 16,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: _timeframes.map((tf) {
                        final isSelected = _timeframe == tf;
                        return Expanded(
                          child: PressScale(
                            onTap: () => setState(() => _timeframe = tf),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? T.white(0.20) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: T.white(0.28), width: 0.5)
                                    : null,
                              ),
                              child: Text(
                                tf,
                                style: T.text(
                                  12.5,
                                  w: T.w600,
                                  color: isSelected ? Colors.white : T.white(0.55),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content List ───────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              T.screenPad,
              8,
              T.screenPad,
              T.navBottomPad + MediaQuery.of(context).padding.bottom + 20,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Available Money Sync Card ─────────────────────────────
                Glass(
                  kind: GlassKind.glass,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Money (${user.name.trim().isNotEmpty ? user.name.trim() : "Account"})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.caption.copyWith(color: T.white(0.55), fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₱${user.balance.toStringAsFixed(2)}',
                                style: T.mono(24, w: T.w800, color: T.cyan300),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Badge2('Synced · TPT4', color: T.emerald400),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Spent / Income Cards Row ──────────────────────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Glass(
                          kind: GlassKind.glass,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(LucideIcons.arrowUpRight, color: T.red400, size: 18),
                                  Text(
                                    _timeframe == '7 Days'
                                        ? '7D'
                                        : (_timeframe == '30 Days' ? '30D' : '1Y'),
                                    style: T.mono(10, color: T.white(0.40)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '₱${totalSpent.toStringAsFixed(2)}',
                                  style: T.mono(18, w: T.w800, color: T.red400),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timeframe == '7 Days'
                                    ? 'Weekly Spent'
                                    : (_timeframe == '30 Days' ? 'Monthly Spent' : 'Total Spent'),
                                style: T.caption.copyWith(color: T.white(0.50)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Glass(
                          kind: GlassKind.glass,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(LucideIcons.arrowDownLeft, color: T.emerald300, size: 18),
                                  Text(
                                    _timeframe == '7 Days'
                                        ? '7D'
                                        : (_timeframe == '30 Days' ? '30D' : '1Y'),
                                    style: T.mono(10, color: T.white(0.40)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '₱${totalIncome.toStringAsFixed(2)}',
                                  style: T.mono(18, w: T.w800, color: T.emerald300),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timeframe == '7 Days'
                                    ? 'Weekly Income'
                                    : (_timeframe == '30 Days' ? 'Monthly Income' : 'Total Income'),
                                style: T.caption.copyWith(color: T.white(0.50)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Area Chart: Income vs. NFC Spend (1:1 with React AreaChart) ──
                Glass(
                  kind: GlassKind.glass,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Income vs. NFC spend', style: T.text(14, w: T.w700)),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34D399),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Income', style: T.caption.copyWith(color: T.emerald300, fontSize: 10)),
                              const SizedBox(width: 12),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22D3EE),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Spend', style: T.caption.copyWith(color: T.cyan300, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: maxVal,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxVal / 3,
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: T.white(0.06),
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
                                  reservedSize: 24,
                                  interval: 1,
                                  getTitlesWidget: (val, meta) {
                                    final i = val.toInt();
                                    final labels = _currentLabels;
                                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                                    return Text(
                                      labels[i],
                                      style: T.caption.copyWith(color: T.white(0.50), fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xDD141C32),
                                tooltipRoundedRadius: 14,
                                tooltipBorder: BorderSide(color: T.white(0.20)),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final isInc = spot.barIndex == 0;
                                    return LineTooltipItem(
                                      '${isInc ? "Income" : "Spend"}: ₱${spot.y.toStringAsFixed(0)}',
                                      TextStyle(
                                        color: isInc ? const Color(0xFF34D399) : const Color(0xFF22D3EE),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              // Income (Emerald #34D399)
                              LineChartBarData(
                                spots: List.generate(
                                  incomePoints.length,
                                  (i) => FlSpot(i.toDouble(), incomePoints[i]),
                                ),
                                isCurved: true,
                                curveSmoothness: 0.35,
                                color: const Color(0xFF34D399),
                                barWidth: 2.5,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF34D399).withValues(alpha: 0.40),
                                      const Color(0xFF34D399).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                              // Spend (Cyan #22D3EE)
                              LineChartBarData(
                                spots: List.generate(
                                  spendPoints.length,
                                  (i) => FlSpot(i.toDouble(), spendPoints[i]),
                                ),
                                isCurved: true,
                                curveSmoothness: 0.35,
                                color: const Color(0xFF22D3EE),
                                barWidth: 2.5,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF22D3EE).withValues(alpha: 0.40),
                                      const Color(0xFF22D3EE).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── "Where it goes" / By Category (Pie + Progress Bars) ─────
                Glass(
                  kind: GlassKind.glass,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Where it goes', style: T.text(14, w: T.w700)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Donut Chart
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 32,
                                sections: categories.map((c) {
                                  return PieChartSectionData(
                                    value: c.pct.toDouble(),
                                    color: c.color,
                                    radius: 18,
                                    showTitle: false,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Category Progress Bars
                          Expanded(
                            child: Column(
                              children: categories.map((c) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            c.name,
                                            style: T.caption.copyWith(color: T.white(0.75)),
                                          ),
                                          Text(
                                            '${c.pct}%',
                                            style: T.mono(11, w: T.w700, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: (c.pct / 100).clamp(0.0, 1.0),
                                          backgroundColor: T.white(0.10),
                                          valueColor: AlwaysStoppedAnimation<Color>(c.color),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Sar-E Purchases Banner ────────────────────────────────
                Glass(
                  kind: GlassKind.glass,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: T.op(T.amber500, 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: T.op(T.amber500, 0.30)),
                        ),
                        child: const Icon(LucideIcons.store, color: T.amber300, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sar-E Purchases', style: T.text(14, w: T.w600)),
                            Text(
                              _timeframe == '7 Days' ? 'This week' : 'Selected timeframe',
                              style: T.caption.copyWith(color: T.white(0.40)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${sarESpent.toStringAsFixed(2)}',
                        style: T.mono(18, w: T.w800, color: T.amber300),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── NFC Taps Banner ───────────────────────────────────────
                Glass(
                  kind: GlassKind.glass,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: T.op(T.cyan500, 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: T.op(T.cyan500, 0.30)),
                        ),
                        child: const Icon(LucideIcons.nfc, color: T.cyan300, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NFC Transactions', style: T.text(14, w: T.w600)),
                            Text(
                              '${user.nfcPayCount} taps completed',
                              style: T.caption.copyWith(color: T.white(0.40)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${user.nfcPayCount}',
                        style: T.mono(24, w: T.w800, color: T.cyan300),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Card Security & Tap Telemetry (1:1 with React Analytics) ─
                Glass(
                  kind: GlassKind.tint,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, size: 18, color: T.emerald300),
                          const SizedBox(width: 8),
                          Text(
                            'Card security & tap telemetry',
                            style: T.text(14, w: T.w700, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: T.blk(0.25),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Turing-verified taps',
                                    style: T.caption.copyWith(color: T.white(0.50)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$verifiedTaps',
                                    style: T.mono(24, w: T.w800, color: T.emerald300),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: T.blk(0.25),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rejected MACs',
                                    style: T.caption.copyWith(color: T.white(0.50)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '0',
                                    style: T.mono(24, w: T.w800, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

class _CatData {
  final String name;
  final int pct;
  final Color color;
  final double amount;
  _CatData(this.name, this.pct, this.color, this.amount);
}
