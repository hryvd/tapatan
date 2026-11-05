import 'package:flutter/material.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _psn = TextEditingController(text: 'PSN-4829374');
  final _requestType = TextEditingController(text: 'PAYMENT_AUTH');
  final _location = TextEditingController(text: 'Quezon City, PH');

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'eGovAI',
      apiSubtitle: 'AI Fraud Detection Engine',
      description: 'Flags anomalous authentication patterns using AI scoring. Detects: impossible travel velocity, rapid repeated requests, '
          'unusual geo-location, suspicious timing patterns. Returns a risk level (LOW/MEDIUM/HIGH) and a recommendation to APPROVE or CHALLENGE.',
      gradient: const [Color(0xFFB91C1C), Color(0xFFEF4444)],
      icon: Icons.psychology_rounded,
      inputWidgets: [
        EGovInputField(
          controller: _psn,
          label: 'PhilSys Number (PSN)',
          hint: 'Identity under analysis',
          icon: Icons.badge_rounded,
          color: const Color(0xFFEF4444),
        ),
        EGovInputField(
          controller: _requestType,
          label: 'Request Type',
          hint: 'PAYMENT_AUTH / LOGIN / DOC_SIGN',
          icon: Icons.category_rounded,
          color: const Color(0xFFEF4444),
        ),
        EGovInputField(
          controller: _location,
          label: 'Client Location Context',
          hint: 'e.g. Quezon City, PH',
          icon: Icons.location_on_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
      callApi: () => EGovAiService.analyzeRisk(
        philsysNumber: _psn.text.trim().isEmpty ? 'PSN-DEMO' : _psn.text.trim(),
        requestType: _requestType.text.trim().isEmpty ? 'PAYMENT_AUTH' : _requestType.text.trim(),
        context: {
          'location': _location.text.trim().isEmpty ? 'Unknown' : _location.text.trim(),
          'deviceFingerprint': 'DEVICE-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(0, 6).toUpperCase()}',
          'requestHour': DateTime.now().hour,
          'requestDayOfWeek': DateTime.now().weekday,
        },
      ),
    );
  }
}
