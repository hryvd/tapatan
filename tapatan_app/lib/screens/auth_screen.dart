import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';
import '../utils/lucide_icons.dart';
import '../services/nfc_service.dart';
import '../providers/user_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum AuthView { welcome, login, signup, idVerification, registerCard }

// Accepted Philippine government IDs
const _govIds = [
  'PhilSys National ID',
  'Philippine Passport',
  'Driver\'s License (LTO)',
  'SSS (Social Security) ID',
  'GSIS (eCard)',
  'PRC Professional ID',
  'Voter\'s ID (COMELEC)',
  'Postal ID (PHLPost)',
];

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  AuthView _view = AuthView.welcome;
  bool _isReturningUser = false;
  bool _isLoading = false;
  bool _nfcTapping = false;
  bool _showPass = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  // KYC state
  int _kycStep = 0; // 0=id select, 1=front scan, 2=back scan, 3=face
  String? _selectedId;
  bool _frontCaptured = false;
  bool _backCaptured = false;
  bool _faceCaptured = false;
  bool _scanning = false;
  double _faceProgress = 0.0;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  String _cardStep = 'idle'; // idle, scanning, success

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    _checkRegistration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    if (isRegistered) {
      setState(() {
        _isReturningUser = true;
        _view = AuthView.login;
      });
    }
  }

  void _switchView(AuthView view) {
    setState(() => _view = view);
  }

  Future<void> _handleLogin() async {
    if (_pinController.text.length < 4) return;

    // Guard: check if account exists
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    if (!isRegistered) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No account found. Please create one first.'),
            backgroundColor: const Color(0xFF0369A1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => _isLoading = false);
    _navigateToMain();
  }

  Future<void> _handleSignupContinue() async {
    if (_pinController.text != _confirmPinController.text ||
        _pinController.text.length < 4) return;
    // Go to KYC ID verification
    setState(() {
      _kycStep = 0;
      _selectedId = null;
      _frontCaptured = false;
      _backCaptured = false;
      _faceCaptured = false;
      _faceProgress = 0.0;
    });
    _switchView(AuthView.idVerification);
  }

  Future<void> _handleNFCTap() async {
    if (_nfcTapping) return;
    setState(() => _nfcTapping = true);
    try {
      final res = await NfcService.readTagFromNfc();
      if (res['success'] == true) {
        _navigateToMain();
      }
    } catch (e) {
      // Ignored for UI
    } finally {
      setState(() => _nfcTapping = false);
    }
  }

  Future<void> _simulateScan(VoidCallback onDone) async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 2200));
    setState(() => _scanning = false);
    onDone();
  }

  Future<void> _simulateFaceScan() async {
    setState(() => _scanning = true);
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 280));
      if (mounted) setState(() => _faceProgress = i / 10);
    }
    setState(() {
      _scanning = false;
      _faceCaptured = true;
    });
  }

  Future<void> _handleCardRegister() async {
    setState(() => _cardStep = 'scanning');
    try {
      final payload = NfcService.buildTokenPayload(
          "new_card_${DateTime.now().millisecondsSinceEpoch}", null);
      final res = await NfcService.writeTokenToNfc(payload);

      if (res['success'] == true) {
        setState(() => _cardStep = 'success');
        await Future.delayed(const Duration(milliseconds: 1100));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('snfc_registered', true);

        await ref.read(userProvider.notifier).setUserData(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : "User",
              _emailController.text.isNotEmpty
                  ? _emailController.text
                  : "user@example.com",
            );

        _navigateToMain();
      } else {
        setState(() => _cardStep = 'idle');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Registration failed')),
          );
        }
      }
    } catch (e) {
      setState(() => _cardStep = 'idle');
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF000000),
            Color(0xFF020B18),
            Color(0xFF031424),
            Color(0xFF041E35),
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Ambient teal glow top-left
          Positioned(
            top: -100, left: -80,
            child: Container(
              width: 350, height: 350,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A0369A1),
              ),
            ),
          ),
          // Ambient blue glow bottom-right
          Positioned(
            bottom: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x160891B2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isNumber = false,
    int? maxLength,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8).withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword && !_showPass,
              keyboardType:
                  isNumber ? TextInputType.number : TextInputType.text,
              maxLength: maxLength,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 15),
                border: InputBorder.none,
                counterText: "",
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  // ─── Welcome View ─────────────────────────────────────────────────────────

  Widget _buildWelcomeView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0x440369A1), Color(0x330891B2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.5)),
                boxShadow: const [
                  BoxShadow(color: Color(0x4D0369A1), blurRadius: 40)
                ],
              ),
              child: const Icon(LucideIcons.shield,
                  color: Color(0xFF38BDF8), size: 44),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "tap@tan",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Colors.white),
          ),
          Text(
            "Java Card · Privacy-first · Tokenized",
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 32),
          ...[
            {
              'icon': LucideIcons.shield,
              'label': 'Hardware-secured Java Card auth',
              'color': const Color(0xFF0369A1)
            },
            {
              'icon': LucideIcons.wifi,
              'label': 'NFC tap-to-authenticate',
              'color': const Color(0xFF06B6D4)
            },
            {
              'icon': LucideIcons.zap,
              'label': 'Single-use tokenized payments',
              'color': const Color(0xFF0891B2)
            },
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: Colors.white.withOpacity(0.04),
                  border: Border.all(
                      color: (item['color'] as Color).withOpacity(0.2)),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item['icon'] as IconData,
                            size: 16, color: item['color'] as Color),
                      ),
                      const SizedBox(width: 12),
                      Text(item['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              )),
          const Spacer(),
          // Sign In — only shown if registered
          if (_isReturningUser)
            GlassButton(
              onPressed: () => _switchView(AuthView.login),
              child: const Text("Sign In",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          if (!_isReturningUser)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Center(
                child: Text(
                  "Sign In",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          if (!_isReturningUser)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "No account yet — create one to sign in",
                style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF38BDF8).withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          GlassButton(
            gradientColors: const [Color(0xFF0C1E35), Color(0xFF0A1628)],
            onPressed: () => _switchView(AuthView.signup),
            child: const Text("Create Account",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Login View ───────────────────────────────────────────────────────────

  Widget _buildLoginView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          if (!_isReturningUser)
            GestureDetector(
              onTap: () => _switchView(AuthView.welcome),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF0891B2).withOpacity(0.3))),
                child: const Icon(LucideIcons.arrowLeft,
                    size: 18, color: Color(0xFF38BDF8)),
              ),
            ),
          const SizedBox(height: 20),
          const Text("Welcome back",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          Text("Enter your PIN to continue",
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _emailController,
            icon: LucideIcons.mail,
            hint: "Email address",
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _pinController,
            icon: LucideIcons.lock,
            hint: "4-Digit PIN",
            isPassword: true,
            isNumber: true,
            maxLength: 4,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text("Forgot PIN?",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF38BDF8).withOpacity(0.8))),
          ),
          const SizedBox(height: 24),
          GlassButton(
            onPressed:
                _pinController.text.length == 4 ? _handleLogin : null,
            isLoading: _isLoading,
            child: const Text("Sign In",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          if (_isReturningUser) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.08))),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("or",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.3)))),
                Expanded(
                    child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.08))),
              ],
            ),
            const SizedBox(height: 16),
            GlassButton(
              onPressed: _nfcTapping ? null : _handleNFCTap,
              gradientColors: const [Color(0x4006B6D4), Color(0x330369A1)],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_nfcTapping) ...[
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4), strokeWidth: 2)),
                    const SizedBox(width: 12),
                    const Text("Reading Java Card...",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF67E8F9))),
                  ] else ...[
                    const Icon(LucideIcons.wifi,
                        color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 12),
                    const Text("Tap NFC Card to Unlock",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF67E8F9))),
                  ]
                ],
              ),
            ),
          ],
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () => _switchView(AuthView.signup),
              child: RichText(
                text: TextSpan(
                  text: "No account? ",
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.4)),
                  children: const [
                    TextSpan(
                      text: "Create one",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Signup View ──────────────────────────────────────────────────────────

  Widget _buildSignupView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => _switchView(AuthView.welcome),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0891B2).withOpacity(0.3))),
              child: const Icon(LucideIcons.arrowLeft,
                  size: 18, color: Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Create account",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text("Personal details & identity verification required",
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 24),
          _buildTextField(
              controller: _nameController,
              icon: LucideIcons.user,
              hint: "Full name"),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _emailController,
              icon: LucideIcons.mail,
              hint: "Email address"),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _pinController,
              icon: LucideIcons.lock,
              hint: "4-Digit PIN",
              isPassword: true,
              isNumber: true,
              maxLength: 4),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _confirmPinController,
            icon: LucideIcons.lock,
            hint: "Confirm PIN",
            isPassword: true,
            isNumber: true,
            maxLength: 4,
            suffix: GestureDetector(
              onTap: () => setState(() => _showPass = !_showPass),
              child: Icon(
                  _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
                  color: Colors.white.withOpacity(0.3),
                  size: 18),
            ),
          ),
          if (_confirmPinController.text.length == 4 &&
              _confirmPinController.text != _pinController.text)
            const Padding(
              padding: EdgeInsets.only(top: 8.0, left: 8.0),
              child: Text("PINs do not match",
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          // KYC badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0369A1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shield,
                    size: 15, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "ID verification required — you\'ll scan a gov\'t ID + face next",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: (_pinController.text.length == 4 &&
                    _pinController.text == _confirmPinController.text &&
                    _nameController.text.isNotEmpty &&
                    _emailController.text.isNotEmpty)
                ? _handleSignupContinue
                : null,
            child: const Text("Continue to ID Verification",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () => _switchView(AuthView.login),
              child: RichText(
                text: TextSpan(
                  text: "Already have an account? ",
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.4)),
                  children: const [
                    TextSpan(
                      text: "Sign in",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ID Verification View ─────────────────────────────────────────────────

  Widget _buildIdVerificationView() {
    final steps = ['Select ID', 'Front Scan', 'Back Scan', 'Face Check'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          // Header
          Row(
            children: [
              GestureDetector(
                onTap: _kycStep > 0
                    ? () => setState(() => _kycStep--)
                    : () => _switchView(AuthView.signup),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF0891B2).withOpacity(0.3))),
                  child: const Icon(LucideIcons.arrowLeft,
                      size: 18, color: Color(0xFF38BDF8)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Identity Verification",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  Text("Step ${_kycStep + 1} of 4 — ${steps[_kycStep]}",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Step progress
          Row(
            children: List.generate(4, (i) {
              final done = i < _kycStep;
              final active = i == _kycStep;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: done || active
                          ? const LinearGradient(
                              colors: [Color(0xFF0369A1), Color(0xFF0891B2)])
                          : null,
                      color: done || active
                          ? null
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _kycStep == 0
                  ? _buildIdSelectStep()
                  : _kycStep == 1
                      ? _buildIdScanStep(isFront: true)
                      : _kycStep == 2
                          ? _buildIdScanStep(isFront: false)
                          : _buildFaceStep(),
            ),
          ),

          // Action button
          _buildKycActionButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildIdSelectStep() {
    return SingleChildScrollView(
      key: const ValueKey('id-select'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select your government-issued ID",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 6),
          Text("Only accepted Philippine national IDs are listed",
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 16),
          ..._govIds.map((id) {
            final selected = _selectedId == id;
            return GestureDetector(
              onTap: () => setState(() => _selectedId = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            Color(0x400369A1),
                            Color(0x300891B2)
                          ],
                        )
                      : null,
                  color: selected ? null : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF0891B2)
                        : Colors.white.withOpacity(0.08),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: selected
                            ? const Color(0xFF0891B2).withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                      ),
                      child: Icon(LucideIcons.creditCard,
                          size: 16,
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(id,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7))),
                    ),
                    if (selected)
                      const Icon(LucideIcons.checkCircle,
                          size: 18, color: Color(0xFF38BDF8)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0369A1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info,
                    size: 14, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Your ID is verified locally and never stored on external servers.",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdScanStep({required bool isFront}) {
    final captured = isFront ? _frontCaptured : _backCaptured;
    final key = ValueKey(isFront ? 'front' : 'back');

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isFront ? "Scan Front of ID" : "Scan Back of ID",
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          isFront
              ? "Place the front of your ${_selectedId ?? 'ID'} inside the frame"
              : "Now flip your ID and align the back inside the frame",
          style:
              TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Camera frame
        Center(
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) => Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: captured
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0891B2)
                          .withOpacity(0.6 + _glowAnim.value * 0.4),
                  width: 2,
                ),
                color: Colors.black.withOpacity(0.4),
                boxShadow: [
                  BoxShadow(
                    color: captured
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF0891B2)
                            .withOpacity(0.15 * _glowAnim.value),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: child,
            ),
            child: Stack(
              children: [
                // Corner marks
                ..._buildScanCorners(captured),

                // Center content
                Center(
                  child: _scanning
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF0891B2),
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 12),
                            Text("Scanning...",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.6))),
                          ],
                        )
                      : captured
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.2),
                                  ),
                                  child: const Icon(LucideIcons.checkCircle,
                                      color: Color(0xFF34D399), size: 32),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    isFront
                                        ? "Front captured ✓"
                                        : "Back captured ✓",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF34D399))),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isFront
                                      ? LucideIcons.creditCard
                                      : LucideIcons.scanLine,
                                  size: 40,
                                  color: const Color(0xFF38BDF8)
                                      .withOpacity(0.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                    "Tap 'Capture' to scan ${isFront ? 'front' : 'back'}",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.4))),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (!captured)
          GestureDetector(
            onTap: _scanning
                ? null
                : () => _simulateScan(() {
                      setState(() {
                        if (isFront) {
                          _frontCaptured = true;
                        } else {
                          _backCaptured = true;
                        }
                      });
                    }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x400891B2),
                      blurRadius: 20,
                      offset: Offset(0, 6))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.camera,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _scanning ? "Scanning..." : "Capture",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildScanCorners(bool captured) {
    final color = captured
        ? const Color(0xFF34D399)
        : const Color(0xFF38BDF8);
    const size = 20.0;
    const thick = 2.5;
    return [
      Positioned(
          top: 12, left: 12,
          child: _corner(color, size, thick, top: true, left: true)),
      Positioned(
          top: 12, right: 12,
          child: _corner(color, size, thick, top: true, left: false)),
      Positioned(
          bottom: 12, left: 12,
          child: _corner(color, size, thick, top: false, left: true)),
      Positioned(
          bottom: 12, right: 12,
          child: _corner(color, size, thick, top: false, left: false)),
    ];
  }

  Widget _corner(Color color, double size, double thick,
      {required bool top, required bool left}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color, thick: thick, top: top, left: left),
      ),
    );
  }

  Widget _buildFaceStep() {
    return Column(
      key: const ValueKey('face'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Face Recognition",
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          "Look directly at the camera and keep your face centered",
          style:
              TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Face oval frame
        Center(
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) => Container(
              width: 240,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(120),
                border: Border.all(
                  color: _faceCaptured
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0891B2)
                          .withOpacity(0.5 + _glowAnim.value * 0.5),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _faceCaptured
                        ? const Color(0xFF10B981).withOpacity(0.35)
                        : const Color(0xFF0891B2)
                            .withOpacity(0.2 * _glowAnim.value),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: child,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_faceCaptured) ...[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withOpacity(0.2),
                    ),
                    child: const Icon(LucideIcons.checkCircle,
                        color: Color(0xFF34D399), size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text("Identity Verified",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF34D399))),
                ] else if (_scanning) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: _faceProgress,
                      color: const Color(0xFF0891B2),
                      backgroundColor: Colors.white.withOpacity(0.08),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "${(_faceProgress * 100).toInt()}%",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(height: 6),
                  Text("Analyzing biometrics...",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5))),
                ] else ...[
                  Icon(LucideIcons.user,
                      size: 56,
                      color: const Color(0xFF38BDF8).withOpacity(0.3)),
                  const SizedBox(height: 10),
                  Text("Position your face here",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4))),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Liveness instructions
        if (!_faceCaptured && !_scanning) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0369A1).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildInstruction(
                    LucideIcons.sun, "Ensure good lighting on your face"),
                const SizedBox(height: 6),
                _buildInstruction(
                    LucideIcons.eye, "Remove glasses if possible"),
                const SizedBox(height: 6),
                _buildInstruction(
                    LucideIcons.shield, "Custom liveness detection — not device biometrics"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _simulateFaceScan,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x400891B2),
                      blurRadius: 20,
                      offset: Offset(0, 6))
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.scanFace, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Start Face Scan",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],

        if (_faceProgress > 0 && !_faceCaptured)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _faceProgress,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF0891B2)),
                minHeight: 4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstruction(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF38BDF8).withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ),
      ],
    );
  }

  Widget _buildKycActionButton() {
    bool canProceed = false;
    String label = "Next";

    if (_kycStep == 0) {
      canProceed = _selectedId != null;
      label = "Continue";
    } else if (_kycStep == 1) {
      canProceed = _frontCaptured;
      label = "Next: Back of ID";
    } else if (_kycStep == 2) {
      canProceed = _backCaptured;
      label = "Next: Face Check";
    } else if (_kycStep == 3) {
      canProceed = _faceCaptured;
      label = "Complete Verification";
    }

    return GlassButton(
      onPressed: canProceed
          ? () {
              if (_kycStep < 3) {
                setState(() => _kycStep++);
              } else {
                _switchView(AuthView.registerCard);
              }
            }
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(width: 8),
          const Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
        ],
      ),
    );
  }

  // ─── Register Card View ───────────────────────────────────────────────────

  Widget _buildRegisterCardView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Text("Register Java Card",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text("Tap your card once to bind it to your account",
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.4))),
          const Spacer(),
          GestureDetector(
            onTap: _cardStep == 'idle' ? _handleCardRegister : null,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _cardStep == 'idle' ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _cardStep == 'success'
                        ? Colors.green
                        : const Color(0xFF0891B2),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    colors: _cardStep == 'success'
                        ? [
                            Colors.green.withOpacity(0.2),
                            Colors.greenAccent.withOpacity(0.2)
                          ]
                        : [
                            const Color(0x330891B2),
                            const Color(0x330369A1)
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cardStep == 'success'
                          ? Colors.green.withOpacity(0.5)
                          : const Color(0xFF0891B2).withOpacity(0.5),
                      blurRadius: 40,
                    )
                  ],
                ),
                child: Center(
                  child: _cardStep == 'success'
                      ? const Icon(LucideIcons.checkCircle,
                          color: Colors.greenAccent, size: 48)
                      : _cardStep == 'scanning'
                          ? const CircularProgressIndicator(
                              color: Color(0xFF0891B2))
                          : const Icon(LucideIcons.wifi,
                              color: Color(0xFF38BDF8), size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.white.withOpacity(0.04),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          width: 12,
                          height: 8,
                          color: Colors.yellow.withOpacity(0.8)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _cardStep == 'success'
                              ? "Java Card Registered ✓"
                              : "Java Card",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text(
                        _cardStep == 'idle'
                            ? "Not yet linked to account"
                            : _cardStep == 'scanning'
                                ? "Reading secure element..."
                                : "Bound to your account",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4)),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _view == AuthView.welcome
                  ? _buildWelcomeView()
                  : _view == AuthView.login
                      ? _buildLoginView()
                      : _view == AuthView.signup
                          ? _buildSignupView()
                          : _view == AuthView.idVerification
                              ? _buildIdVerificationView()
                              : _buildRegisterCardView(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner Painter ────────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top;
  final bool left;

  _CornerPainter(
      {required this.color,
      required this.thick,
      required this.top,
      required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final ex = left ? size.width : 0.0;
    final ey = top ? size.height : 0.0;

    // Horizontal arm
    canvas.drawLine(Offset(x, y), Offset(ex, y), paint);
    // Vertical arm
    canvas.drawLine(Offset(x, y), Offset(x, ey), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
