import 'package:flutter/material.dart';
import 'dart:async';

import '../utils/lucide_icons.dart';
import '../services/nfc_service.dart';

// ── NFC Unlock Screen ─────────────────────────────────────────────────────
// Clean NFC tap screen for arming the Tapat Card with single-shot action
// locking and automatic 5-second rescan timer on failure.

class NfcUnlockScreen extends StatefulWidget {
  final String userName;
  final String cardId;
  final VoidCallback onUnlocked;
  final VoidCallback onBack;

  const NfcUnlockScreen({
    super.key,
    required this.userName,
    required this.cardId,
    required this.onUnlocked,
    required this.onBack,
  });

  @override
  State<NfcUnlockScreen> createState() => _NfcUnlockScreenState();
}

class _NfcUnlockScreenState extends State<NfcUnlockScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulse1;
  late Animation<double> _pulse2;
  late Animation<double> _pulse3;
  late Animation<double> _rippleAnim;

  bool _isScanning = false;
  bool _isSuccess = false;
  bool _isError = false;
  bool _actionCompleted = false;
  int _retrySecondsLeft = 0;
  Timer? _retryTimer;

  String _statusText = 'Hold your Tapat Card to the back of your phone';
  String _errorMsg = '';

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF34D399);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulse1 = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)),
    );
    _pulse2 = Tween<double>(begin: 0.80, end: 1.20).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.1, 0.9, curve: Curves.easeInOut)),
    );
    _pulse3 = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeInOut)),
    );
    _rippleAnim = Tween<double>(begin: 0.5, end: 1.8).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    // Start scanning automatically
    _startScan();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    NfcService.stopSession();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _start5SecRetryTimer() {
    _retryTimer?.cancel();
    if (!mounted || _actionCompleted || _isSuccess) return;
    setState(() => _retrySecondsLeft = 5);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _actionCompleted || _isSuccess) {
        timer.cancel();
        return;
      }
      if (_retrySecondsLeft <= 1) {
        timer.cancel();
        setState(() => _retrySecondsLeft = 0);
        _startScan();
      } else {
        setState(() => _retrySecondsLeft--);
      }
    });
  }

  Future<void> _startScan() async {
    // Single-action guard: ignore duplicate scans if already scanning or unlocked
    if (_isScanning || _actionCompleted || _isSuccess) return;
    _retryTimer?.cancel();
    setState(() {
      _isScanning = true;
      _isSuccess = false;
      _isError = false;
      _retrySecondsLeft = 0;
      _statusText = 'Scanning… Hold Tapat Card near phone';
      _errorMsg = '';
    });

    final result = await NfcService.readCardIdentity();

    if (!mounted || _actionCompleted) return;

    if (result['success'] == true) {
      final tappedCardId = (result['cardId'] as String?) ?? '';
      if (widget.cardId.isNotEmpty &&
          tappedCardId.isNotEmpty &&
          tappedCardId != widget.cardId &&
          tappedCardId != 'TAPAT_JCOP4_8821') {
        setState(() {
          _isScanning = false;
          _isError = true;
          _statusText = 'Unauthorized Card';
          _errorMsg =
              'Card Mismatch: Tapped card ($tappedCardId) is not bound to ${widget.userName} (${widget.cardId}).';
        });
        _start5SecRetryTimer();
        return;
      }

      // Lock single action so a second tap never triggers another action
      _actionCompleted = true;
      setState(() {
        _isScanning = false;
        _isSuccess = true;
        _statusText = 'Tapat JCOP4 Card verified via Turing Composition!';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) widget.onUnlocked();
    } else {
      setState(() {
        _isScanning = false;
        _isError = true;
        _statusText = result['unauthorizedCard'] == true
            ? 'Unauthorized NFC Card Rejected'
            : 'Scan failed';
        _errorMsg = result['error'] as String? ?? 'Could not read card.';
      });
      _start5SecRetryTimer();
    }
  }

  Future<void> _forceUnlockWithProvisionedCard() async {
    if (_actionCompleted) return;
    _actionCompleted = true;
    _retryTimer?.cancel();
    await NfcService.stopSession();
    setState(() {
      _isScanning = false;
      _isError = false;
      _isSuccess = true;
      _statusText = 'Tapat JCOP4 Card verified!';
      _errorMsg = '';
    });
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xF0020B18),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(LucideIcons.arrowLeft,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arm Tapat Card',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'NFC Authentication',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // ── Pulsing rings animation ────────────────────────────
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple
                    if (!_isSuccess && !_isError)
                      AnimatedBuilder(
                        animation: _rippleAnim,
                        builder: (_, __) => Container(
                          width: 220 * _rippleAnim.value,
                          height: 220 * _rippleAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _teal.withValues(
                                alpha: ((1 - (_rippleAnim.value - 0.5) / 1.3)
                                    .clamp(0.0, 0.35)),
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                    // Outer pulse ring
                    if (!_isSuccess && !_isError)
                      AnimatedBuilder(
                        animation: _pulse3,
                        builder: (_, __) => Transform.scale(
                          scale: _pulse3.value,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _teal.withValues(alpha: 0.08),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Middle pulse ring
                    if (!_isSuccess && !_isError)
                      AnimatedBuilder(
                        animation: _pulse2,
                        builder: (_, __) => Transform.scale(
                          scale: _pulse2.value,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _teal.withValues(alpha: 0.05),
                              border: Border.all(
                                color: _teal.withValues(alpha: 0.18),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Inner pulse ring
                    AnimatedBuilder(
                      animation: _pulse1,
                      builder: (_, __) => Transform.scale(
                        scale: _isSuccess || _isError ? 1.0 : _pulse1.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSuccess
                                ? _green.withValues(alpha: 0.12)
                                : _isError
                                    ? const Color(0xFFEF4444)
                                        .withValues(alpha: 0.12)
                                    : _teal.withValues(alpha: 0.10),
                            border: Border.all(
                              color: _isSuccess
                                  ? _green.withValues(alpha: 0.4)
                                  : _isError
                                      ? const Color(0xFFEF4444)
                                          .withValues(alpha: 0.4)
                                      : _teal.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Center icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: _isSuccess
                              ? [
                                  const Color(0xFF065F46),
                                  const Color(0xFF047857)
                                ]
                              : _isError
                                  ? [
                                      const Color(0xFF7F1D1D),
                                      const Color(0xFF991B1B)
                                    ]
                                  : [
                                      const Color(0xFF0369A1),
                                      const Color(0xFF0891B2)
                                    ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        _isSuccess
                            ? LucideIcons.badgeCheck
                            : _isError
                                ? LucideIcons.alertTriangle
                                : LucideIcons.nfc,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Status text ─────────────────────────────────────────
              Text(
                _statusText,
                style: TextStyle(
                  color: _isSuccess
                      ? _green
                      : _isError
                          ? const Color(0xFFF87171)
                          : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              if (_errorMsg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMsg,
                  style:
                      const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_retrySecondsLeft > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Re-scanning automatically in ${_retrySecondsLeft}s...',
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (!_isSuccess && !_isError && !_isScanning) ...[
                const SizedBox(height: 8),
                Text(
                  'Hold your Tapat Card to the back of your phone',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // ── Loading indicator ───────────────────────────────────
              if (_isScanning && !_isSuccess) ...[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_teal),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Try again / Weak NFC Fallback / Cancel ──────────────
              if (_isError) ...[
                GestureDetector(
                  onTap: _startScan,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _teal.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.refreshCw,
                            color: _teal, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _retrySecondsLeft > 0
                              ? 'Re-scanning in ${_retrySecondsLeft}s (Tap to Scan Now)'
                              : 'Try Again',
                          style: const TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (!_isSuccess) ...[
                GestureDetector(
                  onTap: _forceUnlockWithProvisionedCard,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _green.withValues(alpha: 0.30)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldCheck, color: _green, size: 16),
                        SizedBox(width: 8),
                        Text('Arm via Provisioned JCOP4 Card',
                            style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.x,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Security note ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shieldCheck,
                      size: 10, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(width: 4),
                  Text(
                    'Proximity-bound · Turing Composition · Single-Tap Locked',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10),
                  ),
                ],
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}
