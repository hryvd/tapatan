import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/egov_api.dart';

/// Runs all 6 eGov APIs in sequence with a live step-by-step visualizer.
class FullFlowScreen extends StatefulWidget {
  const FullFlowScreen({super.key});

  @override
  State<FullFlowScreen> createState() => _FullFlowScreenState();
}

enum StepState { idle, running, success, error }

class _FlowStep {
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  StepState state;
  EGovResponse? response;
  String? errorMsg;

  _FlowStep({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.state = StepState.idle,
    this.response,
    this.errorMsg,
  });
}

class _FullFlowScreenState extends State<FullFlowScreen> {
  bool _running = false;
  bool _done = false;
  int _currentStep = -1;
  EGovResponse? _selectedResponse;
  int _selectedIndex = -1;

  late List<_FlowStep> _steps;

  @override
  void initState() {
    super.initState();
    _initSteps();
  }

  void _initSteps() {
    _steps = [
      _FlowStep(
        name: 'eVerify',
        subtitle: 'PhilSys Identity Check',
        icon: Icons.verified_user_rounded,
        gradient: const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      ),
      _FlowStep(
        name: 'Face Liveness',
        subtitle: 'Anti-Deepfake Confirmation',
        icon: Icons.face_retouching_natural,
        gradient: const [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      ),
      _FlowStep(
        name: 'eGovPH SSO',
        subtitle: 'Issue Access Token',
        icon: Icons.key_rounded,
        gradient: const [Color(0xFF0E7490), Color(0xFF06B6D4)],
      ),
      _FlowStep(
        name: 'eMessage',
        subtitle: 'Push Approval Request',
        icon: Icons.notifications_active_rounded,
        gradient: const [Color(0xFFB45309), Color(0xFFF59E0B)],
      ),
      _FlowStep(
        name: 'eGovChain',
        subtitle: 'Log Audit Event',
        icon: Icons.link_rounded,
        gradient: const [Color(0xFF047857), Color(0xFF10B981)],
      ),
      _FlowStep(
        name: 'eGovAI',
        subtitle: 'Fraud Risk Analysis',
        icon: Icons.psychology_rounded,
        gradient: const [Color(0xFFB91C1C), Color(0xFFEF4444)],
      ),
    ];
  }

  Future<void> _runFlow() async {
    setState(() {
      _running = true;
      _done = false;
      _currentStep = -1;
      _selectedResponse = null;
      _selectedIndex = -1;
      for (final s in _steps) {
        s.state = StepState.idle;
        s.response = null;
        s.errorMsg = null;
      }
    });

    String philsysNumber = 'PSN-DEMO-000';
    String sessionToken = 'SESSION-INIT';
    String ssoToken = '';

    final apiCalls = <Future<EGovResponse> Function()>[
      // Step 0 — eVerify
      () => EVerifyService.verify(cardSerial: 'NFC-JCOP-A3F2B1C0', nfcChallenge: 'CHLN-DEMO'),
      // Step 1 — Liveness
      () => FaceLivenessService.check(philsysNumber: philsysNumber, sessionToken: sessionToken),
      // Step 2 — SSO
      () => EGovSsoService.issueToken(
          philsysNumber: philsysNumber,
          clientAppId: 'TAPATAN-APP-001',
          scopes: ['identity', 'payments', 'documents']),
      // Step 3 — eMessage
      () => EMessageService.sendApprovalRequest(
          philsysNumber: philsysNumber,
          action: 'PAYMENT_APPROVAL',
          requester: 'Tapatan Pay · ₱5,000.00',
          payload: {'amount': 5000, 'currency': 'PHP', 'merchant': 'Tapatan'}),
      // Step 4 — Chain
      () => EGovChainService.logEvent(
          eventType: 'FULL_AUTH_FLOW',
          actor: philsysNumber,
          metadata: {'ssoToken': ssoToken.substring(0, ssoToken.isEmpty ? 0 : 8) + '...', 'app': 'TAPATAN-APP-001'}),
      // Step 5 — AI
      () => EGovAiService.analyzeRisk(
          philsysNumber: philsysNumber,
          requestType: 'PAYMENT_AUTH',
          context: {'location': 'Quezon City, PH', 'requestHour': DateTime.now().hour}),
    ];

    for (int i = 0; i < _steps.length; i++) {
      setState(() {
        _currentStep = i;
        _steps[i].state = StepState.running;
      });

      try {
        final res = await apiCalls[i]();
        
        // Capture values from early steps to pass to later steps
        if (i == 0 && res.success) {
          philsysNumber = res.data['philsysNumber'] as String? ?? philsysNumber;
          sessionToken = res.data['nfcChallenge'] as String? ?? sessionToken;
        }
        if (i == 2 && res.success) {
          ssoToken = res.data['accessToken'] as String? ?? '';
        }

        setState(() {
          _steps[i].state = res.success ? StepState.success : StepState.error;
          _steps[i].response = res;
          if (!res.success) _steps[i].errorMsg = res.errorMessage;
        });

        // Stop the flow if a critical step fails
        if (!res.success && i < 3) {
          break;
        }
      } catch (e) {
        setState(() {
          _steps[i].state = StepState.error;
          _steps[i].errorMsg = e.toString();
        });
        break;
      }
    }

    setState(() {
      _running = false;
      _done = true;
      _currentStep = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSuccess = _done && _steps.every((s) => s.state == StepState.success);
    final hasError = _done && _steps.any((s) => s.state == StepState.error);

    return Scaffold(
      backgroundColor: const Color(0xFF08142B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Full eGov Flow',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          if (_done)
            GestureDetector(
              onTap: () {
                setState(() {
                  _initSteps();
                  _done = false;
                  _selectedResponse = null;
                  _selectedIndex = -1;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Text('Reset', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header banner
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: allSuccess
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : hasError
                          ? const Color(0xFFEF4444).withOpacity(0.4)
                          : const Color(0xFF003087).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allSuccess ? Icons.check_circle_rounded : hasError ? Icons.error_rounded : Icons.hub_rounded,
                    color: allSuccess
                        ? const Color(0xFF10B981)
                        : hasError
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF60A5FA),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allSuccess
                              ? 'Identity Verified — All Checks Passed'
                              : hasError
                                  ? 'Flow Error — See Details Below'
                                  : _running
                                      ? 'Running eGov Verification Flow...'
                                      : 'Tap Run to Execute All 6 APIs in Sequence',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'eVerify → Liveness → SSO → eMessage → Chain → AI',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Step list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _steps.length,
              itemBuilder: (ctx, i) => _StepCard(
                step: _steps[i],
                index: i,
                isActive: _currentStep == i,
                isSelected: _selectedIndex == i,
                onTap: _steps[i].response != null
                    ? () => setState(() {
                          if (_selectedIndex == i) {
                            _selectedIndex = -1;
                            _selectedResponse = null;
                          } else {
                            _selectedIndex = i;
                            _selectedResponse = _steps[i].response;
                          }
                        })
                    : null,
              ),
            ),
          ),

          // Response viewer (inline)
          if (_selectedResponse != null)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF030D1F),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${_steps[_selectedIndex].name} Response',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() { _selectedResponse = null; _selectedIndex = -1; }),
                          child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.4), size: 18),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SelectableText(
                        _selectedResponse.toString(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF93C5FD),
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Run button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: GestureDetector(
              onTap: _running ? null : _runFlow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _running
                      ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF4B5563)])
                      : const LinearGradient(
                          colors: [Color(0xFF003087), Color(0xFF0050C8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _running
                      ? []
                      : const [BoxShadow(color: Color(0x440050C8), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_running) ...[
                      const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('Executing Flow...', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ] else ...[
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(_done ? 'Run Again' : 'Run Full eGov Flow',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _FlowStep step;
  final int index;
  final bool isActive;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StepCard({
    required this.step,
    required this.index,
    required this.isActive,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = step.gradient.last;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : isActive
                  ? const Color(0xFF0D1F3C)
                  : const Color(0xFF0D1F3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.5)
                : isActive
                    ? color.withOpacity(0.4)
                    : step.state == StepState.success
                        ? const Color(0xFF10B981).withOpacity(0.25)
                        : step.state == StepState.error
                            ? const Color(0xFFEF4444).withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            // Icon / status
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: step.state == StepState.idle
                    ? null
                    : LinearGradient(colors: step.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: step.state == StepState.idle ? Colors.white.withOpacity(0.06) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: step.state == StepState.running
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : step.state == StepState.success
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : step.state == StepState.error
                          ? const Icon(Icons.close_rounded, color: Colors.white, size: 20)
                          : Icon(step.icon, color: Colors.white.withOpacity(0.3), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.name,
                    style: GoogleFonts.inter(
                      color: step.state == StepState.idle ? Colors.white.withOpacity(0.5) : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                  Text(
                    step.state == StepState.running
                        ? 'Calling...'
                        : step.state == StepState.success
                            ? step.subtitle
                            : step.state == StepState.error
                                ? (step.errorMsg ?? 'Error')
                                : step.subtitle,
                    style: GoogleFonts.inter(
                      color: step.state == StepState.success
                          ? const Color(0xFF34D399)
                          : step.state == StepState.error
                              ? const Color(0xFFF87171)
                              : step.state == StepState.running
                                  ? color
                                  : Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      fontWeight: step.state == StepState.running ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (step.response != null) ...[
              Icon(
                isSelected ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ] else ...[
              Text('${index + 1}',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.15), fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
