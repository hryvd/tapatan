import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';
import '../utils/lucide_icons.dart';
import '../services/nfc_service.dart';
import '../providers/user_provider.dart';

enum AuthView { welcome, login, signup, registerCard }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  AuthView _view = AuthView.welcome;
  bool _isLoading = false;
  bool _nfcTapping = false;
  bool _nfcCompleted = false;
  bool _isNavigating = false;
  bool _showPass = false;
  String _cardStep = 'idle'; // idle, scanning, success, error

  int _retrySecondsLeft = 0;
  Timer? _retryTimer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkRegistration();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    NfcService.stopSession();
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    await ref.read(userProvider.notifier).reloadFromPrefs();
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    if (isRegistered) {
      final email = prefs.getString('snfc_email') ?? '';
      if (email.isNotEmpty) {
        _emailController.text = email;
      }
      if (mounted) {
        _switchView(AuthView.login);
      }
    }
  }

  void _switchView(AuthView view) {
    _retryTimer?.cancel();
    NfcService.stopSession();
    setState(() {
      _view = view;
      _cardStep = 'idle';
      _nfcTapping = false;
      _retrySecondsLeft = 0;
    });

    if (view == AuthView.login && !_nfcCompleted && !_isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _view == AuthView.login &&
            !_nfcTapping &&
            !_nfcCompleted &&
            !_isNavigating) {
          _handleNFCTapLogin(simulate: false);
        }
      });
    }
  }

  void _start5SecRetryTimer(VoidCallback onRescan) {
    _retryTimer?.cancel();
    if (!mounted || _nfcCompleted || _isNavigating) return;
    setState(() => _retrySecondsLeft = 5);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _nfcCompleted || _isNavigating) {
        timer.cancel();
        return;
      }
      if (_retrySecondsLeft <= 1) {
        timer.cancel();
        setState(() => _retrySecondsLeft = 0);
        onRescan();
      } else {
        setState(() => _retrySecondsLeft--);
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF0369A1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Demo Quick Sign-In ─────────────────────────────────────────────────────

  Future<void> _handleQuickDemoLogin() async {
    if (_isNavigating) return;
    _retryTimer?.cancel();
    await NfcService.stopSession();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    await ref.read(userProvider.notifier).reloadFromPrefs();
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    final savedName = prefs.getString('snfc_name') ?? '';
    final savedEmail = prefs.getString('snfc_email') ?? '';

    if (isRegistered && savedName.isNotEmpty) {
      ref.read(userProvider.notifier).armCard();
      ref.read(userProvider.notifier).updateJcopCardInfo(
            uid: prefs.getString('snfc_jcop_uid') ?? '04:7A:93:E2:10:88:01',
            pinRetriesLeft: 5,
            lifecycleState: 'ENROLLED',
          );
      if (mounted) setState(() => _isLoading = false);
      _navigateToMain();
      return;
    }

    final demoName = savedName.isNotEmpty ? savedName : 'Richard';
    final demoEmail = savedEmail.isNotEmpty ? savedEmail : 'richard@tapat.ph';

    await ref.read(userProvider.notifier).setUserData(
          demoName,
          demoEmail,
          cardId: 'TAPAT_JCOP4_8821',
          initialBalance: 5000.00,
        );
    ref.read(userProvider.notifier).armCard();
    ref.read(userProvider.notifier).updateJcopCardInfo(
          uid: '04:7A:93:E2:10:88:01',
          pinRetriesLeft: 5,
          lifecycleState: 'ENROLLED',
        );

    if (mounted) setState(() => _isLoading = false);
    _navigateToMain();
  }

  // ── Standard Login ─────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (_isNavigating) return;
    if (_pinController.text.length < 4) {
      _showSnack('Please enter your 4 to 6-digit PIN', isError: true);
      return;
    }

    _retryTimer?.cancel();
    await NfcService.stopSession();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    await ref.read(userProvider.notifier).reloadFromPrefs();
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('snfc_registered') ?? false;
    final savedName = prefs.getString('snfc_name') ?? '';

    if (!isRegistered || savedName.isEmpty) {
      final emailInput = _emailController.text.trim();
      final prefix = emailInput.contains('@')
          ? emailInput.split('@').first
          : emailInput;
      final displayName = prefix.isNotEmpty
          ? prefix[0].toUpperCase() + prefix.substring(1)
          : 'Cardholder';
      final email = emailInput.isNotEmpty ? emailInput : 'user@tapat.ph';
      await ref.read(userProvider.notifier).setUserData(
            displayName,
            email,
            cardId: 'TAPAT_JCOP4_8821',
            initialBalance: 5000.00,
          );
    }

    ref.read(userProvider.notifier).updateJcopCardInfo(
          uid: prefs.getString('snfc_jcop_uid') ?? '04:7A:93:E2:10:88:01',
          pinRetriesLeft: 5,
          lifecycleState: 'ENROLLED',
        );

    if (mounted) setState(() => _isLoading = false);
    _navigateToMain();
  }

  // ── NFC Tap Login (Single-Shot Action + 5s Auto Rescan on Failure) ─────────

  Future<void> _handleNFCTapLogin({bool simulate = false}) async {
    // Only one NFC action is allowed; ignore any duplicate scan if already tapping or completed
    if (_nfcTapping || _nfcCompleted || _isNavigating) return;
    _retryTimer?.cancel();
    setState(() {
      _nfcTapping = true;
      _retrySecondsLeft = 0;
    });

    try {
      await ref.read(userProvider.notifier).reloadFromPrefs();
      if (simulate) {
        _nfcCompleted = true;
        await Future.delayed(const Duration(milliseconds: 500));
        await _handleQuickDemoLogin();
        return;
      }

      final res = await NfcService.readCardIdentity();
      if (!mounted || _view != AuthView.login || _isNavigating || _nfcCompleted) {
        return;
      }

      if (res['success'] == true) {
        final uid = (res['uid'] as String?) ?? '04:7A:93:E2:10:88:01';
        final cardId = (res['cardId'] as String?) ?? 'TAPAT_JCOP4_8821';
        final owner = (res['owner'] as String?) ?? 'user@tapat.ph';
        final cardName = (res['name'] as String?) ?? '';

        final user = ref.read(userProvider);
        if (user.name.isNotEmpty &&
            user.cardId.isNotEmpty &&
            cardId != user.cardId &&
            cardId != 'TAPAT_JCOP4_8821') {
          setState(() => _nfcTapping = false);
          _showSnack(
            'Card Mismatch: Card ($cardId) is not bound to ${user.name}\'s account (${user.cardId}). Re-scanning in 5s...',
            isError: true,
          );
          _start5SecRetryTimer(() {
            if (mounted && _view == AuthView.login && !_nfcCompleted) {
              _handleNFCTapLogin(simulate: false);
            }
          });
          return;
        }

        // Lock single-shot completion so any second NFC read is ignored
        _nfcCompleted = true;
        setState(() => _nfcTapping = false);

        if (user.name.isEmpty) {
          final prefix = owner.contains('@') ? owner.split('@').first : owner;
          final resolvedName = cardName.isNotEmpty
              ? cardName
              : (prefix.isNotEmpty && prefix.toLowerCase() != 'harry'
                  ? prefix[0].toUpperCase() + prefix.substring(1)
                  : 'Cardholder');
          await ref.read(userProvider.notifier).setUserData(
                resolvedName,
                owner,
                cardId: cardId,
                initialBalance: 5000.00,
              );
        }
        ref.read(userProvider.notifier).armCard();
        ref.read(userProvider.notifier).updateJcopCardInfo(
              uid: uid,
              pinRetriesLeft: 5,
              lifecycleState: 'ENROLLED',
            );
        _navigateToMain();
      } else {
        setState(() => _nfcTapping = false);
        _showSnack(
          '${(res['error'] as String?) ?? 'NFC Card recognition failed.'} Re-scanning in 5s...',
          isError: true,
        );
        _start5SecRetryTimer(() {
          if (mounted && _view == AuthView.login && !_nfcCompleted) {
            _handleNFCTapLogin(simulate: false);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _nfcTapping = false);
      _showSnack('NFC error: $e. Re-scanning in 5s...', isError: true);
      _start5SecRetryTimer(() {
        if (mounted && _view == AuthView.login && !_nfcCompleted) {
          _handleNFCTapLogin(simulate: false);
        }
      });
    }
  }

  // ── Signup Steps ───────────────────────────────────────────────────────────

  void _handleSignupContinue() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (name.length < 2) {
      _showSnack('Please enter your full name', isError: true);
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnack('Please enter a valid email address', isError: true);
      return;
    }
    if (pin.length < 4) {
      _showSnack('PIN must be at least 4-6 digits', isError: true);
      return;
    }
    if (pin != confirm) {
      _showSnack('PINs do not match', isError: true);
      return;
    }

    _switchView(AuthView.registerCard);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _view == AuthView.registerCard &&
          _cardStep == 'idle' &&
          !_nfcCompleted) {
        _handleCardRegister(simulate: false);
      }
    });
  }

  Future<void> _handleCardRegister({bool simulate = false}) async {
    // Single-action guard: ignore duplicate tap while scanning or after success
    if (_cardStep == 'scanning' ||
        _cardStep == 'success' ||
        _nfcCompleted ||
        _isNavigating) {
      return;
    }

    _retryTimer?.cancel();
    setState(() {
      _cardStep = 'scanning';
      _retrySecondsLeft = 0;
    });

    try {
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : 'user@tapat.ph';
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Cardholder';

      if (simulate) {
        _nfcCompleted = true;
        await Future.delayed(const Duration(milliseconds: 600));
        const cardId = 'TAPAT_JCOP4_8821';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('snfc_registered', true);
        await prefs.setString('snfc_pin', _pinController.text.trim());
        await ref.read(userProvider.notifier).setUserData(
              name,
              email,
              cardId: cardId,
              initialBalance: 5000.00,
            );
        ref.read(userProvider.notifier).armCard();
        ref.read(userProvider.notifier).updateJcopCardInfo(
              uid: '04:7A:93:E2:10:88:01',
              pinRetriesLeft: 5,
              lifecycleState: 'ENROLLED',
            );

        if (mounted) setState(() => _cardStep = 'success');
        await Future.delayed(const Duration(milliseconds: 350));
        _navigateToMain();
        return;
      }

      final cardId = NfcService.generateCardId();
      final res = await NfcService.writeCardIdentity(cardId, email, name: name);

      if (!mounted ||
          _view != AuthView.registerCard ||
          _isNavigating ||
          _nfcCompleted) {
        return;
      }

      if (res['success'] == true) {
        _nfcCompleted = true;
        final uid = (res['uid'] as String?) ?? '04:7A:93:E2:10:88:01';
        setState(() => _cardStep = 'success');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('snfc_registered', true);
        await prefs.setString('snfc_pin', _pinController.text.trim());
        await ref.read(userProvider.notifier).setUserData(
              name,
              email,
              cardId: cardId,
              initialBalance: 5000.00,
            );
        ref.read(userProvider.notifier).armCard();
        ref.read(userProvider.notifier).updateJcopCardInfo(
              uid: uid,
              pinRetriesLeft: 5,
              lifecycleState: 'ENROLLED',
            );
        await Future.delayed(const Duration(milliseconds: 350));
        _navigateToMain();
      } else {
        setState(() => _cardStep = 'error');
        _showSnack(
          '${(res['error'] as String?) ?? 'Card recognition failed.'} Re-scanning in 5s...',
          isError: true,
        );
        _start5SecRetryTimer(() {
          if (mounted &&
              _view == AuthView.registerCard &&
              !_nfcCompleted &&
              !_isNavigating) {
            _handleCardRegister(simulate: false);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cardStep = 'error');
      _showSnack('Error: $e. Re-scanning in 5s...', isError: true);
      _start5SecRetryTimer(() {
        if (mounted &&
            _view == AuthView.registerCard &&
            !_nfcCompleted &&
            !_isNavigating) {
          _handleCardRegister(simulate: false);
        }
      });
    }
  }

  void _navigateToMain() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _retryTimer?.cancel();
    NfcService.stopSession();
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
  }

  // ── Background Glow ────────────────────────────────────────────────────────

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
          stops: [0.0, 0.35, 0.65, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x220369A1),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x180891B2),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              color: const Color(0xFF38BDF8).withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword && !_showPass,
              keyboardType:
                  isNumber ? TextInputType.number : TextInputType.text,
              maxLength: maxLength,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  // ── Welcome View ───────────────────────────────────────────────────────────

  Widget _buildWelcomeView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Shield Logo
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0369A1).withValues(alpha: 0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(LucideIcons.shield, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bantay',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Dual-Layered Defense & JCOP J3R150 Hardware Security',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Feature pills
          ...[
            {
              'icon': LucideIcons.shieldCheck,
              'label': 'JCOP J3R150 Smart Card Security',
              'color': const Color(0xFF0369A1)
            },
            {
              'icon': LucideIcons.store,
              'label': 'Dual-Layered Protection with Sar-E Store',
              'color': const Color(0xFF0891B2)
            },
            {
              'icon': LucideIcons.keyRound,
              'label': 'Turing Composition Mutual Authentication',
              'color': const Color(0xFF06B6D4)
            },
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                      color: (item['color'] as Color).withValues(alpha: 0.3)),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              (item['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item['icon'] as IconData,
                            size: 17, color: item['color'] as Color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              )),

          const Spacer(flex: 2),

          // Sign In button
          GlassButton(
            onPressed: () => _switchView(AuthView.login),
            child: const Text('Sign In',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 12),

          // Create Account button
          GlassButton(
            gradientColors: const [Color(0xFF0C1E35), Color(0xFF0A1628)],
            onPressed: () => _switchView(AuthView.signup),
            child: const Text('Create Account',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(height: 12),

          // Quick Demo Sign-in for presentation & thesis panel
          GestureDetector(
            onTap: _handleQuickDemoLogin,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.zap,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Demo Sign-In (Pre-Loaded Account)',
                    style: TextStyle(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Login View ─────────────────────────────────────────────────────────────

  Widget _buildLoginView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      children: [
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => _switchView(AuthView.welcome),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.arrowLeft,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Welcome Back',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text('Tap your Tapat Card or enter your 6-digit PIN to sign in',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 28),

        // Email field
        _buildTextField(
          controller: _emailController,
          icon: LucideIcons.mail,
          hint: 'Email address (e.g. richard@tapat.ph)',
        ),
        const SizedBox(height: 14),

        // 6-digit PIN field
        _buildTextField(
          controller: _pinController,
          icon: LucideIcons.lock,
          hint: '6-Digit Card PIN',
          isPassword: true,
          isNumber: true,
          maxLength: 6,
          suffix: GestureDetector(
            onTap: () => setState(() => _showPass = !_showPass),
            child: Icon(
              _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick demo hint
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final savedEmail = prefs.getString('snfc_email') ?? '';
                _emailController.text =
                    savedEmail.isNotEmpty ? savedEmail : 'richard@tapat.ph';
                _pinController.text = prefs.getString('snfc_pin') ?? '123456';
                if (mounted) setState(() {});
              },
              child: Text(
                'Autofill Registered Credentials',
                style: TextStyle(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () => _showSnack(
                  'PIN can be reset via registered email verification.'),
              child: Text(
                'Forgot PIN?',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sign In Button
        GlassButton(
          onPressed: _handleLogin,
          isLoading: _isLoading,
          child: const Text('Sign In',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(
                child: Container(
                    height: 1, color: Colors.white.withValues(alpha: 0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('OR',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
                child: Container(
                    height: 1, color: Colors.white.withValues(alpha: 0.1))),
          ],
        ),
        const SizedBox(height: 16),

        // Tap Card to Login button
        GestureDetector(
          onTap: () => _handleNFCTapLogin(simulate: false),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0369A1).withValues(alpha: 0.25),
                  const Color(0xFF0891B2).withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_nfcTapping)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                else
                  const Icon(LucideIcons.wifi,
                      color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Text(
                  _nfcTapping
                      ? 'Ready: Tap Tapat Card Now...'
                      : (_retrySecondsLeft > 0
                          ? 'Failed — Re-scanning in ${_retrySecondsLeft}s (Tap to retry now)'
                          : 'Tap Tapat Card to Sign In'),
                  style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Simulate NFC tap for testing without physical card
        Center(
          child: TextButton(
            onPressed: () => _handleNFCTapLogin(simulate: true),
            child: Text(
              'Simulate Card Tap (Demo Mode)',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
          ),
        ),

        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => _switchView(AuthView.signup),
            child: RichText(
              text: TextSpan(
                text: 'Don\'t have an account? ',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                children: const [
                  TextSpan(
                    text: 'Create One',
                    style: TextStyle(
                        color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Signup View ────────────────────────────────────────────────────────────

  Widget _buildSignupView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      children: [
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => _switchView(AuthView.welcome),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.arrowLeft,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Create Account',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text('Step 1 of 2: Profile & 6-Digit PIN',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 24),

        _buildTextField(
          controller: _nameController,
          icon: LucideIcons.user,
          hint: 'Full Name (e.g. Richard)',
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _emailController,
          icon: LucideIcons.mail,
          hint: 'Email address',
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _phoneController,
          icon: LucideIcons.phone,
          hint: 'Mobile Number (+63 9XX XXX XXXX)',
          isNumber: true,
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _pinController,
          icon: LucideIcons.lock,
          hint: '6-Digit Card PIN',
          isPassword: true,
          isNumber: true,
          maxLength: 6,
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _confirmPinController,
          icon: LucideIcons.lock,
          hint: 'Confirm 6-Digit Card PIN',
          isPassword: true,
          isNumber: true,
          maxLength: 6,
        ),
        const SizedBox(height: 24),

        GlassButton(
          onPressed: _handleSignupContinue,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Continue to Tapat Card',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              SizedBox(width: 8),
              Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Center(
          child: GestureDetector(
            onTap: () => _switchView(AuthView.login),
            child: RichText(
              text: TextSpan(
                text: 'Already registered? ',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                children: const [
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                        color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Register Tapat Card View ───────────────────────────────────────────────

  Widget _buildRegisterCardView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => _switchView(AuthView.signup),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.arrowLeft,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Bind Tapat Card',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Step 2 of 2: Hold your JCOP J3R150 smart card to the back of your phone',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const Spacer(),

          // Animated NFC Target
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180 * _pulseAnim.value,
                    height: 180 * _pulseAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0891B2)
                          .withValues(alpha: 0.12 / _pulseAnim.value),
                    ),
                  ),
                  Container(
                    width: 130 * _pulseAnim.value,
                    height: 130 * _pulseAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0369A1)
                          .withValues(alpha: 0.2 / _pulseAnim.value),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _cardStep == 'success'
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : _cardStep == 'error'
                                ? [
                                    const Color(0xFF991B1B),
                                    const Color(0xFFEF4444)
                                  ]
                                : [
                                    const Color(0xFF0369A1),
                                    const Color(0xFF0891B2)
                                  ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _cardStep == 'success'
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : const Color(0xFF0891B2).withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Icon(
                      _cardStep == 'success'
                          ? LucideIcons.checkCircle
                          : (_cardStep == 'scanning'
                              ? LucideIcons.refreshCw
                              : LucideIcons.wifi),
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            _cardStep == 'success'
                ? 'Card Registered & Linked — Routing to Home...'
                : (_cardStep == 'scanning'
                    ? 'Writing Turing identity to card secure element...'
                    : (_retrySecondsLeft > 0
                        ? 'Recognition failed — Auto re-scanning in ${_retrySecondsLeft}s...'
                        : 'Ready to Tap Card')),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _cardStep == 'success'
                  ? const Color(0xFF34D399)
                  : (_cardStep == 'error'
                      ? const Color(0xFFF87171)
                      : Colors.white),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Single-tap Turing Composition binding · Automatically routes to Home upon success.',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            textAlign: TextAlign.center,
          ),
          const Spacer(),

          // Physical card scan button
          GlassButton(
            onPressed: _cardStep == 'scanning' || _cardStep == 'success'
                ? null
                : () => _handleCardRegister(simulate: false),
            child: Text(
              _cardStep == 'scanning'
                  ? 'Scanning Card...'
                  : (_retrySecondsLeft > 0
                      ? 'Re-scanning in ${_retrySecondsLeft}s (Tap to Scan Now)'
                      : 'Scan Physical Tapat Card'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),

          // Simulation button for testing on PC/emulator
          GestureDetector(
            onTap: _cardStep == 'scanning' || _cardStep == 'success'
                ? null
                : () => _handleCardRegister(simulate: true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Center(
                child: Text(
                  'Simulate Card Tap (Testing Mode)',
                  style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: switch (_view) {
              AuthView.welcome => _buildWelcomeView(),
              AuthView.login => _buildLoginView(),
              AuthView.signup => _buildSignupView(),
              AuthView.registerCard => _buildRegisterCardView(),
            },
          ),
        ],
      ),
    );
  }
}
