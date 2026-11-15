import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../services/account_backend_service.dart';
import '../services/nfc_service.dart';
import '../ui/card_face.dart' as ui_card;
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';
import '../widgets/account_backend_settings_sheet.dart';
import 'camera_capture_overlay.dart';
import 'face_liveness_screen.dart';

enum AuthView { landing, login, signup, registerCard }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  AuthView _view = AuthView.landing;
  int _landingPage = 0;
  int _signupStep = 1; // 1 = Details & PIN, 2 = ID & Face, 3 = Bind Card

  bool _isLoading = false;
  bool _nfcTapping = false;
  bool _nfcCompleted = false;
  bool _isNavigating = false;
  bool _pinStep = false;
  String _cardStep = 'idle'; // idle | scanning | success | error

  // Real KYC Step 2 state
  String? _capturedIdPath;
  bool _faceVerified = false;

  int _retrySecondsLeft = 0;
  Timer? _retryTimer;
  String? _nfcErrorNote;

  List<AccountSummary> _savedAccounts = const [];
  AccountManagementConfig _accountConfig = const AccountManagementConfig();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  late final AnimationController _pulseController;
  late final AnimationController _heroFloatController;

  bool get _wantsHeroFloat => _view == AuthView.landing && _landingPage < 2;
  bool get _wantsPulse =>
      (_view == AuthView.landing && _landingPage == 1) ||
      (_view == AuthView.login && _nfcTapping) ||
      (_view == AuthView.registerCard && _cardStep == 'scanning');

  void _syncAnimations() {
    if (!mounted) return;
    if (_wantsHeroFloat) {
      if (!_heroFloatController.isAnimating) {
        _heroFloatController.repeat(reverse: true);
      }
    } else if (_heroFloatController.isAnimating) {
      _heroFloatController.stop();
    }
    if (_wantsPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _heroFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _syncAnimations();
    _initializeAuthState();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    NfcService.stopSession();
    _pulseController.dispose();
    _heroFloatController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
    await _refreshAccountsAndConfig();
    final lastEmail = await AccountBackendService.getLastSignedInEmail();
    final active = await AccountBackendService.getActiveSessionAccount();
    if (!mounted) return;
    final email = lastEmail.isNotEmpty ? lastEmail : (active?.email ?? '');
    if (email.isNotEmpty) {
      _emailController.text = email;
    }
    // Returning users always land directly on Sign In when reopened
    if (_savedAccounts.isNotEmpty || email.isNotEmpty) {
      _switchView(AuthView.login);
    }
  }

  void _switchView(AuthView view, {int? resetSignupStep}) {
    _retryTimer?.cancel();
    NfcService.stopSession();
    setState(() {
      _view = view;
      if (resetSignupStep != null) _signupStep = resetSignupStep;
      _cardStep = 'idle';
      _nfcTapping = false;
      _retrySecondsLeft = 0;
      _nfcErrorNote = null;
      _pinStep = false;
    });

    if (view == AuthView.login && !_nfcCompleted && !_isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _view == AuthView.login &&
            !_nfcTapping &&
            !_nfcCompleted &&
            !_isNavigating) {
          _handleNFCTapLogin(userInitiated: false);
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
    showToast(
      context,
      msg,
      isError: isError,
      duration: Duration(milliseconds: isError ? 3400 : 2200),
    );
  }

  Future<void> _openBackendSettings() async {
    _pauseBackgroundNfcForManualTyping();
    await AccountBackendSettingsSheet.show(context);
    await _refreshAccountsAndConfig();
  }

  // ── Email + PIN Login ─────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (_isNavigating || _isLoading) return;
    final emailInput = _emailController.text.trim();
    final pinInput = _pinController.text.trim();

    if (emailInput.isEmpty) {
      _showSnack('Please enter your registered email address.', isError: true);
      return;
    }
    if (_accountConfig.requirePinOnEmailLogin &&
        pinInput.length != 6) {
      _showSnack(
        'Please enter your 6-digit PIN.',
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

  // ── NFC Tap Login ─────────────────────────────────────────────────────────

  Future<void> _handleNFCTapLogin({bool userInitiated = true}) async {
    if (_nfcTapping || _nfcCompleted || _isNavigating) return;
    _retryTimer?.cancel();
    setState(() {
      _nfcTapping = true;
      _retrySecondsLeft = 0;
      _nfcErrorNote = null;
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
          final errMsg = authRes.error ?? 'Card is not linked to an account.';
          setState(() {
            _nfcTapping = false;
            _nfcErrorNote = errMsg;
          });
          _showSnack('$errMsg Re-scanning in 5s...', isError: true);
          _start5SecRetryTimer(() {
            if (mounted && _view == AuthView.login && !_nfcCompleted) {
              _handleNFCTapLogin(userInitiated: false);
            }
          });
          return;
        }

        _nfcCompleted = true;
        setState(() {
          _nfcTapping = false;
          _nfcErrorNote = null;
        });

        await ref
            .read(userProvider.notifier)
            .applyAuthenticatedAccount(authRes.account!, armed: true);
        _navigateToMain();
      } else {
        final errMsg =
            (res['error'] as String?) ?? 'NFC Card recognition failed.';
        final lower = errMsg.toLowerCase();
        final hardwareUnavailable = lower.contains('unavailable') ||
            lower.contains('disabled') ||
            lower.contains('not supported');
        setState(() {
          _nfcTapping = false;
          _nfcErrorNote = hardwareUnavailable
              ? 'NFC reader unavailable · Use Email & PIN or tap to re-check'
              : errMsg;
        });
        if (hardwareUnavailable) {
          if (userInitiated) {
            _showSnack(errMsg, isError: true);
          }
        } else {
          _showSnack('$errMsg Re-scanning in 5s...', isError: true);
          _start5SecRetryTimer(() {
            if (mounted && _view == AuthView.login && !_nfcCompleted) {
              _handleNFCTapLogin(userInitiated: false);
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errMsg = 'NFC error: $e';
      setState(() {
        _nfcTapping = false;
        _nfcErrorNote = errMsg;
      });
      _showSnack('$errMsg. Re-scanning in 5s...', isError: true);
      _start5SecRetryTimer(() {
        if (mounted && _view == AuthView.login && !_nfcCompleted) {
          _handleNFCTapLogin(userInitiated: false);
        }
      });
    }
  }

  // ── Signup Steps ──────────────────────────────────────────────────────────

  Future<void> _validateStep1AndAdvance() async {
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
    if (pin.length != 6) {
      _showSnack(
        'PIN must be exactly 6 digits.',
        isError: true,
      );
      return;
    }
    if (pin != confirm) {
      _showSnack('PINs do not match.', isError: true);
      return;
    }

    setState(() => _signupStep = 2);
  }

  Future<void> _captureValidId() async {
    final path = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCaptureOverlay(
          title: 'Capture Valid ID',
          subtitle: 'Passport, UMID, or Driver\'s License',
        ),
      ),
    );
    if (!mounted) return;
    if (path != null && path.isNotEmpty) {
      setState(() => _capturedIdPath = path);
      showToast(context, 'ID document captured');
    }
  }

  Future<void> _startFaceLiveness() async {
    final verified = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FaceLivenessScreen(),
      ),
    );
    if (!mounted) return;
    if (verified == true) {
      setState(() => _faceVerified = true);
      showToast(context, 'Face liveness confirmed');
    }
  }

  void _advanceToBindStep() {
    _switchView(AuthView.registerCard, resetSignupStep: 3);
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
        final rawErr = (res['error'] as String?) ?? 'Card recognition failed.';
        final lower = rawErr.toLowerCase();
        final hardwareUnavailable = lower.contains('unavailable') ||
            lower.contains('disabled') ||
            lower.contains('not supported');
        setState(() => _cardStep = 'error');
        if (hardwareUnavailable) {
          _showSnack(rawErr, isError: true);
        } else {
          _showSnack(
            '$rawErr Re-scanning in 5s...',
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

  // ── Shared Top Brand Header ───────────────────────────────────────────────

  Widget _buildWordmark({double size = 20}) => Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'tap'),
          const TextSpan(text: '@', style: TextStyle(color: T.teal)),
          const TextSpan(text: 'tan'),
        ]),
        style: T.text(size, w: T.w800),
      );

  // ── Stage 0: Landing Carousel (LandingScreen.tsx 1:1) ─────────────────────

  static const _landingPages = [
    (
      keyLabel: '',
      title: 'Your card is your password. Your wallet is your card.',
      desc: '',
    ),
    (
      keyLabel: 'TAP TO PAY',
      title: 'One tap. Proven twice.',
      desc:
          'Arm your card with a PIN, tap at the store, and every payment is signed by a Turing MAC in under a second.',
    ),
    (
      keyLabel: 'SECOND LAYER',
      title: 'An AI that watches your back.',
      desc: 'Every session is scored for phishing before money moves.',
    ),
  ];

  Widget _buildLandingView() {
    final page = _landingPages[_landingPage];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWordmark(size: 20),
              Row(
                children: [
                  if (_savedAccounts.isNotEmpty) ...[
                    PressScale(
                      onTap: () => _switchView(AuthView.login),
                      child: Glass(
                        kind: GlassKind.pill,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Text(
                          'Sign In (${_savedAccounts.length})',
                          style: T.text(11.5, w: T.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GlassIconBtn(
                    icon: LucideIcons.settings,
                    size: 34,
                    iconSize: 16,
                    onTap: _openBackendSettings,
                  ),
                  if (_landingPage < 2) ...[
                    const SizedBox(width: 10),
                    PressScale(
                      onTap: () => setState(() => _landingPage = 2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Text(
                          'Skip',
                          style: T.text(13, w: T.w600, color: T.white(.55)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Swipeable 3D Artwork Stage
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -250 && _landingPage < 2) {
                  setState(() => _landingPage++);
                } else if (v > 250 && _landingPage > 0) {
                  setState(() => _landingPage--);
                }
              },
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0.12, 0), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_landingPage),
                    child: _buildLandingArt(_landingPage),
                  ),
                ),
              ),
            ),
          ),

          // Copy block
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 158),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Column(
                key: ValueKey('copy$_landingPage'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (page.keyLabel.isNotEmpty) ...[
                    Text(
                      page.keyLabel,
                      style: T.mono(11, color: T.teal, ls: 2.0),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    page.title,
                    style: T.text(31, w: T.w800, height: 1.08, ls: -0.9),
                  ),
                  if (page.desc.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      page.desc,
                      style: T.text(14, color: T.white(.60), height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _landingPage;
                return GestureDetector(
                  onTap: () => setState(() => _landingPage = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? T.teal : T.white(.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_landingPage < 2)
            Btn.text(
              'Continue',
              width: double.infinity,
              onTap: () => setState(() => _landingPage++),
            )
          else
            Column(
              children: [
                Btn.text(
                  'Get Started',
                  width: double.infinity,
                  onTap: () {
                    _nameController.clear();
                    _emailController.clear();
                    _phoneController.clear();
                    _addressController.clear();
                    _pinController.clear();
                    _confirmPinController.clear();
                    _capturedIdPath = null;
                    _faceVerified = false;
                    _switchView(AuthView.signup, resetSignupStep: 1);
                  },
                ),
                const SizedBox(height: 10),
                Btn.text(
                  _savedAccounts.isNotEmpty
                      ? 'I already have an account (${_savedAccounts.length} saved)'
                      : 'I already have an account',
                  variant: BtnVariant.glass,
                  width: double.infinity,
                  onTap: () => _switchView(AuthView.login),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLandingArt(int index) {
    const heroCard = ui_card.CardData(
      id: 'hero-jcop4',
      name: 'Tapat JCOP4',
      material: 'obsidian',
      network: 'ISO 14443-4',
      num: '4532 •••• •••• 8821',
      physical: true,
    );

    if (index == 0) {
      return AnimatedBuilder(
        animation: _heroFloatController,
        builder: (_, _) {
          final t = math.sin(_heroFloatController.value * math.pi);
          final rotY = (-18 + 30 * _heroFloatController.value) * math.pi / 180;
          final rotX = (10 - 6 * t) * math.pi / 180;
          final dy = -8 * t;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 1 / 1000)
                ..rotateX(rotX)
                ..rotateY(rotY),
              child: const SizedBox(
                width: 280,
                child: ui_card.CardFace(
                  card: heroCard,
                  holder: '',
                  tiltX: 0.3,
                  tiltY: 0.0,
                ),
              ),
            ),
          );
        },
      );
    }

    if (index == 1) {
      return SizedBox(
        width: 256,
        height: 256,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var n = 0; n < 4; n++)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, _) {
                  final p = ((_pulseController.value * 3.2 - n * 0.8) / 3.2) %
                      1.0;
                  final pp = p < 0 ? p + 1 : p;
                  final eased = Curves.easeOut.transform(pp);
                  return Opacity(
                    opacity: (0.75 * (1 - eased)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.45 + 1.05 * eased,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: T.teal, width: 1.5),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Transform.translate(
              offset: const Offset(-28, 0),
              child: Transform.rotate(
                angle: -8 * math.pi / 180,
                child: Glass(
                  radius: 34,
                  width: 112,
                  height: 176,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: T.white(.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // NFC Logo behind the card
            Transform.translate(
              offset: const Offset(-10, -14),
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.teal,
                ),
                child: const Icon(LucideIcons.nfc, color: Colors.white, size: 26),
              ),
            ),
            // Tapatan card (smaller and placed in front of the NFC logo)
            AnimatedBuilder(
              animation: _heroFloatController,
              builder: (_, _) {
                final t = (_heroFloatController.value - 0.5).abs() * 2;
                return Transform.translate(
                  offset: Offset(18 + 12 * (1 - t), 16 - 8 * t),
                  child: Transform.rotate(
                    angle: 10 * math.pi / 180,
                    child: const SizedBox(
                      width: 118,
                      child: ui_card.CardFace(
                        card: heroCard,
                        holder: '',
                        small: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Slide 2: CNN-LSTM Threat Engine
    const bars = [0.40, 0.62, 0.50, 0.80, 0.66, 0.92, 0.74, 0.96];
    return SizedBox(
      width: 280,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Glass(
            radius: 36,
            width: 264,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck,
                        size: 16, color: T.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CNN-LSTM THREAT ENGINE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.text(10.5, w: T.w700, color: T.teal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '94.7'),
                    TextSpan(
                      text: '%',
                      style: T.text(24, w: T.w800, color: T.teal),
                    ),
                  ]),
                  style: T.text(44, w: T.w800, height: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  'detection accuracy · AUC-ROC 96.3%',
                  style: T.text(11, color: T.white(.55)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < bars.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: bars[i]),
                              duration: Duration(milliseconds: 450 + i * 60),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Container(
                                height: 40 * v,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: T.teal,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared Auth Chrome Header ─────────────────────────────────────────────

  Widget _buildAuthTopChrome({required bool isSignIn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassIconBtn(
              icon: LucideIcons.chevronLeft,
              size: 40,
              iconSize: 20,
              onTap: () => _switchView(AuthView.landing),
            ),
            PressScale(
              onTap: _openBackendSettings,
              child: Glass(
                kind: GlassKind.pill,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.settings,
                        color: T.teal, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Account Rules',
                      style: T.text(11.5, w: T.w600, color: T.white(.85)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Glass(
                radius: 16,
                width: 48,
                height: 48,
                child: Icon(LucideIcons.shieldCheck,
                    color: T.teal, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWordmark(size: 24),
                  Text(
                    'JCOP4 Turing-Composed NFC Wallet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.text(11, color: T.white(.50)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          isSignIn ? 'Welcome back.' : 'Create your wallet.',
          style: T.h1,
        ),
        const SizedBox(height: 4),
        Text(
          isSignIn
              ? 'Tap your JCOP4 card or use email and PIN.'
              : 'Three quick steps to bind your hardware key.',
          style: T.text(13, color: T.white(.55)),
        ),
        const SizedBox(height: 18),
        // Segmented Sign In / Create Account switcher
        Glass(
          kind: GlassKind.pill,
          radius: 18,
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _modeTab('Sign In', isSignIn, () => _switchView(AuthView.login)),
              _modeTab(
                'Create Account / KYC',
                !isSignIn,
                () => _switchView(AuthView.signup, resetSignupStep: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? T.white(.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(color: T.white(.30), width: 0.5)
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: T.text(
                12.5,
                w: T.w700,
                color: active ? Colors.white : T.white(.55),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Login View (AuthScreen.tsx 'in' 1:1) ──────────────────────────────────

  Widget _buildLoginView() {
    if (_pinStep) return _buildPinStep();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        _buildAuthTopChrome(isSignIn: true),

        // Hero NFC Tap Card
        PressScale(
          scale: 0.98,
          onTap: () => _handleNFCTapLogin(userInitiated: true),
          child: Glass(
            kind: GlassKind.tint,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_nfcTapping)
                        for (var i = 0; i < 3; i++)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, _) {
                              final p = ((_pulseController.value * 2.4 -
                                          i * 0.8) /
                                      2.4) %
                                  1.0;
                              final pp = p < 0 ? p + 1 : p;
                              return Opacity(
                                opacity: (0.8 * (1 - pp)).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.55 + 0.95 * pp,
                                  child: Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: T.teal, width: 1.5),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: T.teal,
                        ),
                        child: _nfcTapping
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.nfc,
                                color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _nfcTapping
                      ? 'Hold Bound Tapat Card Now...'
                      : (_retrySecondsLeft > 0
                          ? 'Re-scanning in ${_retrySecondsLeft}s (Tap to Retry)'
                          : 'Tap to sign in'),
                  style: T.text(16, w: T.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  _nfcErrorNote ?? 'One tap · hardware-verified',
                  style: T.text(
                    11.5,
                    color: _nfcErrorNote != null ? T.amber300 : T.white(.55),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Saved Accounts Chips
        if (_savedAccounts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
            child: Text(
              'SAVED ACCOUNTS ON DEVICE',
              style: T.mono(10.5, color: T.white(.45), ls: 1.1),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedAccounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final acc = _savedAccounts[index];
                final isSelected = AccountBackendService.normalizeEmail(
                        _emailController.text) ==
                    acc.email;
                final initials = acc.name
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase())
                    .take(2)
                    .join();
                return PressScale(
                  onTap: () {
                    _pauseBackgroundNfcForManualTyping();
                    setState(() {
                      _emailController.text = acc.email;
                      _pinController.clear();
                      _pinStep = true;
                    });
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: isSelected ? T.surfaceTint : T.surfacePill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? T.teal : T.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: T.teal,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isEmpty ? 'U' : initials,
                              style: T.text(11, w: T.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.text(12, w: T.w600),
                                ),
                                Text(
                                  '${acc.email} · ${acc.transactionCount} tx',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.text(10, color: T.white(.45)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 18),
        Field(
          label: 'Email address',
          controller: _emailController,
          hint: 'you@email.com',
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            _pauseBackgroundNfcForManualTyping();
            setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Btn.text(
          'Continue',
          width: double.infinity,
          disabled: _emailController.text.trim().isEmpty,
          onTap: () {
            _pauseBackgroundNfcForManualTyping();
            setState(() {
              _pinController.clear();
              _pinStep = true;
            });
          },
        ),
        const SizedBox(height: 14),
        Center(
          child: LinkText(
            'New here? Create an encrypted JCOP4 account',
            onTap: () {
              _nameController.clear();
              _emailController.clear();
              _phoneController.clear();
              _addressController.clear();
              _pinController.clear();
              _confirmPinController.clear();
              _switchView(AuthView.signup, resetSignupStep: 1);
            },
          ),
        ),
      ],
    );
  }

  // ── PIN Step (6 digits, auto-submits on the 6th digit) ────────────────────

  bool _pinSubmitting = false;

  Future<void> _onPinChanged(String v) async {
    if (_pinSubmitting || _isLoading || _isNavigating) return;
    setState(() => _pinController.text = v);
    if (v.length != 6) return;
    _pinSubmitting = true;
    try {
      await _handleLogin();
    } finally {
      _pinSubmitting = false;
      if (mounted && !_isNavigating) {
        setState(() => _pinController.clear());
      }
    }
  }

  Widget _buildPinStep() {
    final email = AccountBackendService.normalizeEmail(_emailController.text);
    String who = email;
    for (final a in _savedAccounts) {
      if (a.email == email && a.name.trim().isNotEmpty) who = a.name;
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GlassIconBtn(
            icon: LucideIcons.chevronLeft,
            size: 40,
            iconSize: 20,
            onTap: () => setState(() {
              _pinStep = false;
              _pinController.clear();
            }),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: T.teal,
            ),
            child: const Icon(LucideIcons.lock, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text('Enter your PIN', style: T.h1)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.text(13, color: T.white(.55)),
          ),
        ),
        const SizedBox(height: 20),
        PinDots(n: _pinController.text.length, max: 6),
        SizedBox(
          height: 24,
          child: Center(
            child: Text(
              _isLoading ? 'Signing in...' : '',
              style: T.text(12, color: T.white(.55)),
            ),
          ),
        ),
        Numpad(
          value: _pinController.text,
          max: 6,
          onChanged: _onPinChanged,
        ),
      ],
    );
  }

  // ── Signup & KYC View (AuthScreen.tsx 'up' 1:1) ───────────────────────────

  Widget _buildSignupStepBar() {
    const stepLabels = ['Details & PIN', 'ID & Face', 'Bind Card'];
    final current = _view == AuthView.registerCard ? 3 : _signupStep;
    return Row(
      children: List.generate(3, (i) {
        final n = i + 1;
        final done = n <= current;
        final isCurr = n == current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? T.teal : T.white(.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepLabels[i],
                  style: T.text(
                    10,
                    w: T.w600,
                    color: isCurr ? Colors.white : T.white(.35),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSignupView() {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    final pinsMismatch = confirm.isNotEmpty && pin != confirm;
    final step1Ready = _nameController.text.trim().length >= 2 &&
        _emailController.text.trim().isNotEmpty &&
        pin.length == 6 &&
        pin == confirm;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        _buildAuthTopChrome(isSignIn: false),
        _buildSignupStepBar(),
        const SizedBox(height: 18),

        if (_signupStep == 1) ...[
          Field(
            label: 'Full name',
            controller: _nameController,
            hint: 'e.g. Maria Clara Reyes',
            onChanged: (_) => setState(() {}),
          ),
          Field(
            label: 'Email',
            controller: _emailController,
            hint: 'you@email.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),
          Field(
            label: 'Phone',
            controller: _phoneController,
            hint: '+63 9XX XXX XXXX',
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          Field(
            label: 'Home address',
            controller: _addressController,
            hint: 'City, Province',
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Expanded(
                child: Field(
                  label: 'Create 6-digit PIN',
                  mono: true,
                  controller: _pinController,
                  hint: '••••••',
                  obscure: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Field(
                  label: 'Confirm PIN',
                  mono: true,
                  controller: _confirmPinController,
                  hint: '••••••',
                  obscure: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (pinsMismatch)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                'PINs don\'t match',
                style: T.text(11.5, color: T.red400),
              ),
            ),
          Btn(
            width: double.infinity,
            disabled: !step1Ready,
            onTap: _validateStep1AndAdvance,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Next: Biometric KYC'),
                SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 17),
              ],
            ),
          ),
        ] else ...[
          // Step 2: Real Camera ID Capture + ML Kit Face Liveness
          PressScale(
            onTap: _captureValidId,
            child: Glass(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: T.op(
                          _capturedIdPath != null ? T.emerald400 : T.teal,
                          .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _capturedIdPath != null
                          ? LucideIcons.check
                          : LucideIcons.camera,
                      color:
                          _capturedIdPath != null ? T.emerald300 : T.teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Capture valid ID photo',
                            style: T.text(14, w: T.w700)),
                        const SizedBox(height: 2),
                        Text(
                          _capturedIdPath != null
                              ? 'ID document captured ✓'
                              : 'Passport, UMID or driver\'s license',
                          style: T.text(11, color: T.white(.45)),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: T.white(.35)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PressScale(
            onTap: _startFaceLiveness,
            child: Glass(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: T.op(T.emerald400, .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _faceVerified
                          ? LucideIcons.check
                          : LucideIcons.scanFace,
                      color: T.emerald300,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start live face verification',
                            style: T.text(14, w: T.w700)),
                        const SizedBox(height: 2),
                        Text(
                          _faceVerified
                              ? 'ML Kit liveness confirmed ✓'
                              : 'Center → Blink → Smile',
                          style: T.text(11, color: T.white(.45)),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: T.white(.35)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Btn.text(
                '‹ Back',
                variant: BtnVariant.glass,
                onTap: () => setState(() => _signupStep = 1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Btn(
                  disabled: _capturedIdPath == null || !_faceVerified,
                  onTap: _advanceToBindStep,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Continue to Bind Card'),
                      SizedBox(width: 6),
                      Icon(LucideIcons.chevronRight, size: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_capturedIdPath == null || !_faceVerified) ...[
            const SizedBox(height: 14),
            Center(
              child: LinkText(
                'Device without camera? Complete Step 2 for emulator test',
                onTap: () => setState(() {
                  _capturedIdPath ??= 'emulator_verified_id';
                  _faceVerified = true;
                }),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Register / Bind JCOP4 Card View (Step 3 of 3) ─────────────────────────

  Widget _buildRegisterCardView() {
    final holderName = _nameController.text.trim();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        _buildAuthTopChrome(isSignIn: false),
        _buildSignupStepBar(),
        const SizedBox(height: 18),
        Glass(
          kind: GlassKind.tint,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_cardStep == 'scanning')
                      for (var i = 0; i < 3; i++)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, _) {
                            final p = ((_pulseController.value * 2.4 -
                                        i * 0.8) /
                                    2.4) %
                                1.0;
                            final pp = p < 0 ? p + 1 : p;
                            return Opacity(
                              opacity: (0.8 * (1 - pp)).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.55 + 0.95 * pp,
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: T.teal, width: 1.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cardStep == 'success'
                            ? T.emerald
                            : _cardStep == 'error'
                                ? T.red500
                                : T.teal,
                      ),
                      child: Icon(
                        _cardStep == 'success'
                            ? LucideIcons.checkCircle
                            : (_cardStep == 'error'
                                ? LucideIcons.shieldAlert
                                : LucideIcons.nfc),
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _cardStep == 'success'
                    ? 'Account Saved & Card Bound'
                    : _cardStep == 'scanning'
                        ? 'Hold JCOP4 Card Steady...'
                        : 'Bind your JCOP4 card',
                style: T.text(17, w: T.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _cardStep == 'success'
                    ? 'Turing Composition identity written for $holderName. Entering tap@tan...'
                    : _retrySecondsLeft > 0
                        ? 'Recognition failed — auto re-scanning in ${_retrySecondsLeft}s...'
                        : 'Writes $holderName\'s encrypted identity to AID F07461706174616E0101 and binds the hardware UID to this account.',
                style: T.text(
                  12,
                  color: _cardStep == 'error' ? T.red300 : T.white(.55),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Btn.text(
                _cardStep == 'scanning'
                    ? 'Scanning JCOP4 Card...'
                    : _retrySecondsLeft > 0
                        ? 'Tap to Retry Now (${_retrySecondsLeft}s)'
                        : 'Tap & Bind JCOP4 Smart Card',
                width: double.infinity,
                disabled: _cardStep == 'scanning' || _cardStep == 'success',
                onTap: () => _handleCardRegister(simulate: false),
              ),
              const SizedBox(height: 10),
              Btn.text(
                'Create Account Without Card (Bind Later)',
                variant: BtnVariant.glass,
                width: double.infinity,
                disabled: _cardStep == 'scanning' || _cardStep == 'success',
                onTap: () => _handleCardRegister(simulate: true),
              ),
              const SizedBox(height: 12),
              LinkText(
                '‹ Back to KYC Step 2',
                onTap: () => _switchView(AuthView.signup, resetSignupStep: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_heroFloatController.isAnimating != _wantsHeroFloat ||
        _pulseController.isAnimating != _wantsPulse) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnimations());
    }
    return Scaffold(
      backgroundColor: T.bg,
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey(_view),
              child: switch (_view) {
                AuthView.landing => _buildLandingView(),
                AuthView.login => _buildLoginView(),
                AuthView.signup => _buildSignupView(),
                AuthView.registerCard => _buildRegisterCardView(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
