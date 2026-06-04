import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';
import '../services/card_revocation_service.dart';

class SecurityInfoScreen extends StatefulWidget {
  const SecurityInfoScreen({super.key});

  @override
  State<SecurityInfoScreen> createState() => _SecurityInfoScreenState();
}

class _SecurityInfoScreenState extends State<SecurityInfoScreen> {
  int? _expandedIdx;
  List<String> _revokedCards = [];
  bool _showRevokeInput = false;
  final TextEditingController _revokeController = TextEditingController();
  
  final List<Map<String, dynamic>> _attacks = [
    {
      "attack": "MITM (Man-in-the-Middle)",
      "protection": "Tokens are single-use and timestamp-bound. Intercepted tokens expire in 30 seconds and cannot be replayed.",
      "protected": true,
    },
    {
      "attack": "SIM Swap",
      "protection": "Authentication requires physical possession of the NFC card — no SMS OTP dependency.",
      "protected": true,
    },
    {
      "attack": "Phishing",
      "protection": "No credentials are entered. The NFC card holds the token — phishing pages can't steal what doesn't exist in a form.",
      "protected": true,
    },
    {
      "attack": "Token Replay",
      "protection": "Tokens are single-use and cryptographically bound to a session ID and timestamp.",
      "protected": true,
    },
    {
      "attack": "Remote Card Cloning",
      "protection": "Partial — card UID is validated, but without attestation certificates a sophisticated clone is theoretically possible.",
      "protected": false,
    },
    {
      "attack": "Physical Theft of Card Only",
      "protection": "Protected — the card is only useful when paired with the app's token. Without the app, a stolen card cannot transact.",
      "protected": true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRevoked();
  }

  void _loadRevoked() async {
    final list = await CardRevocationService.getRevokedCards();
    setState(() => _revokedCards = list);
  }

  void _handleRevoke() async {
    String id = _revokeController.text.trim();
    if (id.isNotEmpty) {
      await CardRevocationService.revokeCard(id);
      _revokeController.clear();
      setState(() => _showRevokeInput = false);
      _loadRevoked();
    }
  }

  void _handleUnrevoke(String id) async {
    await CardRevocationService.unRevokeCard(id);
    _loadRevoked();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0230), Color(0xFF040015)]
        ),
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text("Security Info", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRevocationPanel(),
                const SizedBox(height: 16),
                _buildSystemProperties(),
                const SizedBox(height: 16),
                _buildThreatModel(),
                const SizedBox(height: 16),
                _buildResearchNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevocationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x14EF4444), Color(0x0DEF4444)]),
        border: Border.all(color: const Color(0x33EF4444)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.xCircle, color: Color(0xFFF87171), size: 16),
              SizedBox(width: 8),
              Text("Card Revocation", style: TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text("Lost your NFC card? Revoke it instantly. Any card with this ID will be rejected everywhere.", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          
          if (_revokedCards.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("REVOKED CARDS", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._revokedCards.map((id) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0x1AEF4444), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x33EF4444))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(id, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontFamily: 'monospace')),
                  GestureDetector(
                    onTap: () => _handleUnrevoke(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                      child: const Text("Restore", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            )),
          ],

          const SizedBox(height: 16),
          if (_showRevokeInput)
            Column(
              children: [
                TextField(
                  controller: _revokeController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter Card ID to revoke",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { _showRevokeInput = false; _revokeController.clear(); }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleRevoke,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: const Color(0xB2EF4444), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Text("🔒 Revoke", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            )
          else
            GestureDetector(
              onTap: () => setState(() => _showRevokeInput = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x26EF4444),
                  border: Border.all(color: const Color(0x4DEF4444)),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lock, color: Color(0xFFF87171), size: 14),
                    SizedBox(width: 6),
                    Text("Lock / Revoke a Card", style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSystemProperties() {
    final props = [
      {"label": "Auth Factor", "val": "Something you have (NFC)", "icon": LucideIcons.shield, "color": const Color(0xFF34D399)},
      {"label": "Token Lifetime", "val": "5 mins or single-use", "icon": LucideIcons.lock, "color": const Color(0xFF38BDF8)},
      {"label": "Token Binding", "val": "Session + Time + Card", "icon": LucideIcons.checkCircle, "color": const Color(0xFF06B6D4)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.eye, color: Color(0xFF38BDF8), size: 14),
              SizedBox(width: 8),
              Text("System Properties", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...props.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: (p["color"] as Color).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(p["icon"] as IconData, size: 13, color: p["color"] as Color),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p["label"] as String, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    Text(p["val"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ))
        ],
      ),
    );
  }

  Widget _buildThreatModel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.info, color: Color(0xFF38BDF8), size: 14),
            SizedBox(width: 8),
            Text("Threat Model", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text("— tap to expand", style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        ..._attacks.asMap().entries.map((e) {
          int idx = e.key;
          var item = e.value;
          bool isExpanded = _expandedIdx == idx;
          bool protected = item["protected"] as bool;
          
          return GestureDetector(
            onTap: () => setState(() => _expandedIdx = isExpanded ? null : idx),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: protected ? const Color(0x0F10B981) : const Color(0x0FEF4444),
                border: Border.all(color: protected ? const Color(0x3310B981) : const Color(0x33EF4444)),
                borderRadius: BorderRadius.circular(16)
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(protected ? LucideIcons.checkCircle : LucideIcons.alertTriangle, color: protected ? const Color(0xFF34D399) : const Color(0xFFF87171), size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item["attack"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: Colors.white30, size: 14),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    Text(item["protection"] as String, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.5)),
                  ]
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResearchNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x1A0891B2), Color(0x1406B6D4)]),
        border: Border.all(color: const Color(0x330891B2)),
        borderRadius: BorderRadius.circular(24)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.info, color: Color(0xFF38BDF8), size: 13),
              SizedBox(width: 8),
              Text("Research Transparency Note", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text("This system is a research prototype. It does not implement SCP03 Secure Channel Protocol or formal card attestation certificates. The NFC communication channel is not encrypted at the transport layer.", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.6)),
        ],
      ),
    );
  }
}
