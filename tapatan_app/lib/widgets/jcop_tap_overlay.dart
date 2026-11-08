import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

/// Steps in the JCOP multi-APDU authentication exchange.
enum JcopAuthStep {
  waiting,
  connecting,
  selectingApplet,
  gettingChallenge,
  authenticating,
  verifyingPin,
  success,
  error,
}

extension JcopAuthStepLabel on JcopAuthStep {
  String get label {
    switch (this) {
      case JcopAuthStep.waiting:
        return 'Hold card near phone';
      case JcopAuthStep.connecting:
        return 'Connecting ISO-DEP...';
      case JcopAuthStep.selectingApplet:
        return 'SELECT 0xA4 · AID F07461…0101';
      case JcopAuthStep.gettingChallenge:
        return 'GET CHALLENGE 0x84 · nonce';
      case JcopAuthStep.authenticating:
        return 'INTERNAL AUTH 0x88 · TPT4';
      case JcopAuthStep.verifyingPin:
        return 'VERIFY 0x20 · Card PIN';
      case JcopAuthStep.success:
        return 'Authenticated · SW 0x9000';
      case JcopAuthStep.error:
        return 'Authentication failed';
    }
  }

  int get stepIndex {
    switch (this) {
      case JcopAuthStep.waiting:
        return 0;
      case JcopAuthStep.connecting:
        return 1;
      case JcopAuthStep.selectingApplet:
        return 2;
      case JcopAuthStep.gettingChallenge:
        return 3;
      case JcopAuthStep.authenticating:
      case JcopAuthStep.verifyingPin:
        return 4;
      case JcopAuthStep.success:
        return 5;
      case JcopAuthStep.error:
        return -1;
    }
  }
}

/// Full-screen liquid-glass overlay displayed during multi-APDU JCOP4 NFC exchange.
class JcopTapOverlay extends StatefulWidget {
  final JcopAuthStep step;
  final String? errorMessage;
  final String? successDetail;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const JcopTapOverlay({
    super.key,
    required this.step,
    this.errorMessage,
    this.successDetail,
    this.onRetry,
    this.onCancel,
  });

  @override
  State<JcopTapOverlay> createState() => _JcopTapOverlayState();
}

class _JcopTapOverlayState extends State<JcopTapOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _checkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  static const _apduList = [
    'Connecting ISO 14443-4',
    'SELECT 0xA4 · F07461706174616E0101',
    'GET CHALLENGE 0x84 · 8B nonce',
    'INTERNAL AUTH 0x88 · Turing MAC',
  ];

  @override
  void didUpdateWidget(JcopTapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step == JcopAuthStep.success &&
        oldWidget.step != JcopAuthStep.success) {
      _rippleCtrl.stop();
      _checkCtrl.forward(from: 0);
    } else if (widget.step == JcopAuthStep.error &&
        oldWidget.step != JcopAuthStep.error) {
      _rippleCtrl.stop();
    } else if (widget.step != JcopAuthStep.success &&
        widget.step != JcopAuthStep.error &&
        !_rippleCtrl.isAnimating) {
      _rippleCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.step == JcopAuthStep.error;
    final isSuccess = widget.step == JcopAuthStep.success;
    final tone = isError ? T.red400 : (isSuccess ? T.emerald400 : T.cyan400);

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
                  const SizedBox(height: 14),
                  Text(
                    'ISO 14443-4 · JCOP4 J3R150',
                    style: T.mono(11, color: T.white(.45), ls: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSuccess
                        ? 'Approved ✓'
                        : isError
                            ? 'Authentication Failed'
                            : 'Hold Card Still',
                    textAlign: TextAlign.center,
                    style: T.text(22, w: T.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSuccess
                        ? 'Turing Composition exchange completed'
                        : isError
                            ? (widget.errorMessage ?? 'Unknown error')
                            : 'Keep your phone steady against the card until verified',
                    textAlign: TextAlign.center,
                    style: T.text(
                      12.5,
                      color: isError ? T.red300 : T.white(.55),
                      height: 1.4,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (!isSuccess && !isError)
                            for (var i = 0; i < 3; i++)
                              AnimatedBuilder(
                                animation: _rippleCtrl,
                                builder: (_, _) {
                                  final p =
                                      ((_rippleCtrl.value * 2.4 - i * .8) /
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
                          ScaleTransition(
                            scale: isSuccess
                                ? Tween(begin: 0.85, end: 1.05).animate(
                                    CurvedAnimation(
                                        parent: _checkCtrl,
                                        curve: Curves.elasticOut))
                                : const AlwaysStoppedAnimation(1.0),
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
                                  isSuccess
                                      ? LucideIcons.check
                                      : isError
                                          ? LucideIcons.shieldAlert
                                          : LucideIcons.nfc,
                                  size: 54,
                                  color: tone,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isSuccess && !isError)
                    Glass(
                      radius: 22,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (var i = 0; i < _apduList.length; i++)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                              child: Row(
                                children: [
                                  i + 1 < widget.step.stepIndex
                                      ? const Icon(LucideIcons.check,
                                          size: 14, color: T.emerald400)
                                      : const SizedBox(
                                          width: 14,
                                          child: Center(child: Text('›'))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _apduList[i],
                                      style: T.mono(
                                        11.5,
                                        color: i + 1 < widget.step.stepIndex
                                            ? T.emerald400
                                            : i + 1 == widget.step.stepIndex
                                                ? T.cyan400
                                                : T.white(.35),
                                      ),
                                    ),
                                  ),
                                  if (i + 1 < widget.step.stepIndex)
                                    Text('9000',
                                        style:
                                            T.mono(11, color: T.white(.40))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (isSuccess && widget.successDetail != null)
                    Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(
                        widget.successDetail!,
                        style: T.mono(11, color: T.cyan200),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (isError && widget.onRetry != null) ...[
                    Btn.text(
                      'Try Again',
                      width: double.infinity,
                      onTap: widget.onRetry,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.onCancel != null)
                    Btn.text(
                      widget.step == JcopAuthStep.waiting ? 'Cancel' : 'Close',
                      variant: BtnVariant.glass,
                      width: double.infinity,
                      onTap: widget.onCancel,
                    ),
                ],
              ),
              if (widget.onCancel != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GlassIconBtn(
                    icon: LucideIcons.x,
                    size: 36,
                    onTap: widget.onCancel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
