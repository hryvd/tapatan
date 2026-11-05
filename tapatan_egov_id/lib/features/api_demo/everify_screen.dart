import 'package:flutter/material.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class EVerifyScreen extends StatefulWidget {
  const EVerifyScreen({super.key});
  @override
  State<EVerifyScreen> createState() => _EVerifyScreenState();
}

class _EVerifyScreenState extends State<EVerifyScreen> {
  final _serial = TextEditingController(text: 'NFC-JCOP-A3F2B1C0');
  final _challenge = TextEditingController(text: 'CHLN-' + DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase());

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'eVerify',
      apiSubtitle: 'PhilSys Identity Backbone',
      description: 'Confirms the request is tied to a real PhilSys-verified identity, not a spoofed account. '
          'Pass the card\'s NFC serial and a fresh challenge string; receives back the citizen\'s verified name, PSN, and confidence score.',
      gradient: const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      icon: Icons.verified_user_rounded,
      inputWidgets: [
        EGovInputField(
          controller: _serial,
          label: 'NFC Card Serial',
          hint: 'e.g. NFC-JCOP-A3F2B1C0',
          icon: Icons.nfc_rounded,
          color: const Color(0xFF3B82F6),
        ),
        EGovInputField(
          controller: _challenge,
          label: 'NFC Challenge (hex)',
          hint: 'Random hex challenge',
          icon: Icons.fingerprint_rounded,
          color: const Color(0xFF3B82F6),
        ),
      ],
      callApi: () => EVerifyService.verify(
        cardSerial: _serial.text.trim().isEmpty ? 'NFC-JCOP-A3F2B1C0' : _serial.text.trim(),
        nfcChallenge: _challenge.text.trim().isEmpty ? 'CHLN-DEMO' : _challenge.text.trim(),
      ),
    );
  }
}
