import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/banking_provider.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankingProvider);

    // Auto-redirect if already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: Stack(
        children: [
          // Background gradient orbs
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  // Logo block
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF003087), Color(0xFF0050C8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x660050C8), blurRadius: 30, offset: Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),

                  Text('Tapatan\neGov Bank',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    )),
                  const SizedBox(height: 14),
                  Text(
                    'Secured by the Philippine Government\'s eGov Identity Stack — eVerify, Face Liveness, SSO, eMessage, eGovChain & eGovAI.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Feature pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill('eVerify', Icons.verified_user_rounded, const Color(0xFF3B82F6)),
                      _Pill('Face Liveness', Icons.face_retouching_natural, const Color(0xFF8B5CF6)),
                      _Pill('eGovPH SSO', Icons.key_rounded, const Color(0xFF06B6D4)),
                      _Pill('eMessage', Icons.notifications_active_rounded, const Color(0xFFF59E0B)),
                      _Pill('eGovChain', Icons.link_rounded, const Color(0xFF10B981)),
                      _Pill('eGovAI', Icons.psychology_rounded, const Color(0xFFEF4444)),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // CTA Buttons
                  if (state.isRegistered) ...[
                    _PrimaryButton(
                      label: 'Sign In',
                      icon: Icons.login_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(
                      label: 'Create New Account',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                    ),
                  ] else ...[
                    _PrimaryButton(
                      label: 'Create Account',
                      icon: Icons.person_add_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.isRegistered)
                      _SecondaryButton(
                        label: 'Sign In',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: Text('Protected by Philippine eGov Identity Services',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -120, right: -80,
          child: Container(
            width: 350, height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF003087).withValues(alpha: 0.15),
            ),
          ),
        ),
        Positioned(
          bottom: -100, left: -60,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0050C8).withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Pill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003087), Color(0xFF0050C8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x440050C8), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}
