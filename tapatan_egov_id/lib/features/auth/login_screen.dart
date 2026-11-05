import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/banking_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _psnCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showAnomalyWarning = false;

  Future<void> _login() async {
    if (_psnCtrl.text.trim().isEmpty || _pinCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = null; _showAnomalyWarning = false; });

    final result = await ref.read(bankingProvider.notifier).login(
      philsysNumber: _psnCtrl.text.trim().toUpperCase(),
      pin: _pinCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      if (result.anomalyDetected) {
        setState(() => _showAnomalyWarning = true);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _error = result.errorMessage ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Sign In', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('eGovPH SSO + eGovAI will verify your session',
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
            const SizedBox(height: 36),

            // API flow steps shown statically
            _StepRow(icon: Icons.verified_user_rounded, label: 'Validate SSO Token', color: const Color(0xFF3B82F6)),
            _StepRow(icon: Icons.psychology_rounded, label: 'eGovAI Login Risk Check', color: const Color(0xFFEF4444)),
            _StepRow(icon: Icons.link_rounded, label: 'eGovChain Audit Log', color: const Color(0xFF10B981)),
            const SizedBox(height: 28),

            _BankInput(controller: _psnCtrl, label: 'PhilSys Number (PSN)', hint: 'e.g. PSN-1234567', icon: Icons.badge_rounded),
            const SizedBox(height: 16),
            _BankInput(controller: _pinCtrl, label: 'PIN', hint: '••••••', icon: Icons.lock_rounded, obscure: true, keyboardType: TextInputType.number),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13))),
                ]),
              ),
            ],

            if (_showAnomalyWarning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('eGovAI flagged unusual login pattern. Proceeding with caution.',
                    style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 36),
            _BankButton(label: 'Sign In', onTap: _loading ? null : _login, loading: _loading),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text('No account? Create one →',
                  style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StepRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        ],
      ),
    );
  }
}

// Re-export shared widgets
class _BankInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;

  const _BankInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _BankButton({required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF4B5563)])
              : const LinearGradient(colors: [Color(0xFF003087), Color(0xFF0050C8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null ? [] : const [BoxShadow(color: Color(0x440050C8), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ),
    );
  }
}
