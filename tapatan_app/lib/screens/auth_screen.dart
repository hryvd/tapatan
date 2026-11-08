import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../services/account_backend_service.dart';
import '../services/nfc_service.dart';
import '../utils/lucide_icons.dart';
import '../widgets/account_backend_settings_sheet.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_container.dart';

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

  List<AccountSummary> _savedAccounts = const [];
  AccountManagementConfig _accountConfig = const AccountManagementConfig();

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
    _initializeAuthState();
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

  Future<void> _refreshAccountsAndConfig() async {
    final cfg = await AccountBackendService.getConfig();
    final saved = await AccountBackendService.listSavedAccounts();
    if (!mounted) return;
    setState(() {
      _accountConfig = cfg;
      _savedAccounts = saved;
    });
  }

  Future<void> _initializeAuthState() async {
    await AccountBackendService.initialize();
    final active = await AccountBackendService.getActiveSessionAccount();
    if (active != null) {
      await ref
          .read(userProvider.notifier)
          .applyAuthenticatedAccount(active, armed: false);
      if (mounted) {
        _navigateToMain();
      }
      return;
    }

    await _refreshAccountsAndConfig();
    final lastEmail = await AccountBackendService.getLastSignedInEmail();
    if (!mounted) return;
    if (lastEmail.isNotEmpty) {
      _emailController.text = lastEmail;
    }
    if (_savedAccounts.isNotEmpty) {
      _switchView(AuthView.login);
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
          _handleNFCTapLogin();
        }
      });
    }
  }

  void _pauseBackgroundNfcForManualTyping() {
    if (_nfcTapping || _retrySecondsLeft > 0) {
      _retryTimer?.cancel();
      NfcService.stopSession();
      setState(() {
        _nfcTapping = false;
        _retrySecondsLeft = 0;
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

  Future<void> _openBackendSettings() async {
    _pauseBackgroundNfcForManualTyping();
    await AccountBackendSettingsSheet.show(context);
    await _refreshAccountsAndConfig();
  }

  // ── Email + PIN Login (Restores Stored Account & Full History) ─────────────

  Future<void> _handleLogin() async {
    if (_isNavigating || _isLoading) return;
    final emailInput = _emailController.text.trim();
    final pinInput = _pinController.text.trim();

    if (emailInput.isEmpty) {
      _showSnack('Please enter your registered email address.', isError: true);
      return;
    }
    if (_accountConfig.requirePinOnEmailLogin &&
        pinInput.length < _accountConfig.pinMinLength) {
      _showSnack(
        'Please enter your ${_accountConfig.pinMinLength} to ${_accountConfig.pinMaxLength}-digit PIN.',
        isError: true,
      );
      return;
    }

    _retryTimer?.cancel();
    await NfcService.stopSession();
    setState(() {
      _nfcTapping = false;
      _retrySecondsLeft = 0;
      _isLoading = true;
    });

    final authRes = await AccountBackendService.loginWithEmailPin(
      email: emailInput,
      pin: pinInput,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!authRes.success || authRes.account == null) {
      _showSnack(
        authRes.error ?? 'Unable to sign in with those credentials.',
        isError: true,
      );
      return;
    }

    _nfcCompleted = true;
    await ref
        .read(userProvider.notifier)
        .applyAuthenticatedAccount(authRes.account!, armed: false);
    _navigateToMain();
  }

  // ── NFC Tap Login (Single-Shot Action + 5s Auto Rescan on Failure) ─────────

  Future<void> _handleNFCTapLogin() async {
    // Only one NFC action is allowed; ignore any duplicate scan if already tapping or completed
    if (_nfcTapping || _nfcCompleted || _isNavigating) return;
    _retryTimer?.cancel();
    setState(() {
      _nfcTapping = true;
      _retrySecondsLeft = 0;
    });

    try {
      final res = await NfcService.readCardIdentity();
      if (!mounted ||
          _view != AuthView.login ||
          _isNavigating ||
          _nfcCompleted) {
        return;
      }

      if (res['success'] == true) {
        final uid = (res['uid'] as String?) ?? '';
        final cardId = (res['cardId'] as String?) ?? '';
        final owner = (res['owner'] as String?) ?? '';
        final cardName = (res['name'] as String?) ?? '';

        final authRes = await AccountBackendService.loginWithCard(
          cardId: cardId,
          uid: uid,
          ownerEmail: owner,
          cardName: cardName,
        );

        if (!mounted || _view != AuthView.login || _isNavigating) return;

        if (!authRes.success || authRes.account == null) {
          setState(() => _nfcTapping = false);
          _showSnack(
            '${authRes.error ?? 'Card is not linked to an account.'} Re-scanning in 5s...',
            isError: true,
          );
          _start5SecRetryTimer(() {
            if (mounted && _view == AuthView.login && !_nfcCompleted) {
              _handleNFCTapLogin();
            }
          });
          return;
        }

        // Lock single-shot completion so any second NFC read is ignored
        _nfcCompleted = true;
        setState(() => _nfcTapping = false);

        await ref
            .read(userProvider.notifier)
            .applyAuthenticatedAccount(authRes.account!, armed: true);
        _navigateToMain();
      } else {
        setState(() => _nfcTapping = false);
        _showSnack(
          '${(res['error'] as String?) ?? 'NFC Card recognition failed.'} Re-scanning in 5s...',
          isError: true,
        );
        _start5SecRetryTimer(() {
          if (mounted && _view == AuthView.login && !_nfcCompleted) {
            _handleNFCTapLogin();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _nfcTapping = false);
      _showSnack('NFC error: $e. Re-scanning in 5s...', isError: true);
      _start5SecRetryTimer(() {
        if (mounted && _view == AuthView.login && !_nfcCompleted) {
          _handleNFCTapLogin();
        }
      });
    }
  }

  // ── Signup Steps ───────────────────────────────────────────────────────────

  Future<void> _handleSignupContinue() async {
    final name = _nameController.text.trim();
    final email = AccountBackendService.normalizeEmail(_emailController.text);
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (name.length < 2) {
      _showSnack('Please enter your full name.', isError: true);
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showSnack('Please enter a valid email address.', isError: true);
      return;
    }
    if (_savedAccounts.any((a) => a.email == email)) {
      _showSnack(
        'An account with "$email" already exists. Please Sign In instead.',
        isError: true,
      );
      return;
    }
    if (pin.length < _accountConfig.pinMinLength ||
        pin.length > _accountConfig.pinMaxLength) {
      _showSnack(
        'PIN must be ${_accountConfig.pinMinLength} to ${_accountConfig.pinMaxLength} digits.',
        isError: true,
      );
      return;
    }
    if (pin != confirm) {
      _showSnack('PINs do not match.', isError: true);
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
      final name = _nameController.text.trim();
      final email = AccountBackendService.normalizeEmail(_emailController.text);
      final phone = _phoneController.text.trim();
      final pin = _pinController.text.trim();
      final generatedCardId = NfcService.generateCardId();

      if (simulate) {
        await NfcService.stopSession();
        final regRes = await AccountBackendService.registerAccount(
          name: name,
          email: email,
          phone: phone,
          pin: pin,
          cardId: generatedCardId,
          jcopCardUid: '',
        );

        if (!mounted) return;
        if (!regRes.success || regRes.account == null) {
          setState(() => _cardStep = 'error');
          _showSnack(
            regRes.error ?? 'Could not create account.',
            isError: true,
          );
          return;
        }

        _nfcCompleted = true;
        await ref
            .read(userProvider.notifier)
            .applyAuthenticatedAccount(regRes.account!, armed: false);
        setState(() => _cardStep = 'success');
        await Future.delayed(const Duration(milliseconds: 350));
        _navigateToMain();
        return;
      }

      final res = await NfcService.writeCardIdentity(
        generatedCardId,
        email,
        name: name,
      );

      if (!mounted ||
          _view != AuthView.registerCard ||
          _isNavigating ||
          _nfcCompleted) {
        return;
      }

      if (res['success'] == true) {
        final uid = (res['uid'] as String?) ?? '';
        final regRes = await AccountBackendService.registerAccount(
          name: name,
          email: email,
          phone: phone,
          pin: pin,
          cardId: generatedCardId,
          jcopCardUid: uid,
        );

        if (!mounted) return;
        if (!regRes.success || regRes.account == null) {
          setState(() => _cardStep = 'error');
          _showSnack(
            regRes.error ?? 'Account registration failed.',
            isError: true,
          );
          return;
        }

        _nfcCompleted = true;
        setState(() => _cardStep = 'success');
        await ref
            .read(userProvider.notifier)
            .applyAuthenticatedAccount(regRes.account!, armed: true);
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

  Widget _buildSettingsIconButton() {
    return GestureDetector(
      onTap: _openBackendSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.settings, color: Color(0xFF38BDF8), size: 15),
            const SizedBox(width: 6),
            Text(
              'Account Rules',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    VoidCallback? onChangedExtra,
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
              onChanged: (_) {
                onChangedExtra?.call();
                setState(() {});
              },
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
          Align(
            alignment: Alignment.centerRight,
            child: _buildSettingsIconButton(),
          ),
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
            child:
                const Icon(LucideIcons.shield, color: Colors.white, size: 42),
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
            child: Text(
                _savedAccounts.isNotEmpty
                    ? 'Sign In (${_savedAccounts.length} Saved Account${_savedAccounts.length > 1 ? 's' : ''})'
                    : 'Sign In',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 12),

          // Create Account button
          GlassButton(
            gradientColors: const [Color(0xFF0C1E35), Color(0xFF0A1628)],
            onPressed: () {
              _nameController.clear();
              _emailController.clear();
              _phoneController.clear();
              _pinController.clear();
              _confirmPinController.clear();
              _switchView(AuthView.signup);
            },
            child: const Text('Create Account',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Login View ─────────────────────────────────────────────────────────────

  Widget _buildSavedAccountChips() {
    if (_savedAccounts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAVED ACCOUNTS ON DEVICE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _savedAccounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final acc = _savedAccounts[index];
              final isSelected = AccountBackendService.normalizeEmail(
                      _emailController.text) ==
                  acc.email;
              final initial =
                  acc.name.isNotEmpty ? acc.name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: () {
                  _pauseBackgroundNfcForManualTyping();
                  setState(() {
                    _emailController.text = acc.email;
                    _pinController.clear();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0891B2).withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF0369A1),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            acc.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${acc.email} · ${acc.transactionCount} tx',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildLoginView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
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
            _buildSettingsIconButton(),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Welcome Back',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(
            'Sign in with your registered email & PIN or tap your bound Tapat Card',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 22),

        // Quick-select saved accounts (persisted across sign-outs)
        _buildSavedAccountChips(),

        // Email field
        _buildTextField(
          controller: _emailController,
          icon: LucideIcons.mail,
          hint: 'Registered email address',
          onChangedExtra: _pauseBackgroundNfcForManualTyping,
        ),
        const SizedBox(height: 14),

        // PIN field
        _buildTextField(
          controller: _pinController,
          icon: LucideIcons.lock,
          hint:
              '${_accountConfig.pinMinLength}-${_accountConfig.pinMaxLength} Digit Account PIN',
          isPassword: true,
          isNumber: true,
          maxLength: _accountConfig.pinMaxLength,
          onChangedExtra: _pauseBackgroundNfcForManualTyping,
          suffix: GestureDetector(
            onTap: () => setState(() => _showPass = !_showPass),
            child: Icon(
              _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Sign In Button
        GlassButton(
          onPressed: _handleLogin,
          isLoading: _isLoading,
          child: const Text('Sign In to Account',
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
          onTap: _handleNFCTapLogin,
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
                Flexible(
                  child: Text(
                    _nfcTapping
                        ? 'Ready: Tap Bound Tapat Card Now...'
                        : (_retrySecondsLeft > 0
                            ? 'Failed — Re-scanning in ${_retrySecondsLeft}s (Tap to retry now)'
                            : 'Tap Bound Tapat Card to Sign In'),
                    style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: () {
              _nameController.clear();
              _emailController.clear();
              _phoneController.clear();
              _pinController.clear();
              _confirmPinController.clear();
              _switchView(AuthView.signup);
            },
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
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
            _buildSettingsIconButton(),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Create Account',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(
            'Step 1 of 2: Account Profile & ${_accountConfig.pinMaxLength}-Digit PIN',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 24),

        _buildTextField(
          controller: _nameController,
          icon: LucideIcons.user,
          hint: 'Full Name',
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _emailController,
          icon: LucideIcons.mail,
          hint: 'Email address (e.g. name@email.com)',
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
          hint:
              '${_accountConfig.pinMinLength}-${_accountConfig.pinMaxLength} Digit Card PIN',
          isPassword: true,
          isNumber: true,
          maxLength: _accountConfig.pinMaxLength,
        ),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _confirmPinController,
          icon: LucideIcons.lock,
          hint: 'Confirm Card PIN',
          isPassword: true,
          isNumber: true,
          maxLength: _accountConfig.pinMaxLength,
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
          const SizedBox(height: 12),
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
            'Step 2 of 2: Hold your JCOP J3R150 smart card to bind it to ${_nameController.text.trim()}',
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
                ? 'Account Saved & Card Bound — Routing to Home...'
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
            'Single-tap Turing Composition binding · Account & history persist in database.',
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

          // Complete signup without physical NFC card (bind later / emulator)
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
                  'Create Account Without Card (Bind Later)',
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
