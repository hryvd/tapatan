import 'package:flutter/material.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class EMessageScreen extends StatefulWidget {
  const EMessageScreen({super.key});
  @override
  State<EMessageScreen> createState() => _EMessageScreenState();
}

class _EMessageScreenState extends State<EMessageScreen> {
  final _psn = TextEditingController(text: 'PSN-4829374');
  final _action = TextEditingController(text: 'PAYMENT_APPROVAL');
  final _requester = TextEditingController(text: 'Tapatan Pay · ₱5,000.00 → BDO-0012345');

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'eMessage',
      apiSubtitle: 'Push Approval Notifications',
      description: 'Pushes an approval request to the user\'s registered device. The user sees: "Tapatan wants to process ₱5,000 — Approve?" '
          'Returns an approvalCode that the user enters (or biometrically confirms) to complete the flow.',
      gradient: const [Color(0xFFB45309), Color(0xFFF59E0B)],
      icon: Icons.notifications_active_rounded,
      inputWidgets: [
        EGovInputField(
          controller: _psn,
          label: 'PhilSys Number (PSN)',
          hint: 'Recipient identity',
          icon: Icons.badge_rounded,
          color: const Color(0xFFF59E0B),
        ),
        EGovInputField(
          controller: _action,
          label: 'Action Type',
          hint: 'PAYMENT_APPROVAL / LOGIN / DOCUMENT_SIGN',
          icon: Icons.bolt_rounded,
          color: const Color(0xFFF59E0B),
        ),
        EGovInputField(
          controller: _requester,
          label: 'Requester Description',
          hint: 'Human-readable action description',
          icon: Icons.message_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
      callApi: () => EMessageService.sendApprovalRequest(
        philsysNumber: _psn.text.trim().isEmpty ? 'PSN-DEMO' : _psn.text.trim(),
        action: _action.text.trim().isEmpty ? 'PAYMENT_APPROVAL' : _action.text.trim(),
        requester: _requester.text.trim().isEmpty ? 'Demo App' : _requester.text.trim(),
        payload: {
          'amount': 5000,
          'currency': 'PHP',
          'merchant': 'Tapatan Demo',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }
}
