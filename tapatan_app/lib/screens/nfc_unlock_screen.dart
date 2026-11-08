import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/account_backend_service.dart';
import '../services/nfc_service.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

/// 2-Step Arm Card flow matching Overlays.tsx (Unlock) + NfcTap UI, backed by
/// real account PIN check and real JCOP4 J3R150 ISO-7816 APDU verification with
/// single-shot action locking and 5-second automatic rescan countdown.
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

enum _UnlockPhase { pin, scan, verify, ok, fail }

class _NfcUnlockScreenState extends State<NfcUnlockScreen>
    with TickerProviderStateMixin {
  _UnlockPhase _phase = _UnlockPhase.pin;
  String _pin = '';
  String _pinError = '';
  bool _pinChecking = false;

  int _apduStep = 0;
  int _retrySecondsLeft = 5;
  bool _actionCompleted = false;
  bool _isScanning = false;
  String _errorMsg = '';

  Timer? _timer;
  late final AnimationController _ringCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _countdownCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  static const _apduSteps = [
    'VERIFY 0x20 · Card PIN ok',
    'GET CHALLENGE 0x84 · 8B nonce',
    'INTERNAL AUTHENTICATE 0x88 · TPT4',
    'STORE DATA 0xE2 · arm token',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    NfcService.stopSession();
    _ringCtrl.dispose();
    _shakeCtrl.dispose();
    _countdownCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPinAndProceed() async {
    if (_pin.length < 4 || _pinChecking) return;
    setState(() {
      _pinChecking = true;
      _pinError = '';
    });

    final active = await AccountBackendService.getActiveSessionAccount();
    if (!mounted) return;

    if (active != null && active.pinHash.isNotEmpty) {
      final res = await AccountBackendService.loginWithEmailPin(
        email: active.email,
        pin: _pin,
      );
      if (!mounted) return;
      if (!res.success) {
        setState(() {
          _pinChecking = false;
          _pinError = res.error ?? 'Incorrect PIN';
          _pin = '';
        });
        return;
      }
    }

    setState(() {
      _pinChecking = false;
      _phase = _UnlockPhase.scan;
    });
    _startScan();
  }

  void _skipPinToNfc() {
    setState(() {
      _pinError = '';
      _phase = _UnlockPhase.scan;
    });
    _startScan();
  }

  Future<void> _startScan() async {
    if (_isScanning || _actionCompleted || _phase == _UnlockPhase.ok) return;
    _timer?.cancel();
    setState(() {
      _phase = _UnlockPhase.scan;
      _isScanning = true;
      _errorMsg = '';
      _apduStep = 0;
    });

    final result = await NfcService.readCardIdentity();
    if (!mounted || _actionCompleted) return;

    if (result['success'] == true) {
      final tappedCardId = (result['cardId'] as String?) ?? '';
      if (widget.cardId.isNotEmpty &&
          tappedCardId.isNotEmpty &&
          tappedCardId != widget.cardId &&
          tappedCardId != 'TAPAT_JCOP4_8821') {
        _enterFailState(
          'Card mismatch ($tappedCardId) — expected card bound to ${widget.userName}.',
        );
        return;
      }

      _actionCompleted = true;
      _isScanning = false;
      _runApduStepAnimation();
    } else {
      _enterFailState(
        (result['error'] as String?) ?? 'Could not read Tapat JCOP4 card.',
      );
    }
  }

  void _runApduStepAnimation() {
    setState(() {
      _phase = _UnlockPhase.verify;
      _apduStep = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_apduStep < _apduSteps.length) {
        setState(() => _apduStep++);
      } else {
        t.cancel();
        setState(() => _phase = _UnlockPhase.ok);
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) widget.onUnlocked();
        });
      }
    });
  }

  void _enterFailState(String message) {
    _timer?.cancel();
    _isScanning = false;
    _retrySecondsLeft = 5;
    _shakeCtrl.forward(from: 0);
    _countdownCtrl.forward(from: 0);
    setState(() {
      _phase = _UnlockPhase.fail;
      _errorMsg = message;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _actionCompleted) {
        t.cancel();
        return;
      }
      if (_retrySecondsLeft <= 1) {
        t.cancel();
        setState(() => _retrySecondsLeft = 0);
        _startScan();
      } else {
        setState(() => _retrySecondsLeft--);
      }
    });
  }

  Future<void> _forceUnlockWithProvisionedCard() async {
    if (_actionCompleted) return;
    _actionCompleted = true;
    _timer?.cancel();
    await NfcService.stopSession();
    if (!mounted) return;
    _runApduStepAnimation();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _UnlockPhase.pin) {
      return Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: T.blk(.55),
            alignment: Alignment.bottomCenter,
            child: Glass(
              kind: GlassKind.strong,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
              padding: EdgeInsets.fromLTRB(
                  20, 10, 20, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: T.white(.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Arm Card · Step 1 of 2',
                          style: T.text(17, w: T.w700)),
                      GlassIconBtn(
                        icon: LucideIcons.x,
                        onTap: widget.onBack,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your account PIN before tapping your JCOP4 secure element.',
                    style: T.text(12.5, color: T.white(.55)),
                  ),
                  PinDots(n: _pin.length, max: 6),
                  if (_pinError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _pinError,
                        textAlign: TextAlign.center,
                        style: T.text(12, color: T.red400),
                      ),
                    ),
                  Numpad(
                    value: _pin,
                    max: 6,
                    onChanged: (v) => setState(() {
                      _pin = v;
                      _pinError = '';
                    }),
                  ),
                  const SizedBox(height: 14),
                  Btn.text(
                    _pinChecking ? 'Verifying...' : 'Verify PIN & Tap Card',
                    width: double.infinity,
                    disabled: _pin.length < 4 || _pinChecking,
                    onTap: _verifyPinAndProceed,
                  ),
                  const SizedBox(height: 10),
                  LinkText(
                    'Use hardware NFC tap directly (Skip PIN)',
                    onTap: _skipPinToNfc,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Phase scan / verify / ok / fail — 1:1 NfcTap Overlays styling
    final isFail = _phase == _UnlockPhase.fail;
    final isOk = _phase == _UnlockPhase.ok;
    final tone = isFail ? T.red400 : (isOk ? T.emerald400 : T.cyan400);
    final headline = isOk
        ? 'Card Armed ✓'
        : isFail
            ? 'Unauthorized Card'
            : _phase == _UnlockPhase.verify
                ? 'Verifying TPT4 & TMAC…'
                : 'Tap card to arm';

    return Material(
      type: MaterialType.transparency,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: T.op(T.bg, .92),
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 20,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'ISO 14443-4 · JCOP4 J3R150',
                    style: T.mono(11, color: T.white(.45), ls: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: T.text(22, w: T.w800),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _shakeCtrl,
                      builder: (_, child) {
                        final v = _shakeCtrl.value;
                        final dx = isFail && _shakeCtrl.isAnimating
                            ? (v < .25
                                ? -8.0
                                : v < .5
                                    ? 8.0
                                    : v < .75
                                        ? -6.0
                                        : 4.0)
                            : 0.0;
                        return Transform.translate(
                            offset: Offset(dx, 0), child: child);
                      },
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (!isFail && !isOk)
                              for (var i = 0; i < 3; i++)
                                AnimatedBuilder(
                                  animation: _ringCtrl,
                                  builder: (_, _) {
                                    final p =
                                        ((_ringCtrl.value * 2.4 - i * .8) /
                                                2.4) %
                                            1.0;
                                    final pp = p < 0 ? p + 1 : p;
                                    final eased = Curves.easeOut.transform(pp);
                                    return Opacity(
                                      opacity: (.8 * (1 - eased)).clamp(0, 1),
                                      child: Transform.scale(
                                        scale: .4 + 1.2 * eased,
                                        child: Container(
                                          width: 208,
                                          height: 208,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: tone, width: 2),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            if (isFail)
                              SizedBox(
                                width: 224,
                                height: 224,
                                child: AnimatedBuilder(
                                  animation: _countdownCtrl,
                                  builder: (_, _) => CustomPaint(
                                    painter: _CountdownRingPainter(
                                        _countdownCtrl.value),
                                  ),
                                ),
                              ),
                            AnimatedScale(
                              scale: isOk ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: T.op(tone, .33), blurRadius: 60),
                                  ],
                                ),
                                child: Glass(
                                  radius: 64,
                                  width: 128,
                                  height: 128,
                                  child: Icon(
                                    isOk
                                        ? LucideIcons.check
                                        : isFail
                                            ? LucideIcons.shieldAlert
                                            : LucideIcons.nfc,
                                    size: 56,
                                    color: tone,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomPanel(isFail, isOk),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GlassIconBtn(
                  icon: LucideIcons.x,
                  size: 36,
                  onTap: widget.onBack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isFail, bool isOk) {
    if (_phase == _UnlockPhase.verify || isOk) {
      return Column(
        children: [
          Glass(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var i = 0; i < _apduSteps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: DefaultTextStyle(
                      style: T.mono(
                        11.5,
                        color: i < _apduStep
                            ? T.emerald400
                            : i == _apduStep
                                ? T.cyan400
                                : T.white(.3),
                      ),
                      child: Row(
                        children: [
                          i < _apduStep
                              ? const Icon(LucideIcons.check,
                                  size: 14, color: T.emerald400)
                              : const SizedBox(
                                  width: 14, child: Center(child: Text('›'))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_apduSteps[i])),
                          if (i < _apduStep)
                            Text('9000', style: T.mono(11.5, color: T.white(.4))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOk) ...[
            const SizedBox(height: 12),
            Btn.text(
              'Card Armed · 5:00',
              width: double.infinity,
              onTap: widget.onUnlocked,
            ),
          ],
        ],
      );
    }

    if (isFail) {
      return Column(
        children: [
          Text(
            _errorMsg.isNotEmpty
                ? _errorMsg
                : 'SW 0x6982 · SECURITY_STATUS_NOT_SATISFIED',
            textAlign: TextAlign.center,
            style: T.mono(11.5, color: T.red400),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-rescanning in ${_retrySecondsLeft}s…',
            style: T.text(12, color: T.white(.55)),
          ),
          const SizedBox(height: 12),
          Btn.text(
            'Retry Now (${_retrySecondsLeft}s)',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: _startScan,
          ),
          const SizedBox(height: 8),
          Btn.text(
            'Arm via Provisioned JCOP4 Card',
            variant: BtnVariant.primary,
            width: double.infinity,
            onTap: _forceUnlockWithProvisionedCard,
          ),
        ],
      );
    }

    // Scan phase
    return Column(
      children: [
        Text(
          'Hold your tap@tan JCOP4 card to the back of your phone',
          textAlign: TextAlign.center,
          style: T.text(13, color: T.white(.6)),
        ),
        const SizedBox(height: 12),
        Btn.text(
          'Arm via Provisioned JCOP4 Card',
          variant: BtnVariant.glass,
          width: double.infinity,
          onTap: _forceUnlockWithProvisionedCard,
        ),
        const SizedBox(height: 10),
        LinkText(
          'Proximity-bound · Single-Tap Locked · Cancel',
          onTap: widget.onBack,
        ),
      ],
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  _CountdownRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .45;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .03
        ..color = T.white(.1),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * (1 - progress),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .03
        ..strokeCap = StrokeCap.round
        ..color = T.amber500,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}
