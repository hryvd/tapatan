import 'package:flutter/material.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});
  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  final _psn = TextEditingController(text: 'PSN-4829374');
  final _session = TextEditingController(text: 'SESSION-${DateTime.now().millisecondsSinceEpoch}');

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'Face Liveness',
      apiSubtitle: 'Anti-Deepfake Check',
      description: 'Ensures a real person (not a photo/deepfake) is approving the request — critical since this replaces OTP entirely. '
          'Returns a liveness score, facial match score, and a list of anti-spoof checks passed.',
      gradient: const [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      icon: Icons.face_retouching_natural,
      inputWidgets: [
        EGovInputField(
          controller: _psn,
          label: 'PhilSys Number (PSN)',
          hint: 'e.g. PSN-4829374',
          icon: Icons.badge_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        EGovInputField(
          controller: _session,
          label: 'Session Token',
          hint: 'From eVerify or SSO',
          icon: Icons.key_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      ],
      callApi: () => FaceLivenessService.check(
        philsysNumber: _psn.text.trim().isEmpty ? 'PSN-DEMO' : _psn.text.trim(),
        sessionToken: _session.text.trim().isEmpty ? 'SESSION-DEMO' : _session.text.trim(),
      ),
    );
  }
}
