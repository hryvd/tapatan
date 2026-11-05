import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/banking_provider.dart';
import '../../../core/services/egov_api.dart';
import '../../../core/services/config_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(bankingProvider);
    final chain = EGovChainService.chain;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(bank)),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Tab bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1A30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(children: [
                    _Tab('Identity', 0, _tabIndex, (i) => setState(() => _tabIndex = i)),
                    _Tab('eGovChain Log', 1, _tabIndex, (i) => setState(() => _tabIndex = i)),
                    _Tab('Security', 2, _tabIndex, (i) => setState(() => _tabIndex = i)),
                  ]),
                ),
                const SizedBox(height: 20),

                if (_tabIndex == 0) _buildIdentityTab(bank),
                if (_tabIndex == 1) _buildChainTab(chain),
                if (_tabIndex == 2) _buildSecurityTab(bank, context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BankingState bank) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF001854), Color(0xFF080F1E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF003087).withValues(alpha: 0.5),
                        child: Text(
                          bank.name.isNotEmpty ? bank.name[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: Color(0xFF080F1E), width: 2)),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bank.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF34D399)),
                          const SizedBox(width: 4),
                          Text('PhilSys Verified', style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(children: [
                _Stat('Confidence', '${bank.confidenceScore}%', const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _Stat('Transactions', '${bank.transactions.length}', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _Stat('Chain Blocks', '${EGovChainService.chain.length}', const Color(0xFF8B5CF6)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityTab(BankingState bank) {
    return Column(
      children: [
        _InfoCard(items: [
          ('PhilSys Number', bank.philsysNumber, Icons.badge_rounded, const Color(0xFF3B82F6)),
          ('Verification Status', 'eVerify Passed', Icons.verified_user_rounded, const Color(0xFF10B981)),
          ('Face Liveness', 'Confirmed', Icons.face_retouching_natural, const Color(0xFF8B5CF6)),
          ('Confidence Score', '${bank.confidenceScore}%', Icons.speed_rounded, const Color(0xFF06B6D4)),
        ]),
        const SizedBox(height: 16),
        _SectionHeader('Active eGov Services'),
        const SizedBox(height: 10),
        ...[
          ('eVerify', 'PhilSys Identity Backbone', Icons.verified_user_rounded, const Color(0xFF3B82F6)),
          ('Face Liveness', 'Anti-Deepfake Check', Icons.face_retouching_natural, const Color(0xFF8B5CF6)),
          ('eGovPH SSO', 'Active Bearer Token', Icons.key_rounded, const Color(0xFF06B6D4)),
          ('eMessage', 'Approval Notifications', Icons.notifications_active_rounded, const Color(0xFFF59E0B)),
          ('eGovChain', 'Audit Trail Logging', Icons.link_rounded, const Color(0xFF10B981)),
          ('eGovAI', 'Fraud Risk Engine', Icons.psychology_rounded, const Color(0xFFEF4444)),
        ].map((s) => _ServiceRow(name: s.$1, desc: s.$2, icon: s.$3, color: s.$4)),
      ],
    );
  }

  Widget _buildChainTab(List<AuditEvent> chain) {
    if (chain.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Icon(Icons.link_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('No chain events yet', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
            const SizedBox(height: 6),
            Text('Events are logged when you register,\nlogin, transfer, or pay bills.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 12, height: 1.5)),
          ]),
        ),
      );
    }

    final fmt = DateFormat('MMM d, HH:mm:ss');
    return Column(
      children: chain.reversed.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
            const SizedBox(width: 8),
            Text(e.eventType, style: GoogleFonts.inter(color: const Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(fmt.format(e.timestamp), style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Text('Block: ${e.blockHash}', style: GoogleFonts.jetBrainsMono(color: Colors.white.withValues(alpha: 0.4), fontSize: 9)),
          Text('Prev:  ${e.previousHash.substring(0, e.previousHash.length.clamp(0, 30))}...', style: GoogleFonts.jetBrainsMono(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
        ]),
      )).toList(),
    );
  }

  Widget _buildSecurityTab(BankingState bank, BuildContext context) {
    return Column(
      children: [
        _InfoCard(items: [
          ('SSO Token', bank.ssoToken.isNotEmpty ? '${bank.ssoToken.substring(0, 16)}...' : 'N/A', Icons.key_rounded, const Color(0xFF06B6D4)),
          ('Token Issuer', 'sso.egov.ph', Icons.dns_rounded, const Color(0xFF8B5CF6)),
          ('Token Scopes', 'identity, payments, documents', Icons.security_rounded, const Color(0xFF3B82F6)),
          ('Expires In', '3600s (auto-refresh)', Icons.timer_rounded, const Color(0xFF10B981)),
        ]),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _showSettingsSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF003087).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF003087).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.settings_suggest_rounded, color: Color(0xFF60A5FA), size: 18),
              const SizedBox(width: 8),
              Text('Configure eGov API Keys', style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await ref.read(bankingProvider.notifier).logout();
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/welcome');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              Text('Sign Out (eGovChain Logged)', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await ref.read(bankingProvider.notifier).clearAccount();
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/welcome');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: Text('Clear Account (Dev Reset)', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 13))),
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final ssoUrlCtrl = TextEditingController(text: ConfigService.ssoBaseUrl);
    final ssoCodeCtrl = TextEditingController(text: ConfigService.ssoPartnerCode);
    final ssoSecCtrl = TextEditingController(text: ConfigService.ssoPartnerSecret);

    final verifyUrlCtrl = TextEditingController(text: ConfigService.verifyBaseUrl);
    final verifyIdCtrl = TextEditingController(text: ConfigService.verifyClientId);
    final verifySecCtrl = TextEditingController(text: ConfigService.verifyClientSecret);

    final aiUrlCtrl = TextEditingController(text: ConfigService.aiBaseUrl);
    final aiCodeCtrl = TextEditingController(text: ConfigService.aiAccessCode);

    final liveUrlCtrl = TextEditingController(text: ConfigService.livenessBaseUrl);
    final liveKeyCtrl = TextEditingController(text: ConfigService.livenessApiKey);

    final rpcUrlCtrl = TextEditingController(text: ConfigService.chainRpcUrl);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1A30),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('eGov Hackathon API Settings', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              
              Text('eGov SSO Config', style: GoogleFonts.inter(color: const Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _SettingsInput(controller: ssoUrlCtrl, label: 'Base URL', hint: 'SSO Base URL'),
              _SettingsInput(controller: ssoCodeCtrl, label: 'Partner Code', hint: 'Partner Code'),
              _SettingsInput(controller: ssoSecCtrl, label: 'Partner Secret', hint: 'Partner Secret'),
              
              const Divider(color: Colors.white24, height: 24),
              Text('eVerify Config', style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _SettingsInput(controller: verifyUrlCtrl, label: 'Base URL', hint: 'Verify Base URL'),
              _SettingsInput(controller: verifyIdCtrl, label: 'Client ID', hint: 'Client ID'),
              _SettingsInput(controller: verifySecCtrl, label: 'Client Secret', hint: 'Client Secret'),

              const Divider(color: Colors.white24, height: 24),
              Text('eGovAI Config', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _SettingsInput(controller: aiUrlCtrl, label: 'Base URL', hint: 'AI Base URL'),
              _SettingsInput(controller: aiCodeCtrl, label: 'Access Code', hint: 'Access Code'),

              const Divider(color: Colors.white24, height: 24),
              Text('Face Liveness Config', style: GoogleFonts.inter(color: const Color(0xFF8B5CF6), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _SettingsInput(controller: liveUrlCtrl, label: 'Base URL', hint: 'Liveness Base URL'),
              _SettingsInput(controller: liveKeyCtrl, label: 'API Key (x-api-key)', hint: 'API Key'),

              const Divider(color: Colors.white24, height: 24),
              Text('eGovChain Config', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _SettingsInput(controller: rpcUrlCtrl, label: 'RPC Node URL', hint: 'Besu node URL'),

              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  await ConfigService.setSsoConfig(ssoUrlCtrl.text.trim(), ssoCodeCtrl.text.trim(), ssoSecCtrl.text.trim());
                  await ConfigService.setVerifyConfig(verifyUrlCtrl.text.trim(), verifyIdCtrl.text.trim(), verifySecCtrl.text.trim());
                  await ConfigService.setAiConfig(aiUrlCtrl.text.trim(), aiCodeCtrl.text.trim());
                  await ConfigService.setLivenessConfig(liveUrlCtrl.text.trim(), liveKeyCtrl.text.trim());
                  await ConfigService.setChainRpcUrl(rpcUrlCtrl.text.trim());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('eGov API configs updated successfully!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF10B981)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF003087), Color(0xFF0050C8)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Save Configurations', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _SettingsInput({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: controller,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _Tab extends StatelessWidget {
  final String label; final int index, current; final void Function(int) onTap;
  const _Tab(this.label, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF003087) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(child: Text(label, style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500))),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value; final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
    ]),
  ));
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2));
}

class _InfoCard extends StatelessWidget {
  final List<(String, String, IconData, Color)> items;
  const _InfoCard({required this.items});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF0D1A30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
    child: Column(children: items.map((i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: i.$4.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(i.$3, color: i.$4, size: 15)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.$1, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          Text(i.$2, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
      ]),
    )).toList()),
  );
}

class _ServiceRow extends StatelessWidget {
  final String name, desc; final IconData icon; final Color color;
  const _ServiceRow({required this.name, required this.desc, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF0D1A30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
    child: Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 15)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(desc, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      ])),
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
    ]),
  );
}
