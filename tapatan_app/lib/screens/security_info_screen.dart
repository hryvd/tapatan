import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';

// ── Security Info Screen ─────────────────────────────────────────────────
// Information screen about the Tapat Card security system.

class SecurityInfoScreen extends StatelessWidget {
  const SecurityInfoScreen({super.key});

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF34D399);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(LucideIcons.arrowLeft, color: Colors.white54, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security Center', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Tapat Card · JCOP J3R150', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── ECDSA P-256 ───────────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.keyRound,
                    iconColor: _teal,
                    title: 'ECDSA P-256 Key',
                    children: const [
                      _InfoRow(label: 'Algorithm', value: 'ECDSA with SHA-256'),
                      _InfoRow(label: 'Curve', value: 'NIST P-256 (secp256r1)'),
                      _InfoRow(label: 'Key storage', value: 'On-card JavaCard secure element'),
                      _InfoRow(label: 'Key exportability', value: 'Never — private key never leaves card'),
                      _InfoRow(label: 'Signature size', value: '64 bytes (r + s, each 32 bytes)'),
                      _InfoRow(label: 'Random nonce', value: 'Per-signature nonce prevents replay'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Signature Counter ─────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.activity,
                    iconColor: _green,
                    title: 'Signature Counter',
                    children: const [
                      _InfoRow(label: 'Purpose', value: 'Prevent replay attacks'),
                      _InfoRow(label: 'Location', value: 'Stored on-card in persistent memory'),
                      _InfoRow(label: 'Behaviour', value: 'Increments with every INTERNAL AUTHENTICATE call'),
                      _InfoRow(label: 'Server check', value: 'Server rejects counter ≤ last seen value'),
                      _InfoRow(label: 'Reset', value: 'Only by card re-personalisation (destroys key)'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── PIN Lockout ───────────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.lock,
                    iconColor: _amber,
                    title: 'PIN Lockout Policy',
                    children: const [
                      _InfoRow(label: 'Max retries', value: '5 attempts'),
                      _InfoRow(label: 'Enforcement', value: 'On-card OwnerPIN (JavaCard API)'),
                      _InfoRow(label: 'After 5 failures', value: 'Card enters BLOCKED state'),
                      _InfoRow(label: 'App cannot bypass', value: 'Counter lives in card\'s EEPROM'),
                      _InfoRow(label: 'Unblock method', value: 'PUK code via card admin channel'),
                      _InfoRow(label: 'Lifecycle after block', value: 'PIN_BLOCKED → requires admin reset'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Auth Tiers ────────────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.shieldCheck,
                    iconColor: _teal,
                    title: 'Progressive Auth Tiers',
                    children: const [],
                    customChild: _AuthTiersTable(),
                  ),

                  const SizedBox(height: 16),

                  // ── STRIDE Threat Model ───────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.shield,
                    iconColor: _red,
                    title: 'STRIDE Threat Model',
                    children: const [
                      _StrideRow(
                        threat: 'S — Spoofing',
                        mitigation: 'Challenge-response ECDSA; private key never leaves card',
                      ),
                      _StrideRow(
                        threat: 'T — Tampering',
                        mitigation: 'Card memory is tamper-resistant; JCOP secure element',
                      ),
                      _StrideRow(
                        threat: 'R — Repudiation',
                        mitigation: 'Signed transactions with counter stored on server',
                      ),
                      _StrideRow(
                        threat: 'I — Info disclosure',
                        mitigation: 'Only public key and signature leave the card',
                      ),
                      _StrideRow(
                        threat: 'D — Denial of service',
                        mitigation: 'PIN block after 5 fails; revocation via server flag',
                      ),
                      _StrideRow(
                        threat: 'E — Elevation of privilege',
                        mitigation: 'App-side UI can\'t bypass on-card PIN enforcement',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Card Lifecycle ────────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.creditCard,
                    iconColor: _green,
                    title: 'Card Lifecycle States',
                    children: const [
                      _InfoRow(label: 'PERSONALIZED', value: 'Keys generated, app installed'),
                      _InfoRow(label: 'PIN_SET', value: 'User has set their 6-digit PIN'),
                      _InfoRow(label: 'ENROLLED', value: 'Card linked to Bantay account'),
                      _InfoRow(label: 'PIN_BLOCKED', value: 'Too many wrong PIN attempts'),
                      _InfoRow(label: 'TERMINATED', value: 'Card revoked; no further use'),
                    ],
                  ),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final Widget? customChild;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    this.customChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: iconColor.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (children.isNotEmpty || customChild != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0x1AFFFFFF), height: 1),
              const SizedBox(height: 16),
              if (customChild != null) customChild!,
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── STRIDE Row ────────────────────────────────────────────────────────────

class _StrideRow extends StatelessWidget {
  final String threat;
  final String mitigation;

  const _StrideRow({required this.threat, required this.mitigation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(threat, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(mitigation, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Auth Tiers Table ──────────────────────────────────────────────────────

class _AuthTiersTable extends StatelessWidget {
  const _AuthTiersTable();

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF34D399);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    final rows = [
      _TierRow('Micro', '< ₱100', 'Tap-and-go', _green),
      _TierRow('Low', '₱100–₱500', 'Card tap', _teal),
      _TierRow('Medium', '₱500–₱5000', 'Card + PIN', _amber),
      _TierRow('High', '> ₱5000', 'Card + PIN + OTP', _red),
    ];

    return Column(
      children: [
        // Header row
        Row(
          children: [
            _cell('Tier', flex: 2, isHeader: true),
            _cell('Amount', flex: 3, isHeader: true),
            _cell('Auth', flex: 4, isHeader: true),
          ],
        ),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: r.color.withOpacity(0.3)),
                  ),
                  child: Text(r.tier, style: TextStyle(color: r.color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: Text(r.amount, style: const TextStyle(color: Colors.white, fontSize: 11))),
              Expanded(flex: 4, child: Text(r.auth, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _cell(String text, {required int flex, bool isHeader = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? Colors.white38 : Colors.white,
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _TierRow {
  final String tier;
  final String amount;
  final String auth;
  final Color color;
  const _TierRow(this.tier, this.amount, this.auth, this.color);
}
