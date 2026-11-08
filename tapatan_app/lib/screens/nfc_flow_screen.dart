import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/user_provider.dart';
import '../services/card_revocation_service.dart';
import '../services/jcop_apdu_service.dart';
import '../services/nfc_service.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

enum FlowStep {
  idle,
  amount,
  pin,
  otp,
  authenticating,
  writing,
  ready,
  success,
  error
}

class NfcFlowScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final void Function(double amount)? onTransactionComplete;
  final String cardId;
  final SarEPendingOrder? pendingOrder;

  const NfcFlowScreen({
    super.key,
    this.onClose,
    this.onTransactionComplete,
    required this.cardId,
    this.pendingOrder,
  });

  @override
  State<NfcFlowScreen> createState() => _NfcFlowScreenState();
}

class _NfcFlowScreenState extends State<NfcFlowScreen>
    with TickerProviderStateMixin {
  FlowStep _step = FlowStep.idle;
  String _amountStr = '';
  String _pinStr = '';
  String _otpStr = '';
  String _errorMsg = '';
  TokenPayload? _payload;

  int _apduIdx = 0;
  int _pinRetriesLeft = -1;

  static const int cardTimeoutSeconds = 5 * 60;
  int _timeoutSecsLeft = cardTimeoutSeconds;
  Timer? _timer;
  int _retrySecondsLeft = 0;
  Timer? _retryTimer;
  Timer? _apduTimer;
  bool _writeCompleted = false;

  static const double microThreshold = 100.0;
  static const double mediumThreshold = 500.0;
  static const double highThreshold = 1000.0;
  static const String _generatedOtp = '123456';

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

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

  static const _apduLines = [
    'SELECT 0xA4 · AID F07461706174616E0101',
    'TPT4 Turing handshake',
    'INTERNAL AUTHENTICATE 0x88',
    'STORE DATA 0xE2 · payment token',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.pendingOrder != null) {
      _amountStr = widget.pendingOrder!.totalAmount.toStringAsFixed(2);
      _amountCtrl.text = _amountStr;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startWriteFlow();
      });
    } else {
      // Directly show Amount entry sheet instead of a redundant intermediate button
      _checkRevocationAndStart();
    }
  }

  Future<void> _checkRevocationAndStart() async {
    final revoked = await CardRevocationService.isRevoked(widget.cardId);
    if (!mounted) return;
    if (revoked) {
      setState(() {
        _errorMsg = 'This card has been revoked. Please contact support.';
        _step = FlowStep.error;
      });
      return;
    }
    setState(() => _step = FlowStep.amount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    _apduTimer?.cancel();
    _ringCtrl.dispose();
    _shakeCtrl.dispose();
    _countdownCtrl.dispose();
    _amountCtrl.dispose();
    _otpCtrl.dispose();
    NfcService.stopSession();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountStr.trim()) ?? 0;

  String _authLevel() {
    if (_amount < microThreshold) return 'micro';
    if (_amount < mediumThreshold) return 'low';
    if (_amount < highThreshold) return 'medium';
    return 'high';
  }

  void _start5SecRetryTimer() {
    _retryTimer?.cancel();
    if (!mounted || _writeCompleted || _step == FlowStep.ready) return;
    _countdownCtrl.forward(from: 0);
    setState(() => _retrySecondsLeft = 5);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _writeCompleted || _step == FlowStep.ready) {
        timer.cancel();
        return;
      }
      if (_retrySecondsLeft <= 1) {
        timer.cancel();
        setState(() => _retrySecondsLeft = 0);
        _startWriteFlow(simulate: false);
      } else {
        setState(() => _retrySecondsLeft--);
      }
    });
  }

  void _startTimer() {
    _timeoutSecsLeft = cardTimeoutSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeoutSecsLeft <= 1) {
          timer.cancel();
          _step = FlowStep.amount;
          _payload = null;
        } else {
          _timeoutSecsLeft--;
        }
      });
    });
  }

  void _handleAmountNext() {
    if (_amount <= 0) return;
    final level = _authLevel();
    if (level == 'micro' || level == 'low') {
      _startWriteFlow();
    } else {
      setState(() {
        _pinStr = '';
        _errorMsg = '';
        _step = FlowStep.pin;
      });
    }
  }

  void _handlePinNext() {
    if (_pinStr.length < 4) return;
    if (_authLevel() == 'high') {
      setState(() {
        _otpStr = '';
        _errorMsg = '';
        _step = FlowStep.otp;
      });
    } else {
      _startWriteFlow();
    }
  }

  void _handleOtpNext() {
    if (_otpStr.trim() != _generatedOtp) {
      setState(() => _errorMsg = 'Incorrect OTP. Use demo OTP $_generatedOtp.');
      return;
    }
    _startWriteFlow();
  }

  Future<void> _completeWriteSuccess() async {
    if (_writeCompleted) return;
    _writeCompleted = true;
    _retryTimer?.cancel();
    _apduTimer?.cancel();
    await JcopApduService.stopSession();
    if (!mounted) return;
    await CardRevocationService.incrementUseCount(widget.cardId);
    await CardRevocationService.recordLastTap(widget.cardId);
    if (!mounted) return;
    setState(() {
      _apduIdx = _apduLines.length;
      _step = FlowStep.ready;
    });
    _startTimer();

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _step == FlowStep.ready) {
        widget.onTransactionComplete?.call(_amount);
      }
    });
  }

  Future<void> _startWriteFlow({bool simulate = false}) async {
    if (_writeCompleted || _step == FlowStep.writing) return;
    _retryTimer?.cancel();
    _apduTimer?.cancel();

    final newPayload =
        NfcService.buildTokenPayload(widget.cardId, _amount > 0 ? _amount : null);

    setState(() {
      _payload = newPayload;
      _step = FlowStep.writing;
      _apduIdx = 0;
      _errorMsg = '';
      _retrySecondsLeft = 0;
    });

    _apduTimer = Timer.periodic(const Duration(milliseconds: 520), (t) {
      if (!mounted || _step != FlowStep.writing) {
        t.cancel();
        return;
      }
      if (_apduIdx < _apduLines.length - 1) {
        setState(() => _apduIdx++);
      }
    });

    if (simulate) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _completeWriteSuccess();
      return;
    }

    final result = await NfcService.writeTokenToNfc(newPayload);
    _apduTimer?.cancel();
    if (!mounted || _writeCompleted) return;

    if (result['success'] == true) {
      await _completeWriteSuccess();
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() {
        _errorMsg = (result['error'] as String?) ?? 'NFC write failed.';
        _step = FlowStep.error;
      });
      _start5SecRetryTimer();
    }
  }

  void _reset() {
    _timer?.cancel();
    _retryTimer?.cancel();
    _apduTimer?.cancel();
    _amountCtrl.clear();
    _otpCtrl.clear();
    setState(() {
      _step = FlowStep.amount;
      _payload = null;
      _amountStr = '';
      _pinStr = '';
      _otpStr = '';
      _errorMsg = '';
      _pinRetriesLeft = -1;
      _writeCompleted = false;
      _retrySecondsLeft = 0;
    });
  }

  void _closeFlow() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Steps amount / pin / otp appear as crisp liquid-glass bottom sheet
    if (_step == FlowStep.idle ||
        _step == FlowStep.amount ||
        _step == FlowStep.pin ||
        _step == FlowStep.otp) {
      return Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: T.blk(.55),
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Glass(
              kind: GlassKind.strong,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
              padding: EdgeInsets.fromLTRB(
                  20, 10, 20, MediaQuery.of(context).padding.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: T.white(.3),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NFC Tap to Pay', style: T.text(17, w: T.w700)),
                            Text(
                              'JCOP4 J3R150 · Turing Composition MAC',
                              style: T.mono(10, color: T.white(.45)),
                            ),
                          ],
                        ),
                        GlassIconBtn(icon: LucideIcons.x, onTap: _closeFlow),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_step == FlowStep.amount || _step == FlowStep.idle)
                      _buildAmountSheetBody()
                    else if (_step == FlowStep.pin)
                      _buildPinSheetBody()
                    else
                      _buildOtpSheetBody(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Fullscreen NFC Tap / Approved / Failed screen (1:1 React NfcTap)
    final isFail = _step == FlowStep.error;
    final isReady = _step == FlowStep.ready || _step == FlowStep.success;
    final tone = isFail ? T.red400 : (isReady ? T.emerald400 : T.cyan400);
    final headline = isReady
        ? 'Approved ✓'
        : isFail
            ? 'Unauthorized Card'
            : _step == FlowStep.authenticating
                ? 'Updating Card State…'
                : 'Pay ₱${_amount.toStringAsFixed(2)}';

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
                            ? (v < .25 ? -8.0 : v < .5 ? 8.0 : -4.0)
                            : 0.0;
                        return Transform.translate(
                            offset: Offset(dx, 0), child: child);
                      },
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (!isFail && !isReady)
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
                            if (isFail && _retrySecondsLeft > 0)
                              SizedBox(
                                width: 224,
                                height: 224,
                                child: AnimatedBuilder(
                                  animation: _countdownCtrl,
                                  builder: (_, _) => CustomPaint(
                                    painter: _FlowCountdownPainter(
                                        _countdownCtrl.value),
                                  ),
                                ),
                              ),
                            AnimatedScale(
                              scale: isReady ? 1.1 : 1.0,
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
                                    isReady
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
                  if (isReady)
                    _buildReadyBottom()
                  else if (isFail)
                    _buildErrorBottom()
                  else
                    _buildWritingBottom(),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GlassIconBtn(
                  icon: LucideIcons.x,
                  size: 36,
                  onTap: _closeFlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSheetBody() {
    final tierLabel = _amount <= 0
        ? 'Enter amount to compute verification tier'
        : _amount < mediumThreshold
            ? 'Standard Tap · No PIN required (< ₱500)'
            : _amount < highThreshold
                ? 'Elevated Tier · Requires Card PIN (≥ ₱500)'
                : 'High-Value Tier · Card PIN + Email OTP (≥ ₱1,000)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [50, 150, 500, 1200].map((v) {
            final selected = _amount == v.toDouble();
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: v == 1200 ? 0 : 8),
                child: PressScale(
                  onTap: () => setState(() {
                    _amountStr = v.toString();
                    _amountCtrl.text = _amountStr;
                  }),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? T.op(T.cyan400, .20) : T.white(.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? T.op(T.cyan300, .6) : T.white(.1),
                      ),
                    ),
                    child: Text(
                      '₱$v',
                      style: T.text(
                        12.5,
                        w: T.w700,
                        color: selected ? T.cyan200 : T.white(.75),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Field(
          label: 'Transaction amount (₱)',
          mono: true,
          controller: _amountCtrl,
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => _amountStr = v),
        ),
        Text(
          tierLabel,
          style: T.text(11, color: T.cyan300),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Btn.text(
              'Cancel',
              variant: BtnVariant.glass,
              onTap: _closeFlow,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Btn.text(
                'Continue to NFC Tap',
                disabled: _amount <= 0,
                onTap: _handleAmountNext,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinSheetBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Card PIN${_amount >= highThreshold ? ' · Step 1 of 2' : ''}',
              style: T.text(13, color: T.white(.60)),
            ),
            if (_pinRetriesLeft >= 0)
              Badge2(
                _pinRetriesLeft == 0 ? 'LOCKED' : '$_pinRetriesLeft TRIES LEFT',
                color: _pinRetriesLeft <= 1 ? T.red400 : T.cyan400,
                textColor: _pinRetriesLeft <= 1 ? T.red300 : T.cyan200,
              ),
          ],
        ),
        PinDots(n: _pinStr.length, max: 6),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: T.text(12, color: T.red400),
            ),
          ),
        Numpad(
          value: _pinStr,
          max: 6,
          onChanged: (v) => setState(() => _pinStr = v),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Btn.text('Back', variant: BtnVariant.glass, onTap: _reset),
            const SizedBox(width: 10),
            Expanded(
              child: Btn.text(
                'Confirm PIN',
                disabled: _pinStr.length < 4 || _pinRetriesLeft == 0,
                onTap: _handlePinNext,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpSheetBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'High-value payment detected (≥ ₱1,000). Enter 6-digit email OTP (demo: $_generatedOtp).',
          style: T.text(12, color: T.white(.60)),
        ),
        const SizedBox(height: 12),
        Field(
          label: 'Email OTP (Step 2 of 2)',
          mono: true,
          controller: _otpCtrl,
          hint: '123456',
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => setState(() {
            _otpStr = v;
            _errorMsg = '';
          }),
        ),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_errorMsg, style: T.text(12, color: T.red400)),
          ),
        Row(
          children: [
            Btn.text('Cancel', variant: BtnVariant.glass, onTap: _reset),
            const SizedBox(width: 10),
            Expanded(
              child: Btn.text(
                'Verify OTP & Tap',
                disabled: _otpStr.length < 6,
                onTap: _handleOtpNext,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWritingBottom() {
    return Column(
      children: [
        Glass(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var i = 0; i < _apduLines.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: Row(
                    children: [
                      i < _apduIdx
                          ? const Icon(LucideIcons.check,
                              size: 14, color: T.emerald400)
                          : const SizedBox(
                              width: 14, child: Center(child: Text('›'))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _apduLines[i],
                          style: T.mono(
                            11.5,
                            color: i < _apduIdx
                                ? T.emerald400
                                : i == _apduIdx
                                    ? T.cyan400
                                    : T.white(.35),
                          ),
                        ),
                      ),
                      if (i < _apduIdx)
                        Text('9000', style: T.mono(11, color: T.white(.40))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Btn.text(
          'Arm via Provisioned JCOP4 Card',
          variant: BtnVariant.glass,
          width: double.infinity,
          onTap: () => _startWriteFlow(simulate: true),
        ),
      ],
    );
  }

  Widget _buildReadyBottom() {
    final mins = _timeoutSecsLeft ~/ 60;
    final secs = (_timeoutSecsLeft % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Glass(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                widget.pendingOrder?.merchant ?? 'NFC POS Terminal',
                style: T.text(11.5, color: T.white(.55)),
              ),
              const SizedBox(height: 2),
              Text(
                '₱${_amount.toStringAsFixed(2)}',
                style: T.text(28, w: T.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'TM•${_payload?.token ?? "9000"} · MAC verified · $mins:$secs left',
                style: T.mono(11, color: T.emerald300),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Btn.text(
          'Done',
          width: double.infinity,
          onTap: () => widget.onTransactionComplete?.call(_amount),
        ),
        const SizedBox(height: 8),
        Btn.text(
          'Disarm / Revert Card',
          variant: BtnVariant.glass,
          width: double.infinity,
          onTap: () async {
            setState(() {
              _step = FlowStep.authenticating;
              _errorMsg = '';
            });
            final result = await NfcService.revertCardIdentity(widget.cardId);
            if (!mounted) return;
            if (result['success'] == true) {
              _reset();
            } else {
              setState(() {
                _errorMsg =
                    (result['error'] as String?) ?? 'Failed to disarm card.';
                _step = FlowStep.error;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildErrorBottom() {
    return Column(
      children: [
        Text(
          _errorMsg.isNotEmpty
              ? _errorMsg
              : 'SW 0x6982 · SECURITY_STATUS_NOT_SATISFIED',
          textAlign: TextAlign.center,
          style: T.mono(11.5, color: T.red400),
        ),
        if (_retrySecondsLeft > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Auto-rescanning in ${_retrySecondsLeft}s…',
            style: T.text(12, color: T.white(.55)),
          ),
        ],
        const SizedBox(height: 12),
        Btn.text(
          _retrySecondsLeft > 0
              ? 'Retry Now (${_retrySecondsLeft}s)'
              : 'Retry Now',
          variant: BtnVariant.glass,
          width: double.infinity,
          onTap: () => _startWriteFlow(simulate: false),
        ),
        const SizedBox(height: 8),
        Btn.text(
          'Arm via Provisioned JCOP4 Card',
          width: double.infinity,
          onTap: () => _startWriteFlow(simulate: true),
        ),
      ],
    );
  }
}

class _FlowCountdownPainter extends CustomPainter {
  final double progress;
  _FlowCountdownPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * .45;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .03
        ..color = T.white(.1),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
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
  bool shouldRepaint(_FlowCountdownPainter old) => old.progress != progress;
}
