import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

// ── Analytics Screen (real account data only) ───────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _Tx {
  final TransactionData t;
  final DateTime at;
  _Tx(this.t, this.at);
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _timeframe = '7 Days';

  static const _timeframes = ['7 Days', '30 Days', 'Year'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Transaction timestamp parsed from its id (tx-millis); unknown → now.
  DateTime _timeOf(TransactionData t) {
    final m = RegExp(r'(\d{12,})').firstMatch(t.id);
    if (m != null) {
      final ms = int.tryParse(m.group(1)!);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.now();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _start {
    final d = _today;
    switch (_timeframe) {
      case '30 Days':
        return d.subtract(const Duration(days: 27));
      case 'Year':
        return DateTime(d.year, d.month - 11, 1);
      default:
        return d.subtract(const Duration(days: 6));
    }
  }

  int get _buckets => _timeframe == '30 Days' ? 4 : (_timeframe == 'Year' ? 12 : 7);

  int _bucketOf(DateTime at) {
    final start = _start;
    switch (_timeframe) {
      case '30 Days':
        return (at.difference(start).inDays ~/ 7).clamp(0, 3);
      case 'Year':
        return ((at.year - start.year) * 12 + at.month - start.month).clamp(0, 11);
      default:
        return DateTime(at.year, at.month, at.day).difference(start).inDays.clamp(0, 6);
    }
  }

  String _label(int i) {
    final start = _start;
    switch (_timeframe) {
      case '30 Days':
        return 'W${i + 1}';
      case 'Year':
        return _months[(start.month - 1 + i) % 12];
      default:
        return _days[start.add(Duration(days: i)).weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final start = _start;
    final txs = user.transactions
        .map((t) => _Tx(t, _timeOf(t)))
        .where((x) => !x.at.isBefore(start))
        .toList();

    final n = _buckets;
    final spend = List<double>.filled(n, 0);
    final income = List<double>.filled(n, 0);
    double totalSpent = 0, totalIncome = 0;
    final cats = <String, double>{};
    for (final x in txs) {
      final b = _bucketOf(x.at);
      final a = x.t.amount;
      if (a < 0) {
        spend[b] += a.abs();
        totalSpent += a.abs();
        final key = _categoryOf(x.t);
        cats[key] = (cats[key] ?? 0) + a.abs();
      } else if (a > 0) {
        income[b] += a;
        totalIncome += a;
      }
    }

    final hasData = txs.isNotEmpty;
    double maxVal = 0;
    for (final v in [...spend, ...income]) {
      if (v > maxVal) maxVal = v;
    }
    maxVal = maxVal <= 0 ? 1 : maxVal * 1.25;

    final palette = [T.teal, T.emerald400, T.amber300, T.red400, T.white(.60)];
    final entries = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categories = <_CatData>[
      for (var i = 0; i < entries.length; i++)
        _CatData(
          entries[i].key,
          totalSpent > 0 ? (entries[i].value / totalSpent * 100).round() : 0,
          palette[i % palette.length],
          entries[i].value,
        ),
    ];

    final short = _timeframe == '7 Days' ? '7D' : (_timeframe == '30 Days' ? '30D' : '1Y');

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.screenPad, 12, T.screenPad, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: T.h1),
                  const SizedBox(height: 12),
                  Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: _timeframes.map((tf) {
                        final sel = _timeframe == tf;
                        return Expanded(
                          child: PressScale(
                            onTap: () => setState(() => _timeframe = tf),
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel ? T.teal : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tf,
                                style: T.text(12.5,
                                    w: T.w600,
                                    color: sel ? Colors.white : T.white(0.55)),
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
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              T.screenPad,
              8,
              T.screenPad,
              T.navBottomPad + MediaQuery.of(context).padding.bottom + 20,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available balance',
                          style: T.caption.copyWith(color: T.white(0.55), fontSize: 12)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('₱${user.balance.toStringAsFixed(2)}',
                            style: T.mono(24, w: T.w800, color: T.teal)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!hasData)
                  _card(
                    pad: 32,
                    child: Column(
                      children: [
                        Icon(LucideIcons.arrowUpRight, size: 36, color: T.white(0.35)),
                        const SizedBox(height: 12),
                        Text('No activity yet', style: T.text(15, w: T.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Transactions will appear here after your first payment',
                          textAlign: TextAlign.center,
                          style: T.caption.copyWith(color: T.white(0.50)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _stat(LucideIcons.arrowUpRight, T.red400, short,
                              totalSpent, 'Spent'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _stat(LucideIcons.arrowDownLeft, T.emerald300, short,
                              totalIncome, 'Income'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Income vs. spend', style: T.text(14, w: T.w700)),
                            Row(children: [
                              _dot(T.emerald400),
                              const SizedBox(width: 4),
                              Text('Income',
                                  style: T.caption.copyWith(color: T.emerald300, fontSize: 10)),
                              const SizedBox(width: 12),
                              _dot(T.teal),
                              const SizedBox(width: 4),
                              Text('Spend',
                                  style: T.caption.copyWith(color: T.teal, fontSize: 10)),
                            ]),
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
                                getDrawingHorizontalLine: (_) =>
                                    FlLine(color: T.white(0.06), strokeWidth: 1),
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
                                      if (i < 0 || i >= n) return const SizedBox.shrink();
                                      return Text(_label(i),
                                          style: T.caption.copyWith(
                                              color: T.white(0.50), fontSize: 11));
                                    },
                                  ),
                                ),
                              ),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => T.surfaceStrong,
                                  getTooltipItems: (spots) => spots.map((s) {
                                    final isInc = s.barIndex == 0;
                                    return LineTooltipItem(
                                      '${isInc ? "Income" : "Spend"}: ₱${s.y.toStringAsFixed(0)}',
                                      TextStyle(
                                        color: isInc ? T.emerald400 : T.teal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              lineBarsData: [
                                _line(income, T.emerald400),
                                _line(spend, T.teal),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Where it goes', style: T.text(14, w: T.w700)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 32,
                                    sections: categories
                                        .map((c) => PieChartSectionData(
                                              value: c.amount,
                                              color: c.color,
                                              radius: 18,
                                              showTitle: false,
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
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
                                              Text(c.name,
                                                  style: T.caption.copyWith(color: T.white(0.75))),
                                              Text('${c.pct}%',
                                                  style: T.mono(11, w: T.w700, color: Colors.white)),
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
                  ],
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryOf(TransactionData t) {
    final n = t.name.toLowerCase();
    if (t.type == 'nfc') return 'Card taps';
    if (n.contains('sari') || n.contains('sar-e') || n.contains('store')) {
      return 'Store purchases';
    }
    return 'Transfers';
  }

  Widget _card({required Widget child, double pad = 18}) => Glass(
        radius: 20,
        padding: EdgeInsets.all(pad),
        child: child,
      );

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _stat(IconData icon, Color color, String tag, double v, String label) =>
      _card(
        pad: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                Text(tag, style: T.mono(10, color: T.white(0.40))),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('₱${v.toStringAsFixed(2)}',
                  style: T.mono(18, w: T.w800, color: color)),
            ),
            const SizedBox(height: 2),
            Text(label, style: T.caption.copyWith(color: T.white(0.50))),
          ],
        ),
      );

  LineChartBarData _line(List<double> pts, Color c) => LineChartBarData(
        spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i])],
        isCurved: true,
        curveSmoothness: 0.3,
        preventCurveOverShooting: true,
        color: c,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      );
}

class _CatData {
  final String name;
  final int pct;
  final Color color;
  final double amount;
  _CatData(this.name, this.pct, this.color, this.amount);
}
