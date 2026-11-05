import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_demo/everify_screen.dart';
import '../api_demo/liveness_screen.dart';
import '../api_demo/sso_screen.dart';
import '../api_demo/emessage_screen.dart';
import '../api_demo/chain_screen.dart';
import '../api_demo/ai_screen.dart';
import '../api_demo/full_flow_screen.dart';

class EGovHomeScreen extends StatelessWidget {
  const EGovHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08142B),
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Run Full Flow button
                _FullFlowButton(),
                const SizedBox(height: 28),
                Text(
                  'API Modules',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                ..._apis(context).map((api) => _ApiCard(api: api)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF08142B),
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF003087), Color(0xFF0050C8), Color(0xFF0A1F5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Stars/dots overlay
            ...List.generate(30, (i) {
              final r = (i * 7919) % 100 / 100;
              final size = 1.5 + (i % 3) * 1.0;
              return Positioned(
                left: ((i * 37) % 100) / 100 * 400,
                top: ((i * 53) % 100) / 100 * 200,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3 + r * 0.4),
                  ),
                ),
              );
            }),
            // PH sun emblem hint
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                ),
              ),
            ),
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'eGov ID API Hub',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Philippine Government Identity Services',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      _Chip('v2.4', Icons.tag, const Color(0xFF60A5FA)),
                      _Chip('6 APIs', Icons.api, const Color(0xFF34D399)),
                      _Chip('Mock Mode', Icons.developer_mode, const Color(0xFFFBBF24)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      title: Text(
        'eGov ID Hub',
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  List<_ApiInfo> _apis(BuildContext context) => [
    _ApiInfo(
      name: 'eVerify',
      subtitle: 'PhilSys Identity Backbone',
      description: 'Confirms the request is tied to a real PhilSys-verified identity, not a spoofed account.',
      icon: Icons.verified_user_rounded,
      color: const Color(0xFF3B82F6),
      gradient: const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      screen: const EVerifyScreen(),
    ),
    _ApiInfo(
      name: 'Face Liveness',
      subtitle: 'Anti-Deepfake Check',
      description: 'Ensures a real person (not a photo/deepfake) is approving — critical since this replaces OTP entirely.',
      icon: Icons.face_retouching_natural,
      color: const Color(0xFF8B5CF6),
      gradient: const [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      screen: const LivenessScreen(),
    ),
    _ApiInfo(
      name: 'eGovPH SSO',
      subtitle: 'Single Sign-On Entry Point',
      description: 'The actual "login" surface other apps redirect to. Issues scoped access tokens after verification.',
      icon: Icons.key_rounded,
      color: const Color(0xFF06B6D4),
      gradient: const [Color(0xFF0E7490), Color(0xFF06B6D4)],
      screen: const SsoScreen(),
    ),
    _ApiInfo(
      name: 'eMessage',
      subtitle: 'Push Approval Notifications',
      description: 'Pushes the approval request to the user\'s device. User sees: "Tapatan wants to process ₱5,000 — Approve?"',
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFFF59E0B),
      gradient: const [Color(0xFFB45309), Color(0xFFF59E0B)],
      screen: const EMessageScreen(),
    ),
    _ApiInfo(
      name: 'eGovChain',
      subtitle: 'Tamper-Evident Audit Trail',
      description: 'Tamper-evident log of every authentication event — useful for fraud disputes ("I never approved that login").',
      icon: Icons.link_rounded,
      color: const Color(0xFF10B981),
      gradient: const [Color(0xFF047857), Color(0xFF10B981)],
      screen: const ChainScreen(),
    ),
    _ApiInfo(
      name: 'eGovAI',
      subtitle: 'AI Fraud Detection',
      description: 'Flags anomalous approval patterns: impossible travel, rapid repeated requests, geo anomalies, etc.',
      icon: Icons.psychology_rounded,
      color: const Color(0xFFEF4444),
      gradient: const [Color(0xFFB91C1C), Color(0xFFEF4444)],
      screen: const AiScreen(),
    ),
  ];
}

class _ApiInfo {
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final Widget screen;

  const _ApiInfo({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.screen,
  });
}

class _ApiCard extends StatelessWidget {
  final _ApiInfo api;
  const _ApiCard({required this.api});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => api.screen),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F3C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: api.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: api.color.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: api.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(api.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    api.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    api.subtitle,
                    style: GoogleFonts.inter(
                      color: api.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    api.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _FullFlowButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FullFlowScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003087), Color(0xFF0050C8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x440050C8), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Run Full eGov Flow',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                  Text('eVerify → Liveness → SSO → eMessage → Chain → AI',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                    )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
