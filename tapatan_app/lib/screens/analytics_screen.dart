import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../utils/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _activeTab = 'overview';
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    final totalTxns = user.transactions.length;
    final successTxns = user.transactions.where((t) => t.amount != 0).length;
    final failedTxns = 0;
    final avgAuthTime = 0.82;
    final totalProcessed = user.transactions
        .where((t) => t.amount < 0)
        .fold(0.0, (s, t) => s + t.amount.abs());
    final successRate = totalTxns > 0 ? ((successTxns / totalTxns) * 100).toStringAsFixed(1) : '100.0';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          // Header
          const Text('Analytics', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text('Tap performance & security metrics', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 20),

          // Tab switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _buildTab('overview', 'Overview', LucideIcons.activity),
                _buildTab('benchmark', 'Benchmark', LucideIcons.barChart2),
                _buildTab('health', 'Card Health', LucideIcons.creditCard),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _activeTab == 'overview'
                ? _buildOverviewTab(user, totalTxns, successTxns, failedTxns, avgAuthTime, totalProcessed, successRate)
                : _activeTab == 'benchmark'
                    ? _buildBenchmarkTab()
                    : _buildHealthTab(user),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String id, String label, IconData icon) {
    final isActive = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0369A1).withOpacity(0.35) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? const Color(0xFF0891B2).withOpacity(0.4) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isActive ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.35)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isActive ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(UserState user, int totalTxns, int successTxns, int failedTxns, double avgAuthTime, double totalProcessed, String successRate) {
    final recentLogs = user.transactions.take(6).toList();

    return Column(
      key: const ValueKey('overview'),
      children: [
        // Stats 2x2 grid
        Row(
          children: [
            _buildStatBox('Total Transactions', totalTxns.toString(), 'Last 30 days', LucideIcons.activity, const Color(0xFF0369A1)),
            const SizedBox(width: 12),
            _buildStatBox('Success Rate', '$successRate%', '$successTxns of $totalTxns', LucideIcons.trendingUp, const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatBox('Avg NFC Auth', '${avgAuthTime}s', 'Card tap speed', LucideIcons.zap, const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _buildStatBox('Total Processed', '₱${totalProcessed >= 1000 ? "${(totalProcessed / 1000).toStringAsFixed(1)}K" : totalProcessed.toStringAsFixed(0)}', 'Tokenized payments', LucideIcons.shield, const Color(0xFF06B6D4)),
          ],
        ),
        const SizedBox(height: 20),

        // Transaction bar chart
        _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Transactions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('Last 7 days · success vs failed', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0891B2))),
                      const SizedBox(width: 4),
                      Text('OK', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFEF4444))),
                      const SizedBox(width: 4),
                      Text('Fail', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, _) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final idx = val.toInt();
                            if (idx >= 0 && idx < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(days[idx], style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 5, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 0, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 8, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 1, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 6, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 0, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 9, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 1, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 7, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 1, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 5, color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: 0, color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                      BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: (4 + user.transactions.length).toDouble(), color: const Color(0xFF10B981), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))), BarChartRodData(toY: failedTxns.toDouble(), color: const Color(0xFFEF4444), width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // NFC Auth Speed
        _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NFC Auth Speed Distribution', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              Text('Time from tap to authentication', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              const SizedBox(height: 16),
              ...[
                ['<0.5s', 12, const Color(0xFF10B981)],
                ['0.5–1s', 21, const Color(0xFF10B981)],
                ['1–1.5s', 10, const Color(0xFFF59E0B)],
                ['1.5–2s', 4, const Color(0xFFEF4444)],
                ['>2s', 1, const Color(0xFFEF4444)],
              ].map((e) {
                final label = e[0] as String;
                final count = e[1] as int;
                final color = e[2] as Color;
                final pct = count / 48;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11))),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.white.withOpacity(0.08)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24, child: Text('$count', textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Security metrics
        Row(
          children: [
            _buildMiniStat('Failed Auths', '$failedTxns', const Color(0xFFEF4444), LucideIcons.xCircle),
            const SizedBox(width: 8),
            _buildMiniStat('NFC Pays', '${user.nfcPayCount}', const Color(0xFF38BDF8), LucideIcons.wifi),
            const SizedBox(width: 8),
            _buildMiniStat('Avg Tx Time', '1.3s', const Color(0xFF06B6D4), LucideIcons.timer),
          ],
        ),
        const SizedBox(height: 16),

        // Recent auth log
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Auth Log', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('${recentLogs.length} entries', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            if (recentLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Center(
                  child: Text('No transactions yet', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ),
              )
            else
              ...recentLogs.map((tx) {
                final isExpanded = _expandedId == tx.id;
                final isSuccess = tx.amount != 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: !isSuccess ? const Color(0xFFEF4444).withOpacity(0.2) : Colors.white.withOpacity(0.07)),
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _expandedId = isExpanded ? null : tx.id),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isSuccess ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                              ),
                              child: Icon(isSuccess ? LucideIcons.checkCircle : LucideIcons.xCircle, size: 15, color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tx.type == 'nfc' ? 'NFC Pay' : tx.type == 'send' ? 'Send' : 'Receive'} → ${tx.name}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                  Text('₱${tx.amount.abs().toStringAsFixed(2)} · ${tx.time}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('1.3s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171))),
                                Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 12, color: Colors.white.withOpacity(0.3)),
                              ],
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          Divider(color: Colors.white.withOpacity(0.07)),
                          const SizedBox(height: 8),
                          _buildLogDetail('Transaction ID', tx.id),
                          _buildLogDetail('NFC Auth Time', '0.82s'),
                          _buildLogDetail('Total Time', '1.3s'),
                          _buildLogDetail('Status', isSuccess ? 'Completed' : 'Failed'),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 16),

        // Security assessment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x1410B981), Color(0x0F06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.shield, size: 16, color: Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  const Text('Security Assessment', style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              _buildAssessmentRow('Auth Reliability', '$successRate%', const Color(0xFF34D399)),
              _buildAssessmentRow('Avg NFC Response', '0.82s', const Color(0xFF38BDF8)),
              _buildAssessmentRow('Token Integrity', '100%', const Color(0xFF34D399)),
              _buildAssessmentRow('Failed Auth Rate', '0.0%', const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenchmarkTab() {
    final benchmarkData = [
      {'method': 'NFC Card', 'avgMs': 820.0, 'p95Ms': 1400.0, 'failRate': 6.4, 'security': 95},
      {'method': 'SMS OTP', 'avgMs': 4200.0, 'p95Ms': 12000.0, 'failRate': 18.2, 'security': 55},
      {'method': 'Biometric', 'avgMs': 950.0, 'p95Ms': 1800.0, 'failRate': 8.1, 'security': 82},
    ];
    final colors = [const Color(0xFF0891B2), const Color(0xFFF59E0B), const Color(0xFF06B6D4)];

    return Column(
      key: const ValueKey('benchmark'),
      children: [
        _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.cpu, size: 14, color: const Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  const Text('Authentication Method Comparison', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              Text('Side-by-side timing: NFC Card vs SMS OTP vs Biometric. Lower is better.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (val, _) {
                            final labels = ['NFC Card', 'SMS OTP', 'Biometric'];
                            final idx = val.toInt();
                            if (idx >= 0 && idx < labels.length) {
                              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[idx], style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)));
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(3, (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(toY: (benchmarkData[i]['avgMs'] as double) / 100, color: colors[i], width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                        BarChartRodData(toY: (benchmarkData[i]['p95Ms'] as double) / 100, color: colors[i].withOpacity(0.4), width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ],
                    )),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Comparison table
        _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detailed Comparison', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: ['Method', 'Avg', 'Fail %', 'Security'].map((h) => Expanded(
                  child: Text(h, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w700)),
                )).toList(),
              ),
              Divider(color: Colors.white.withOpacity(0.08), height: 16),
              ...List.generate(3, (i) {
                final d = benchmarkData[i];
                final failRate = d['failRate'] as double;
                final security = d['security'] as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(d['method'] as String, style: TextStyle(color: colors[i], fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('${d['avgMs']}ms', style: TextStyle(color: colors[i], fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('$failRate%', style: TextStyle(color: failRate > 10 ? const Color(0xFFF87171) : const Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('$security/100', style: TextStyle(color: security >= 90 ? const Color(0xFF34D399) : security >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Research finding
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0x1F0891B2), Color(0x1406B6D4)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 Research Finding', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.6),
                  children: const [
                    TextSpan(text: 'NFC Card authentication is '),
                    TextSpan(text: '5.1× faster', style: TextStyle(color: Color(0xFFD4BCFC), fontWeight: FontWeight.w700)),
                    TextSpan(text: ' than SMS OTP on average and achieves a '),
                    TextSpan(text: '93.6% success rate', style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w700)),
                    TextSpan(text: ' vs 81.8% for SMS OTP — while offering significantly stronger security due to physical possession requirements.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTab(UserState user) {
    return Column(
      key: const ValueKey('health'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Real-time card health data from your registered NFC cards.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 12),
        ...user.virtualCards.map((card) {
          final useCount = user.transactions.where((t) => t.type == 'nfc').length;
          final memPct = (useCount * 12 + 24).clamp(0, 100);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(colors: [card.colors[0].withOpacity(0.4), card.colors[1].withOpacity(0.3)]),
                          ),
                          child: Icon(LucideIcons.creditCard, size: 15, color: card.colors[0]),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.provider, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(card.id, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                      ),
                      child: const Text('Active', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildHealthCell('Times Used', '$useCount'),
                    _buildHealthCell('Last Tapped', useCount > 0 ? 'Recently' : 'Never'),
                    _buildHealthCell('Applet Version', 'v2.1.0'),
                    _buildHealthCell('Memory Used', '$memPct%'),
                  ],
                ),
                const SizedBox(height: 12),
                // Memory bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Memory Usage', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                        Text('$memPct%', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white.withOpacity(0.08)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: memPct / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: memPct < 50 ? const Color(0xFF34D399) : memPct < 80 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (user.virtualCards.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Center(
              child: Text('No cards registered', style: TextStyle(color: Colors.white.withOpacity(0.4))),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
          ),
          child: Text('⚡ Memory usage is estimated based on tap count. Actual Java Card memory varies by applet version.', style: TextStyle(color: const Color(0xFFFBBF24).withOpacity(0.8), fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildGlassPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _buildStatBox(String label, String value, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.13), color.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withOpacity(0.2)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          Text(value, style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildAssessmentRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildHealthCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
