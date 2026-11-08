import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

// ── Models & Paper Data (manuscript__2_.pdf) ────────────────────────────────

enum SecuritySubTab { overview, nfc, ml }

class StrideItem {
  final String threat;
  final String vector;
  final String layer;
  final String status;
  final String note;

  const StrideItem({
    required this.threat,
    required this.vector,
    required this.layer,
    required this.status,
    required this.note,
  });
}

const kStrideMatrix = [
  StrideItem(
    threat: 'Spoofing',
    vector: 'Forged card via APDU replay',
    layer: 'Hardware',
    status: 'Mitigated',
    note: 'Challenge nonce unique per session; card increments monotonic signature counter.',
  ),
  StrideItem(
    threat: 'Spoofing',
    vector: 'Server impersonation via fraudulent SSL',
    layer: 'Application',
    status: 'Mitigated',
    note: 'Certificate pinning enforced; MITM proxies rejected immediately.',
  ),
  StrideItem(
    threat: 'Tampering',
    vector: 'NFC data modification in transit',
    layer: 'Hardware',
    status: 'Mitigated',
    note: 'ECDSA P-256 signature invalidated if any byte in transit is altered.',
  ),
  StrideItem(
    threat: 'Tampering',
    vector: 'Firestore public key substitution',
    layer: 'Backend',
    status: 'Partial',
    note: 'Firebase rules restrict writes to card owner; hardware-enforced key rotation in progress.',
  ),
  StrideItem(
    threat: 'Repudiation',
    vector: 'User denies auth event',
    layer: 'Backend',
    status: 'Mitigated',
    note: 'Signed assertion stored with cryptographic session timestamp and sequence number.',
  ),
  StrideItem(
    threat: 'Info Disclosure',
    vector: 'NFC passive eavesdropping',
    layer: 'Hardware',
    status: 'Mitigated',
    note: 'Eavesdropped assertion cannot be reused; short ~4 cm operating range.',
  ),
  StrideItem(
    threat: 'Info Disclosure',
    vector: 'Firestore unauthorized read',
    layer: 'Backend',
    status: 'Mitigated',
    note: 'Firebase granular security rules restrict reads to authenticated token owner.',
  ),
  StrideItem(
    threat: 'DoS',
    vector: 'Sustained auth request flood',
    layer: 'Backend',
    status: 'Partial',
    note: 'Firebase token rate limiting active; hardware throttle recommended for high-volume nodes.',
  ),
  StrideItem(
    threat: 'DoS',
    vector: 'Card unresponsive after error',
    layer: 'Hardware',
    status: 'Mitigated',
    note: 'Card OS automatically resets APDU session state on next AID SELECT.',
  ),
  StrideItem(
    threat: 'EoP',
    vector: 'Unauthorized admin Firebase access',
    layer: 'Backend',
    status: 'Mitigated',
    note: 'Admin functions gated by multi-party RBAC checks and service-account validation.',
  ),
  StrideItem(
    threat: 'EoP',
    vector: 'Malicious URL injection',
    layer: 'Application',
    status: 'Mitigated',
    note: 'CNN-LSTM hybrid scanner blocks navigation to flagged phishing URLs before execution.',
  ),
];

class RegisteredKey {
  final String id;
  final String name;
  final String uid;
  final String status;
  final int signal;
  final String lastUsed;
  final String device;

  const RegisteredKey({
    required this.id,
    required this.name,
    required this.uid,
    required this.status,
    required this.signal,
    required this.lastUsed,
    required this.device,
  });
}

