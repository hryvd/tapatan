import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/egov_api.dart';
import 'api_demo_scaffold.dart';

class ChainScreen extends StatefulWidget {
  const ChainScreen({super.key});
  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  final _actor = TextEditingController(text: 'PSN-4829374');
  final _eventType = TextEditingController(text: 'AUTH_SUCCESS');
  bool _showChain = false;

  @override
  Widget build(BuildContext context) {
    return ApiDemoScaffold(
      apiName: 'eGovChain',
      apiSubtitle: 'Tamper-Evident Audit Trail',
      description: 'Tamper-evident blockchain-style log of every authentication event. Each block references the previous block\'s hash, '
          'making retroactive tampering detectable. Useful for fraud disputes: "I never approved that login."',
      gradient: const [Color(0xFF047857), Color(0xFF10B981)],
      icon: Icons.link_rounded,
      inputWidgets: [
        EGovInputField(
          controller: _actor,
          label: 'Actor (PSN or App ID)',
          hint: 'Who triggered this event',
          icon: Icons.person_rounded,
          color: const Color(0xFF10B981),
        ),
        EGovInputField(
          controller: _eventType,
          label: 'Event Type',
          hint: 'AUTH_SUCCESS / PAYMENT / DOC_SIGN / LOGOUT',
          icon: Icons.event_note_rounded,
          color: const Color(0xFF10B981),
        ),
        // View chain button
        GestureDetector(
          onTap: () => setState(() => _showChain = !_showChain),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Text('${_showChain ? 'Hide' : 'View'} Local Chain (${EGovChainService.chain.length} blocks)',
                  style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Icon(_showChain ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: const Color(0xFF10B981), size: 18),
              ],
            ),
          ),
        ),
        if (_showChain && EGovChainService.chain.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ChainViewer(),
        ],
        if (_showChain && EGovChainService.chain.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No blocks yet — call the API to log events.',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ),
        const SizedBox(height: 4),
      ],
      callApi: () => EGovChainService.logEvent(
        eventType: _eventType.text.trim().isEmpty ? 'AUTH_SUCCESS' : _eventType.text.trim(),
        actor: _actor.text.trim().isEmpty ? 'PSN-DEMO' : _actor.text.trim(),
        metadata: {
          'userAgent': 'TapatanApp/1.0 Android',
          'ip': '192.168.1.' + (100 + (DateTime.now().millisecond % 50)).toString(),
          'requestType': _eventType.text.trim(),
        },
      ),
    );
  }
}

class _ChainViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chain = EGovChainService.chain.reversed.toList();
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF030D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: chain.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final block = chain[i];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: Center(
                  child: Text('${chain.length - i}',
                    style: GoogleFonts.jetBrainsMono(color: const Color(0xFF10B981), fontSize: 10)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${block.eventType} · ${block.actor}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(block.blockHash,
                      style: GoogleFonts.jetBrainsMono(color: const Color(0xFF10B981).withOpacity(0.7), fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
