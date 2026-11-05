import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/banking_provider.dart';
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _psnCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  int _step = 0; // 0=Form, 1=Processing, 2=Done
  int _processingStep = 0;
  bool _loading = false;
  String _statusMessage = '';
  String? _error;
  String? _ssoError;
  int _confidence = 0;

  String _ssoToken = '';
  List<Map<String, dynamic>> _ssoLogs = [];

  final _steps = [
    ('eVerify', 'Checking PhilSys identity...', Icons.verified_user_rounded, Color(0xFF3B82F6)),
    ('Face Liveness', 'Running anti-deepfake check...', Icons.face_retouching_natural, Color(0xFF8B5CF6)),
    ('eGovChain', 'Logging registration event...', Icons.link_rounded, Color(0xFF10B981)),
  ];

  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'tapatan' && uri.host == 'auth-result') {
        final status = uri.queryParameters['status'];
        if (status == 'success') {
          setState(() {
            _ssoToken = uri.queryParameters['ssoToken'] ?? 'mock_sso_token';
            _nameCtrl.text = 'Juan Dela Cruz'; // Mocked or returned from token payload
            _psnCtrl.text = '6347365049241571';
            _loading = false;
          });
          // Proceed with rest of registration
        } else {
          setState(() {
            _ssoError = 'eGovPH App verification failed: ${uri.queryParameters['error']}';
            _loading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _nameCtrl.dispose();
    _psnCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectSSO() async {
    setState(() { _loading = true; _ssoError = null; });
    final uri = Uri.parse('egovph://auth?client=Tapatan Bank');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        setState(() {
          _ssoError = 'Could not launch eGovPH app. Please install it first.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _ssoError = 'Error launching eGovPH app: $e';
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _psnCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in Name and PSN');
      return;
    }
    if (_pinCtrl.text.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (_pinCtrl.text != _confirmPinCtrl.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() { _loading = true; _error = null; _step = 1; });

    // Simulate step progression while provider does actual work
    for (int i = 0; i < _steps.length; i++) {
      setState(() {
        _processingStep = i;
        _statusMessage = _steps[i].$2;
      });
      await Future.delayed(const Duration(milliseconds: 600));
    }

    final result = await ref.read(bankingProvider.notifier).register(
      name: _nameCtrl.text.trim(),
      philsysNumber: _psnCtrl.text.trim().toUpperCase(),
      pin: _pinCtrl.text,
      ssoToken: _ssoToken.isEmpty ? 'manual_entry_no_sso' : _ssoToken,
      initialLogs: _ssoLogs,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _step = 2;
        _confidence = result.confidenceScore ?? 97;
        _loading = false;
      });
    } else {
      setState(() {
        _step = 0;
        _loading = false;
        _error = result.errorMessage ?? 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: _step < 1 ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Create Account', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
      ) : null,
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    switch (_step) {
      case 0: return _buildForm();
      case 1: return _buildVerifying();
      case 2: return _buildSuccess();
      default: return const SizedBox();
    }
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Secured by Philippine\neGov Identity Stack',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 8),
          Text('Connect your eGovPH account to auto-fill, or enter your details manually.',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          
          GestureDetector(
            onTap: _loading ? null : _connectSSO,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.key_rounded, color: Color(0xFF06B6D4), size: 18),
                  const SizedBox(width: 8),
                  Text('Auto-fill with eGovPH SSO', style: GoogleFonts.inter(color: const Color(0xFF06B6D4), fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
          
          if (_ssoError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(_ssoError!),
          ],
          
          const SizedBox(height: 24),
          _BankInput(controller: _nameCtrl, label: 'Full Name', hint: 'As it appears on your PhilSys ID', icon: Icons.person_rounded),
          const SizedBox(height: 16),
          _BankInput(controller: _psnCtrl, label: 'PhilSys Number (PSN)', hint: 'e.g. PSN-1234567', icon: Icons.badge_rounded),
          const SizedBox(height: 16),
          _BankInput(controller: _pinCtrl, label: 'Create 6-Digit PIN', hint: '••••••', icon: Icons.lock_rounded, obscure: true, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _BankInput(controller: _confirmPinCtrl, label: 'Confirm PIN', hint: '••••••', icon: Icons.lock_outline_rounded, obscure: true, keyboardType: TextInputType.number),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorBox(_error!),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _loading ? null : () async {
                  setState(() { _loading = true; _error = null; });
                  await ref.read(bankingProvider.notifier).forceRegister(
                    name: _nameCtrl.text.trim(),
                    philsysNumber: _psnCtrl.text.trim().toUpperCase(),
                    pin: _pinCtrl.text,
                    ssoToken: _ssoToken.isEmpty ? 'bypassed_demo' : _ssoToken,
                  );
                  if (!mounted) return;
                  setState(() { _step = 2; _confidence = 100; _loading = false; });
                },
                child: Text(
                  'Bypass API Error (Demo Mode)',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFEF4444).withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          _BankButton(
            label: 'Create Account',
            onTap: _loading ? null : _register,
            loading: _loading,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'eVerify + Face Liveness required',
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildVerifying() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_steps[_processingStep].$4, _steps[_processingStep].$4.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _steps[_processingStep].$4.withValues(alpha: 0.3), blurRadius: 24)],
              ),
              child: Icon(_steps[_processingStep].$3, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 28),
            Text(_steps[_processingStep].$1,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_statusMessage, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            const SizedBox(height: 40),
            // Step indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final done = i < _processingStep;
                final active = i == _processingStep;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8, height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: done
                        ? const Color(0xFF10B981)
                        : active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.15),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Color(0x4410B981), blurRadius: 30)],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 28),
            Text('Account Created!', style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Your PhilSys identity was verified with $_confidence% confidence.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 8),
                  Text('Registration logged on eGovChain', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _BankButton(
              label: 'Go to Banking',
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared form widgets ──────────────────────────────────────────────────────

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