const kRegisteredKeys = [
  RegisteredKey(
    id: 'k1',
    name: 'Primary Key Card',
    uid: '7F:3A:BC:D1',
    status: 'active',
    signal: 88,
    lastUsed: '2 min ago',
    device: 'JCOP4 J3R150 · Secure Element',
  ),
  RegisteredKey(
    id: 'k2',
    name: 'Backup Key Card',
    uid: 'A2:51:FF:C3',
    status: 'active',
    signal: 73,
    lastUsed: '3 days ago',
    device: 'Feitian A40CR · JavaCard',
  ),
  RegisteredKey(
    id: 'k3',
    name: 'Test Key',
    uid: 'D1:F0:38:55',
    status: 'inactive',
    signal: 0,
    lastUsed: '2 weeks ago',
    device: 'N/A · Unlinked',
  ),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class SecurityInfoScreen extends StatefulWidget {
  const SecurityInfoScreen({super.key});

  @override
  State<SecurityInfoScreen> createState() => _SecurityInfoScreenState();
}

class _SecurityInfoScreenState extends State<SecurityInfoScreen> {
  SecuritySubTab _subTab = SecuritySubTab.overview;
  String? _expandedKeyId;
  int? _expandedStrideIndex;
  late final List<RegisteredKey> _keys = List.of(kRegisteredKeys);

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top Bar ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(T.screenPad, 12, T.screenPad, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GlassIconBtn(
                                icon: LucideIcons.arrowLeft,
                                onTap: () => Navigator.pop(context),
                                size: 36,
                                iconSize: 18,
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  const Icon(LucideIcons.shieldCheck, size: 20, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('Security Center', style: T.h3.copyWith(fontSize: 18)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: T.op(T.emerald, 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: T.op(T.emerald, 0.40)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: T.emerald300,
                                    shape: BoxShape.circle,
                                    boxShadow: T.glow(T.emerald, 6),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Protected',
                                  style: T.text(11, w: T.w700, color: T.emerald300),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Circular Accuracy Score Card ───────────────────
                      Glass(
                        kind: GlassKind.glass,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 94.7% Ring
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(72, 72),
                                    painter: _AccuracyRingPainter(
                                      progress: 0.947,
                                      trackColor: T.white(0.10),
                                      fillColor: T.cyan300,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '94.7',
                                        style: T.mono(16, w: T.w800, color: Colors.white),
                                      ),
                                      Text(
                                        '% acc.',
                                        style: T.caption.copyWith(fontSize: 8, color: T.white(0.55)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CNN-LSTM Accuracy', style: T.text(14, w: T.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'PhishTank + UCI datasets · 80/20 split',
                                    style: T.caption.copyWith(color: T.white(0.55), fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _badgePill('2.4M samples'),
                                      _badgePill('< 500ms latency'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Sub-tabs Pill Selector ─────────────────────────
                      Glass(
                        kind: GlassKind.pill,
                        radius: 16,
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _subTabBtn(SecuritySubTab.overview, 'Overview', LucideIcons.shieldCheck),
                            _subTabBtn(SecuritySubTab.nfc, 'NFC Key', LucideIcons.wifi),
                            _subTabBtn(SecuritySubTab.ml, 'ML Model', LucideIcons.brain),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tab Content ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  T.screenPad,
                  4,
                  T.screenPad,
                  T.navBottomPad + 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_subTab == SecuritySubTab.overview) ..._buildOverviewTab(),
                    if (_subTab == SecuritySubTab.nfc) ..._buildNfcTab(),
                    if (_subTab == SecuritySubTab.ml) ..._buildMlTab(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-tab button ────────────────────────────────────────────────────────

  Widget _subTabBtn(SecuritySubTab tab, String label, IconData icon) {
    final active = _subTab == tab;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _subTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? T.glow(T.white(0.3), 8) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? const Color(0xFF0F172A) : T.white(0.60),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: T.text(
                  12,
                  w: active ? T.w700 : T.w500,
                  color: active ? const Color(0xFF0F172A) : T.white(0.60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badgePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: T.white(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: T.white(0.12)),
      ),
      child: Text(label, style: T.caption.copyWith(color: T.white(0.80), fontSize: 10)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildOverviewTab() {
    return [
      // 3-Col Dual Layer Summary Cards
      Row(
        children: [
          Expanded(
            child: _metricMiniCard(
              '94.1%',
              'NFC Layer',
              'ECDSA P-256',
              LucideIcons.wifi,
              const Color(0xFF60A5FA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricMiniCard(
              '94.7%',
              'ML Layer',
              'CNN-LSTM',
              LucideIcons.brain,
              const Color(0xFF34D399),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricMiniCard(
              '99.1%',
              'Combined',
              'Dual-Layer',
              LucideIcons.shieldCheck,
              const Color(0xFFA78BFA),
            ),
          ),
        ],
      ),

      const SizedBox(height: 14),

      // Weekly Threat Activity Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Threat Activity', style: T.text(14, w: T.w700)),
            const SizedBox(height: 2),
            Text(
              'Phishing · Replay · Anomaly (all blocked)',
              style: T.caption.copyWith(color: T.white(0.45)),
            ),
            const SizedBox(height: 16),
            _buildWeeklyThreatChart(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _threatLegend(const Color(0xFF2563EB), 'Phishing'),
                const SizedBox(width: 14),
                _threatLegend(const Color(0xFF059669), 'Replay'),
                const SizedBox(width: 14),
                _threatLegend(const Color(0xFF7C3AED), 'Anomaly'),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Defense Layer Effectiveness
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Defense Layer Effectiveness', style: T.text(14, w: T.w700)),
            const SizedBox(height: 2),
            Text(
              'Per-layer threat mitigation rate',
              style: T.caption.copyWith(color: T.white(0.45)),
            ),
            const SizedBox(height: 14),
            _layerProgressBar('NFC Hardware Layer (ECDSA)', 0.94, const Color(0xFF2563EB)),
            const SizedBox(height: 10),
            _layerProgressBar('CNN-LSTM Phishing Detection', 0.947, const Color(0xFF059669)),
            const SizedBox(height: 10),
            _layerProgressBar('Combined Dual-Layer System', 0.991, const Color(0xFF7C3AED)),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // STRIDE Threat Matrix Summary
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('STRIDE Threat Matrix', style: T.text(14, w: T.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: T.white(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: T.white(0.12)),
                  ),
                  child: Text(
                    '${kStrideMatrix.where((s) => s.status == "Mitigated").length}/${kStrideMatrix.length} mitigated',
                    style: T.mono(10, color: T.white(0.70)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _strideCountBox(
                    '${kStrideMatrix.where((s) => s.status == "Mitigated").length}',
                    'Mitigated',
                    T.emerald,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _strideCountBox(
                    '${kStrideMatrix.where((s) => s.status == "Partial").length}',
                    'Partial',
                    T.amber500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _strideCountBox('0', 'Unmitigated', T.red400),
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Progressive Auth Tiers Table (from existing Flutter screen)
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.shieldCheck, size: 18, color: T.cyan300),
                const SizedBox(width: 8),
                Text('Progressive Auth Tiers', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 14),
            _buildAuthTiersTable(),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Card Lifecycle States (from existing Flutter screen)
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.creditCard, size: 18, color: T.emerald300),
                const SizedBox(width: 8),
                Text('Card Lifecycle States', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow('PERSONALIZED', 'Keys generated, app installed'),
            _infoRow('PIN_SET', 'User has set their 6-digit PIN'),
            _infoRow('ENROLLED', 'Card linked to Tapat account'),
            _infoRow('PIN_BLOCKED', 'Too many wrong PIN attempts (5 max)'),
            _infoRow('TERMINATED', 'Card revoked; no further use'),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Thesis Research Context Glass-Tint Card
      Glass(
        kind: GlassKind.tint,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.info, size: 16, color: Color(0xFF60A5FA)),
                const SizedBox(width: 8),
                Text('Thesis Context', style: T.text(14, w: T.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This system implements the thesis "A Dual-Layered Security Defense System for NFC-Based Hardware Key Online Banking using CNN-LSTM for Phishing Detection." It pairs physical NFC smart card credentials (Layer 1) with CNN-LSTM machine-learning heuristic validation (Layer 2) to eliminate single points of compromise.',
              style: T.caption.copyWith(color: T.white(0.70), height: 1.45),
            ),
          ],
        ),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: NFC KEY
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildNfcTab() {
    return [
      // Hardware Spec Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.50)),
                  ),
                  child: const Icon(LucideIcons.creditCard, color: Color(0xFF60A5FA), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JCOP4 J3R150 / Feitian A40CR', style: T.text(14, w: T.w700)),
                    Text(
                      'Java Card Hardware Secure Element',
                      style: T.caption.copyWith(color: T.white(0.45)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _specBox('Protocol', 'FIDO2 / CTAP2'),
                _specBox('Crypto', 'ECDSA P-256'),
                _specBox('NFC Standard', 'ISO/IEC 14443'),
                _specBox('Frequency', '13.56 MHz'),
                _specBox('Range', '~4 cm proximity'),
                _specBox('RAM', '~4 KB volatile'),
                _specBox('EEPROM', '64 KB secure'),
                _specBox('Certification', 'CC EAL4+ / EAL6+'),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Security Guarantee Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.lock, size: 16, color: Color(0xFF60A5FA)),
                const SizedBox(width: 8),
                Text('Security Guarantee', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 12),
            _guaranteeItem('🔐', 'Private key is non-exportable and stays inside the Secure Element — forever.'),
            _guaranteeItem('🔄', 'ECDSA P-256 provides 128-bit symmetric security level (equivalent to 3072-bit RSA).'),
            _guaranteeItem('✅', 'Each authentication challenge is unique per session — replay attacks are strictly impossible.'),
            _guaranteeItem('📡', '~4 cm NFC range prevents remote eavesdropping (ISO/IEC 14443 Type A layer).'),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Authentication Flow (5-Step Stepper)
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Authentication Flow', style: T.text(14, w: T.w700)),
            const SizedBox(height: 14),
            _stepRow('1', 'App generates challenge', 'Server issues cryptographic nonce (unique per session)', const Color(0xFF2563EB)),
            _stepRow('2', 'NFC Tap', 'User taps smart card — ~4 cm range · ISO/IEC 14443', const Color(0xFF2563EB)),
            _stepRow('3', 'ECDSA P-256 Sign', 'Secure Element signs challenge; private key never leaves card', const Color(0xFF059669)),
            _stepRow('4', 'CNN-LSTM scan', 'ML model checks URL/behavior features in < 500 ms', const Color(0xFF059669)),
            _stepRow('5', 'Firebase verify', 'Backend verifies signature & ML result → transaction approved', const Color(0xFF7C3AED)),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Registered Keys List with interactive Expand/Collapse
      Text('REGISTERED KEYS', style: T.label.copyWith(fontSize: 10, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      for (final key in _keys) ...[
        _buildKeyCard(key),
        const SizedBox(height: 8),
      ],

      const SizedBox(height: 14),

      // Existing APDU Commands & PIN Lockout Details
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.terminal, size: 18, color: T.cyan300),
                const SizedBox(width: 8),
                Text('APDU Command Protocol', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 12),
            _apduRow('00 A4 04 00', 'SELECT APPLET (AID: F0 74 61 70 61 74 61 6E 01 01)'),
            _apduRow('00 20 00 00', 'VERIFY PIN (P2=00, Lc=PIN len)'),
            _apduRow('00 88 00 00', 'INTERNAL AUTHENTICATE (Signs challenge)'),
            _apduRow('00 CA 00 00', 'GET DATA (Reads Turing-framed identity/token)'),
            _apduRow('80 E2 00 00', 'STORE DATA (Writes Turing identity/payment token)'),
            const SizedBox(height: 10),
            const Divider(color: Color(0x1AFFFFFF), height: 1),
            const SizedBox(height: 10),
            Text('PIN Lockout Policy', style: T.text(13, w: T.w700, color: T.amber300)),
            const SizedBox(height: 6),
            _infoRow('Max retries', '5 attempts (hardware enforced)'),
            _infoRow('After 5 fails', 'Card enters PIN_BLOCKED state (SW 0x6983)'),
            _infoRow('Storage', 'OwnerPIN counter in on-card persistent EEPROM'),
          ],
        ),
      ),
    ];
  }

  Widget _buildKeyCard(RegisteredKey key) {
    final expanded = _expandedKeyId == key.id;
    final isActive = key.status == 'active';

    return Glass(
      kind: GlassKind.glass,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          PressScale(
            onTap: () {
              setState(() {
                _expandedKeyId = expanded ? null : key.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isActive ? T.btnLiquidGradient : null,
                      color: isActive ? null : T.white(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(LucideIcons.creditCard, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(key.name, style: T.text(13, w: T.w600)),
                            const SizedBox(width: 6),
                            Badge2(
                              key.status,
                              color: isActive ? T.emerald : T.white(0.2),
                              textColor: isActive ? T.emerald300 : T.white(0.5),
                              fontSize: 9,
                            ),
                          ],
                        ),
                        Text(key.uid, style: T.mono(11, color: T.white(0.40))),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: T.white(0.50),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Container(height: 1, color: T.white(0.08)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _infoRow('Last Used', key.lastUsed),
                  _infoRow('Linked Device', key.device),
                  _infoRow('Crypto', 'ECDSA P-256 (128-bit)'),
                  _infoRow('Signal', isActive ? '${key.signal}%' : 'Offline'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isActive) ...[
                        Expanded(
                          child: Btn(
                            variant: BtnVariant.danger,
                            onTap: () {
                              setState(() {
                                final i = _keys.indexWhere((k) => k.id == key.id);
                                if (i >= 0) {
                                  _keys[i] = RegisteredKey(
                                    id: key.id,
                                    name: key.name,
                                    uid: key.uid,
                                    status: 'inactive',
                                    signal: 0,
                                    lastUsed: 'Revoked just now',
                                    device: key.device,
                                  );
                                }
                              });
                              showToast(context, '${key.name} (${key.uid}) revoked');
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('Revoke', style: T.text(12, w: T.w600, color: T.red300)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Btn(
                            variant: BtnVariant.glass,
                            onTap: () {
                              setState(() {
                                final i = _keys.indexWhere((k) => k.id == key.id);
                                if (i >= 0) {
                                  _keys[i] = RegisteredKey(
                                    id: key.id,
                                    name: key.name,
                                    uid: key.uid,
                                    status: 'active',
                                    signal: key.signal,
                                    lastUsed: 'Rotated just now',
                                    device: key.device,
                                  );
                                }
                              });
                              showToast(context, 'Session key rotated for ${key.name}');
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.rotateCcw, size: 14),
                                const SizedBox(width: 4),
                                Text('Rotate Key', style: T.text(12, w: T.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Btn(
                            variant: BtnVariant.primary,
                            onTap: () {
                              setState(() {
                                final i = _keys.indexWhere((k) => k.id == key.id);
                                if (i >= 0) {
                                  _keys[i] = RegisteredKey(
                                    id: key.id,
                                    name: key.name,
                                    uid: key.uid,
                                    status: 'active',
                                    signal: 92,
                                    lastUsed: 'Activated just now',
                                    device: 'JCOP4 J3R150 · Secure Element',
                                  );
                                }
                              });
                              showToast(context, '${key.name} activated');
                            },
                            child: Text('Activate', style: T.text(12, w: T.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: ML MODEL
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildMlTab() {
    return [
      // Model Identity Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.50)),
                  ),
                  child: const Icon(LucideIcons.brain, color: Color(0xFF34D399), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CNN-LSTM Hybrid Model', style: T.text(14, w: T.w700)),
                      Text(
                        'Phishing URL & behavioral anomaly detection',
                        style: T.caption.copyWith(color: T.white(0.45)),
                      ),
                    ],
                  ),
                ),
                const Badge2('Live', color: T.emerald),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'A CNN-LSTM hybrid: CNN extracts local lexical URL features; LSTM models sequential transaction dependencies. Trained on PhishTank + UCI phishing datasets (80/20 stratified split). Targets >90% accuracy with FPR <5% and latency <500 ms.',
              style: T.caption.copyWith(color: T.white(0.70), height: 1.45),
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Model Architecture Flow Pipeline
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model Architecture', style: T.text(14, w: T.w700)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _archNode('Input', 'URL / Feat', LucideIcons.database, const Color(0xFF94A3B8)),
                  _archArrow(),
                  _archNode('Conv1D', 'Local feat', LucideIcons.layers, const Color(0xFF60A5FA)),
                  _archArrow(),
                  _archNode('MaxPool', 'Downsample', LucideIcons.layers, const Color(0xFF60A5FA)),
                  _archArrow(),
                  _archNode('LSTM', 'Sequences', LucideIcons.gitBranch, const Color(0xFF34D399)),
                  _archArrow(),
                  _archNode('Dense', 'Classify', LucideIcons.cpu, const Color(0xFFA78BFA)),
                  _archArrow(),
                  _archNode('Output', 'Safe/Phish', LucideIcons.target, const Color(0xFFFBBF24)),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Core Metrics 2x2 Grid
      Row(
        children: [
          Expanded(
            child: _metricSquareCard('Accuracy', '94.7%', 'Target: >90%', LucideIcons.target, const Color(0xFF60A5FA)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricSquareCard('Precision', '93.2%', 'PhishTank + UCI', LucideIcons.award, const Color(0xFF34D399)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _metricSquareCard('Recall', '95.1%', 'FPR < 5% target', LucideIcons.activity, const Color(0xFFA78BFA)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricSquareCard('F1 Score', '94.1%', 'Harmonic mean', LucideIcons.barChart2, const Color(0xFFFB923C)),
          ),
        ],
      ),

      const SizedBox(height: 14),

      // AUC-ROC, Latency, Features Row
      Row(
        children: [
          Expanded(child: _metricMiniCard('96.3%', 'AUC-ROC', 'Metric', LucideIcons.trendingUp, const Color(0xFF22D3EE))),
          const SizedBox(width: 8),
          Expanded(child: _metricMiniCard('<500ms', 'Latency', 'Target met', LucideIcons.zap, const Color(0xFFFCD34D))),
          const SizedBox(width: 8),
          Expanded(child: _metricMiniCard('42+', 'Features', 'Engineered', LucideIcons.eye, const Color(0xFFF472B6))),
        ],
      ),

      const SizedBox(height: 14),

      // CNN-LSTM vs Baselines
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CNN-LSTM vs. Baselines', style: T.text(14, w: T.w700)),
            const SizedBox(height: 2),
            Text('Based on Gurung et al. (2023) comparison', style: T.caption.copyWith(color: T.white(0.45))),
            const SizedBox(height: 14),
            _baselineBar('CNN-LSTM', 94.7, const Color(0xFF2563EB)),
            const SizedBox(height: 10),
            _baselineBar('Random Forest', 70.0, const Color(0xFF059669)),
            const SizedBox(height: 10),
            _baselineBar('Logistic Reg.', 62.3, const Color(0xFF7C3AED)),
            const SizedBox(height: 10),
            _baselineBar('Naive Bayes', 58.4, const Color(0xFFD97706)),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Top Detection Features
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Detection Features', style: T.text(14, w: T.w700)),
            const SizedBox(height: 2),
            Text('What the model weights most heavily', style: T.caption.copyWith(color: T.white(0.45))),
            const SizedBox(height: 14),
            _featureBar('URL lexical features', 89, const Color(0xFF38BDF8)),
            const SizedBox(height: 8),
            _featureBar('NFC tap pattern', 83, const Color(0xFF60A5FA)),
            const SizedBox(height: 8),
            _featureBar('Session time delta', 77, const Color(0xFF818CF8)),
            const SizedBox(height: 8),
            _featureBar('Geographic anomaly', 72, const Color(0xFFA78BFA)),
            const SizedBox(height: 8),
            _featureBar('Device fingerprint', 68, const Color(0xFFC084FC)),
            const SizedBox(height: 8),
            _featureBar('Transaction velocity', 65, const Color(0xFFE879F9)),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Training Datasets Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.database, size: 16, color: Color(0xFF60A5FA)),
                const SizedBox(width: 8),
                Text('Training Datasets', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 12),
            _datasetItem('PhishTank', 'Community-verified phishing URLs', 'Primary'),
            const SizedBox(height: 8),
            _datasetItem('UCI Phishing Dataset', 'Machine learning benchmark (phishing URLs)', 'Primary'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _datasetStat('Split', '80 / 20')),
                const SizedBox(width: 8),
                Expanded(child: _datasetStat('Strategy', 'Stratified')),
                const SizedBox(width: 8),
                Expanded(child: _datasetStat('Test runs', '30+')),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Interactive STRIDE Threat Resistance Full Table (All 11 items)
      Glass(
        kind: GlassKind.glass,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('STRIDE Threat Resistance', style: T.text(14, w: T.w700)),
                  Text('Table 3.1', style: T.mono(10, color: T.white(0.40))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap any row to view mitigation detail',
                style: T.caption.copyWith(color: T.white(0.45)),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < kStrideMatrix.length; i++) ...[
              _buildStrideRow(kStrideMatrix[i], i),
            ],
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Thesis Research Targets
      Glass(
        kind: GlassKind.tint,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.award, size: 18, color: T.amber300),
                const SizedBox(width: 8),
                Text('Thesis Research Targets', style: T.text(14, w: T.w700)),
              ],
            ),
            const SizedBox(height: 12),
            _targetRow('ML Accuracy', '> 90%', '94.7%', true),
            _targetRow('False Positive Rate', '< 5%', '~4.9%', true),
            _targetRow('End-to-end Latency', '< 500 ms', '< 500 ms', true),
            _targetRow('SUS Usability Score', '≥ 68', 'Pending (10–15 cohort)', null),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // Model Last Retrained Card
      Glass(
        kind: GlassKind.glass,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.rotateCcw, size: 18, color: T.emerald300),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model Retrained & Validated', style: T.text(13, w: T.w600)),
                  Text(
                    'PhishTank + UCI datasets · Stratified k-fold',
                    style: T.caption.copyWith(color: T.white(0.45)),
                  ),
                ],
              ),
            ),
            const Badge2('Current', color: T.emerald),
          ],
        ),
      ),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildStrideRow(StrideItem s, int index) {
    final expanded = _expandedStrideIndex == index;
    final isMitigated = s.status == 'Mitigated';

    return Column(
      children: [
        Container(height: 1, color: T.white(0.06)),
        PressScale(
          onTap: () {
            setState(() {
              _expandedStrideIndex = expanded ? null : index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isMitigated ? T.emerald300 : T.amber300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: T.white(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(s.threat, style: T.mono(9, color: T.white(0.60))),
                          ),
                          const SizedBox(width: 6),
                          Text(s.layer, style: T.caption.copyWith(color: T.white(0.40), fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.vector,
                        style: T.text(12, w: T.w500, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Badge2(
                  s.status,
                  color: isMitigated ? T.emerald : T.amber500,
                  textColor: isMitigated ? T.emerald300 : T.amber300,
                  fontSize: 9,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(26, 6, 16, 12),
            color: T.white(0.04),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 14, color: T.cyan300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.note,
                    style: T.caption.copyWith(color: T.white(0.70), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _metricMiniCard(String val, String label, String sub, IconData icon, Color color) {
    return Glass(
      kind: GlassKind.glass,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(val, style: T.mono(14, w: T.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: T.caption.copyWith(fontSize: 10, color: T.white(0.60))),
          Text(sub, style: T.caption.copyWith(fontSize: 8.5, color: T.white(0.40))),
        ],
      ),
    );
  }

  static Widget _metricSquareCard(String label, String val, String sub, IconData icon, Color color) {
    return Glass(
      kind: GlassKind.glass,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(val, style: T.mono(20, w: T.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: T.text(12, w: T.w600, color: Colors.white)),
          Text(sub, style: T.caption.copyWith(fontSize: 9, color: T.white(0.40))),
        ],
      ),
    );
  }

  static Widget _strideCountBox(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: T.op(color, 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.op(color, 0.30)),
      ),
      child: Column(
        children: [
          Text(count, style: T.mono(18, w: T.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: T.caption.copyWith(fontSize: 10, color: T.white(0.60))),
        ],
      ),
    );
  }

  static Widget _specBox(String label, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: T.white(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.white(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(fontSize: 9, color: T.white(0.45))),
          const SizedBox(height: 2),
          Text(value, style: T.text(11, w: T.w600, color: Colors.white)),
        ],
      ),
    );
  }

  static Widget _guaranteeItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: T.white(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.white(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: T.caption.copyWith(color: T.white(0.75), height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _stepRow(String num, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: T.op(color, 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: T.op(color, 0.60)),
            ),
            child: Center(
              child: Text(num, style: T.mono(11, w: T.w700, color: color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.text(12, w: T.w600, color: Colors.white)),
                Text(desc, style: T.caption.copyWith(color: T.white(0.50), fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _archNode(String label, String sub, IconData icon, Color color) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: T.op(color, 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.op(color, 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(label, style: T.text(10, w: T.w700, color: color)),
          Text(sub, style: T.caption.copyWith(fontSize: 8, color: T.white(0.45)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static Widget _archArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(LucideIcons.arrowRight, size: 12, color: T.white(0.30)),
    );
  }

  static Widget _layerProgressBar(String title, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: T.caption.copyWith(color: T.white(0.70))),
            Text('${(val * 100).toStringAsFixed(1)}%', style: T.mono(11, w: T.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 5,
            backgroundColor: T.white(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  static Widget _baselineBar(String model, double acc, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(model, style: T.caption.copyWith(color: T.white(0.75))),
            Text('$acc%', style: T.mono(11, w: T.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: acc / 100,
            minHeight: 6,
            backgroundColor: T.white(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  static Widget _featureBar(String name, int pct, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: T.caption.copyWith(color: T.white(0.70))),
            Text('$pct%', style: T.mono(11, w: T.w700, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 4,
            backgroundColor: T.white(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  static Widget _datasetItem(String name, String desc, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: T.white(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.white(0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: T.text(12, w: T.w600, color: Colors.white)),
                Text(desc, style: T.caption.copyWith(color: T.white(0.45), fontSize: 10)),
              ],
            ),
          ),
          Badge2(tag, color: T.cyan400, textColor: T.cyan300, fontSize: 9),
        ],
      ),
    );
  }

  static Widget _datasetStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: T.white(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.white(0.08)),
      ),
      child: Column(
        children: [
          Text(value, style: T.mono(12, w: T.w700, color: Colors.white)),
          Text(label, style: T.caption.copyWith(fontSize: 9, color: T.white(0.45))),
        ],
      ),
    );
  }

  static Widget _targetRow(String label, String target, String achieved, bool? met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: T.white(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.text(12, w: T.w600, color: Colors.white)),
                Text('Target: $target', style: T.caption.copyWith(color: T.white(0.45), fontSize: 9.5)),
              ],
            ),
            Row(
              children: [
                Text(achieved, style: T.mono(11, w: T.w600, color: T.white(0.85))),
                const SizedBox(width: 6),
                if (met == true)
                  const Icon(LucideIcons.checkCircle, size: 14, color: T.emerald300)
                else
                  const Icon(LucideIcons.clock, size: 14, color: T.amber300),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: T.caption.copyWith(color: T.white(0.50), fontSize: 11)),
          ),
          Expanded(
            child: Text(value, style: T.text(12, w: T.w500, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Widget _apduRow(String code, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: T.white(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(code, style: T.mono(10, w: T.w700, color: T.cyan300)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(desc, style: T.caption.copyWith(color: T.white(0.70), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static Widget _threatLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: T.caption.copyWith(color: T.white(0.50), fontSize: 10)),
      ],
    );
  }

  Widget _buildWeeklyThreatChart() {
    const days = [
      {'d': 'Mon', 'p': 8, 'r': 3, 'a': 2},
      {'d': 'Tue', 'p': 12, 'r': 5, 'a': 4},
      {'d': 'Wed', 'p': 6, 'r': 2, 'a': 1},
      {'d': 'Thu', 'p': 19, 'r': 7, 'a': 6},
      {'d': 'Fri', 'p': 14, 'r': 4, 'a': 3},
      {'d': 'Sat', 'p': 7, 'r': 2, 'a': 1},
      {'d': 'Sun', 'p': 4, 'r': 1, 'a': 0},
    ];

    const maxVal = 20.0;

    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final p = (day['p'] as int).toDouble();
          final r = (day['r'] as int).toDouble();
          final a = (day['a'] as int).toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chartBar(p / maxVal, const Color(0xFF2563EB)),
                  const SizedBox(width: 2),
                  _chartBar(r / maxVal, const Color(0xFF059669)),
                  const SizedBox(width: 2),
                  _chartBar(a / maxVal, const Color(0xFF7C3AED)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                day['d'] as String,
                style: T.caption.copyWith(fontSize: 10, color: T.white(0.40)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _chartBar(double factor, Color color) {
    const maxBarH = 65.0;
    final h = (factor * maxBarH).clamp(4.0, maxBarH);
    return Container(
      width: 5,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
    );
  }

  Widget _buildAuthTiersTable() {
    const tiers = [
      {'tier': 'Micro', 'amt': '< ₱100', 'auth': 'Tap-and-go (zero-PIN)', 'c': T.emerald},
      {'tier': 'Low', 'amt': '₱100–₱500', 'auth': 'Card tap (counter check)', 'c': T.cyan400},
      {'tier': 'Medium', 'amt': '₱500–₱5000', 'auth': 'Card + on-card PIN verify', 'c': T.amber500},
      {'tier': 'High', 'amt': '> ₱5000', 'auth': 'Card + PIN + OTP auth', 'c': T.red400},
    ];

    return Column(
      children: tiers.map((t) {
        final c = t['c'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: T.op(c, 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: T.op(c, 0.35)),
                ),
                child: Text(
                  t['tier'] as String,
                  style: T.text(11, w: T.w700, color: c),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(t['amt'] as String, style: T.mono(10.5, color: Colors.white)),
              ),
              Expanded(
                child: Text(
                  t['auth'] as String,
                  style: T.caption.copyWith(color: T.white(0.70), fontSize: 10.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Custom Ring Painter ─────────────────────────────────────────────────────

class _AccuracyRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _AccuracyRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_AccuracyRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.trackColor != trackColor;
}
