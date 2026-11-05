import 'package:flutter/material.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class SsoScreen extends StatefulWidget {
  const SsoScreen({super.key});
  @override
  State<SsoScreen> createState() => _SsoScreenState();
}

class _SsoScreenState extends State<SsoScreen> {
  final _psn = TextEditingController(text: 'PSN-4829374');
  final _clientApp = TextEditingController(text: 'TAPATAN-APP-001');
  final _scopes = TextEditingController(text: 'identity,payments,documents');

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'eGovPH SSO',
      apiSubtitle: 'Single Sign-On Entry Point',
      description: 'The actual "login" surface that other apps redirect to. After eVerify + Liveness pass, issues a scoped Bearer access token '
          'and a refresh token. Client apps use this token for subsequent API calls.',
      gradient: const [Color(0xFF0E7490), Color(0xFF06B6D4)],
      icon: Icons.key_rounded,
      inputWidgets: [
        EGovInputField(
          controller: _psn,
          label: 'PhilSys Number (PSN)',
          hint: 'e.g. PSN-4829374',
          icon: Icons.badge_rounded,
          color: const Color(0xFF06B6D4),
        ),
        EGovInputField(
          controller: _clientApp,
          label: 'Client App ID',
          hint: 'Your registered app ID',
          icon: Icons.apps_rounded,
          color: const Color(0xFF06B6D4),
        ),
        EGovInputField(
          controller: _scopes,
          label: 'OAuth Scopes (comma-separated)',
          hint: 'identity,payments,documents',
          icon: Icons.security_rounded,
          color: const Color(0xFF06B6D4),
        ),
      ],
      callApi: () => EGovSsoService.issueToken(
        philsysNumber: _psn.text.trim().isEmpty ? 'PSN-DEMO' : _psn.text.trim(),
        clientAppId: _clientApp.text.trim().isEmpty ? 'TAPATAN-APP-001' : _clientApp.text.trim(),
        scopes: (_scopes.text.trim().isEmpty ? 'identity' : _scopes.text.trim())
            .split(',')
            .map((s) => s.trim())
            .toList(),
      ),
    );
  }
}
