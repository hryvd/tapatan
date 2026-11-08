import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';

// ── JCOP Auth Step Enum ───────────────────────────────────────────────────

/// Steps in the JCOP multi-APDU authentication exchange.
///
/// Each step maps to a progress indicator in [JcopTapOverlay].
enum JcopAuthStep {
  waiting,          // Waiting for card tap
  connecting,       // ISO-DEP tag detected, connecting
  selectingApplet,  // SELECT APDU sent
  gettingChallenge, // GET CHALLENGE APDU sent
  authenticating,   // INTERNAL AUTHENTICATE APDU sent
  verifyingPin,     // VERIFY APDU sent (for high-value flows)
  success,          // Auth complete
  error,            // Something went wrong
}

extension JcopAuthStepLabel on JcopAuthStep {
  String get label {
    switch (this) {
      case JcopAuthStep.waiting:
        return 'Hold card near phone';
      case JcopAuthStep.connecting:
        return 'Connecting...';
      case JcopAuthStep.selectingApplet:
        return 'Selecting applet';
      case JcopAuthStep.gettingChallenge:
        return 'Getting challenge';
      case JcopAuthStep.authenticating:
        return 'Authenticating';
      case JcopAuthStep.verifyingPin:
        return 'Verifying PIN';
      case JcopAuthStep.success:
        return 'Authenticated';
      case JcopAuthStep.error:
        return 'Failed';
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

// ── JCOP Tap Overlay ─────────────────────────────────────────────────────

/// Full-screen overlay displayed during the JCOP multi-APDU NFC exchange.
///
/// Shows:
/// - A pulsing card/phone animation urging the user to hold still
/// - A step progress bar: Connecting → SELECT → Challenge → Authenticating
/// - Current step label and error messages
///
/// **UX rationale** (JCOP plan Phase C.3): The most common failure in NFC MFA
/// demos is users lifting the phone after feeling the initial "tap" haptic,
/// before the multi-APDU exchange completes. This overlay holds attention
/// and communicates that the exchange is ongoing.
class JcopTapOverlay extends StatefulWidget {
  /// The current auth step to display.
  final JcopAuthStep step;

  /// Optional error message (shown when step == error).
  final String? errorMessage;

  /// Optional success card UID / token snippet to display on success.
  final String? successDetail;

  /// Callback when the user taps "Try Again" from the error state.
  final VoidCallback? onRetry;

  /// Callback when the user cancels.
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
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _checkController;

  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _checkAnim;

  static const _steps = [
    'Connecting',
    'SELECT',
    'Challenge',
    'Auth',
    'Done',
  ];

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rippleAnim = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _checkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(JcopTapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step == JcopAuthStep.success &&
        oldWidget.step != JcopAuthStep.success) {
      _pulseController.stop();
      _rippleController.stop();
      _checkController.forward();
    }
    if (widget.step == JcopAuthStep.error &&
        oldWidget.step != JcopAuthStep.error) {
      _pulseController.stop();
      _rippleController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.step == JcopAuthStep.error;
    final isSuccess = widget.step == JcopAuthStep.success;
    final isWaiting = widget.step == JcopAuthStep.waiting;

    return Container(
      color: const Color(0xE6020B18), // semi-opaque deep navy
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Title ──────────────────────────────────────────────
              Text(
                isSuccess
                    ? 'Authenticated'
                    : isError
                        ? 'Authentication Failed'
                        : 'Hold Card Still',
                style: TextStyle(
                  color: isSuccess
                      ? _green
                      : isError
                          ? _red
                          : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isSuccess
                    ? 'Card verified successfully'
                    : isError
                        ? (widget.errorMessage ?? 'Unknown error')
                        : 'Keep your phone flat against the card\nuntil the exchange completes',
                style: TextStyle(
                  color: isError
                      ? _red.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.38),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // ── Animated Card Icon ─────────────────────────────────
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripple rings (only during active scanning)
                    if (!isSuccess && !isError)
                      AnimatedBuilder(
                        animation: _rippleAnim,
                        builder: (context, child) => Container(
                          width: 160 * _rippleAnim.value,
                          height: 160 * _rippleAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _teal.withValues(
                                alpha: (1 -
                                        (_rippleAnim.value - 0.6) / 1.2)
                                    .clamp(0, 0.4)),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                    // Outer glow ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(
                        scale: isSuccess || isError ? 1.0 : _pulseAnim.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSuccess
                                ? _green.withValues(alpha: 0.12)
                                : isError
                                    ? _red.withValues(alpha: 0.12)
                                    : _teal.withValues(alpha: 0.10),
                            border: Border.all(
                              color: isSuccess
                                  ? _green.withValues(alpha: 0.4)
                                  : isError
                                      ? _red.withValues(alpha: 0.4)
                                      : _teal.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Center icon
                    if (isSuccess)
                      ScaleTransition(
                        scale: _checkAnim,
                        child: const Icon(
                          LucideIcons.badgeCheck,
                          color: _green,
                          size: 56,
                        ),
                      )
                    else if (isError)
                      const Icon(
                        LucideIcons.alertTriangle,
                        color: _red,
                        size: 56,
                      )
                    else
                      Icon(
                        isWaiting ? LucideIcons.wifi : LucideIcons.creditCard,
                        color: _teal,
                        size: 48,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Step Progress Bar ──────────────────────────────────
              if (!isSuccess && !isError) ...[
                _StepProgressBar(
                  steps: _steps,
                  currentStepIndex: widget.step.stepIndex,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.step.label,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // ── Success Detail ─────────────────────────────────────
              if (isSuccess && widget.successDetail != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _green.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    widget.successDetail!,
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // ── Action Buttons ─────────────────────────────────────
              if (isError && widget.onRetry != null)
                _OverlayButton(
                  label: 'Try Again',
                  color: _teal,
                  icon: LucideIcons.refreshCw,
                  onTap: widget.onRetry!,
                ),
              if (widget.onCancel != null) ...[
                if (isError) const SizedBox(height: 12),
                _OverlayButton(
                  label: isWaiting ? 'Cancel' : 'Stop',
                  color: Colors.white24,
                  icon: LucideIcons.x,
                  onTap: widget.onCancel!,
                  isSecondary: true,
                ),
              ],

              // ── Proximity / security note ──────────────────────────
              if (!isSuccess && !isError) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.shieldCheck,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      'Proximity-bound · Not relayable',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step Progress Bar ─────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final List<String> steps;
  final int currentStepIndex;

  const _StepProgressBar({
    required this.steps,
    required this.currentStepIndex,
  });

  static const _teal = Color(0xFF06B6D4);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i < currentStepIndex;
        final isCurrent = i == currentStepIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _teal
                            : isCurrent
                                ? _teal.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        color: isDone || isCurrent
                            ? _teal
                            : Colors.white.withValues(alpha: 0.24),
                        fontSize: 9,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }
}

// ── Overlay Button ────────────────────────────────────────────────────────

class _OverlayButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSecondary;

  const _OverlayButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSecondary
              ? Colors.white.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSecondary
                ? Colors.white.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color:
                    isSecondary ? Colors.white.withValues(alpha: 0.38) : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSecondary
                    ? Colors.white.withValues(alpha: 0.38)
                    : color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
