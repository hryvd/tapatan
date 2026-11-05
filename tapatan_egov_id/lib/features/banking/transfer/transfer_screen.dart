import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/banking_provider.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});
  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _nameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'tapatan' && uri.host == 'transfer_success') {
        final approvalId = uri.queryParameters['approvalId'];
        if (approvalId != null) {
          setState(() => _loading = true);
          final r = await ref.read(bankingProvider.notifier).approveAndExecuteTransfer(
            approvalId: approvalId,
            recipientName: _nameCtrl.text.trim(),
            recipientAccount: _accountCtrl.text.trim(),
            amount: double.tryParse(_amountCtrl.text) ?? 0,
          );
          if (!mounted) return;
          setState(() {
            _loading = false;
            if (r.success) {
              _success = '₱${(double.tryParse(_amountCtrl.text) ?? 0).toStringAsFixed(2)} sent to ${_nameCtrl.text.trim()}';
              _nameCtrl.clear(); _accountCtrl.clear(); _amountCtrl.clear();
            } else {
              _error = r.errorMessage;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // Mock contacts
  final _contacts = [
    ('Maria Santos', 'PH-BDO-001234567'),
    ('Jose Reyes', 'PH-BPI-009876543'),
    ('Ana Garcia', 'PH-UB-00456789'),
    ('Carlo Diaz', 'PH-LBP-007654321'),
  ];

  Future<void> _send() async {
    final amt = double.tryParse(_amountCtrl.text);
    if (_nameCtrl.text.trim().isEmpty || _accountCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Fill in recipient details');
      return;
    }
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });

    final result = await ref.read(bankingProvider.notifier).initiateTransfer(
      recipientName: _nameCtrl.text.trim(),
      recipientAccount: _accountCtrl.text.trim(),
      amount: amt,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success && !result.needsApproval) {
      setState(() => _error = result.errorMessage ?? 'Transfer failed');
      return;
    }

    if (result.needsApproval && result.approvalId != null) {
      final url = Uri.parse('egovph://everify?amount=$amt&recipient=${Uri.encodeComponent(_nameCtrl.text.trim())}&approvalId=${result.approvalId}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        setState(() => _error = 'Cannot launch eGovPH app');
      }
      return;
    }

    // Success
    setState(() {
      _success = '₱${amt.toStringAsFixed(2)} sent to ${_nameCtrl.text.trim()}';
      _nameCtrl.clear(); _accountCtrl.clear(); _amountCtrl.clear();
    });
  }

  // _showApprovalDialog removed.

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(bankingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Send Money', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFFEF4444), size: 12),
              const SizedBox(width: 4),
              Text('AI Protected', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1A30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF60A5FA), size: 16),
                  const SizedBox(width: 8),
                  Text('Available: ₱${bank.balance.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick contacts
            Text('Quick Send', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _contacts.map((c) => GestureDetector(
                  onTap: () { setState(() { _nameCtrl.text = c.$1; _accountCtrl.text = c.$2; }); },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          radius: 18,
                          child: Text(c.$1[0], style: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 6),
                        Text(c.$1.split(' ').first, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),

            Text('Transfer Details', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _FormField(controller: _nameCtrl, label: 'Recipient Name', hint: 'Full name', icon: Icons.person_rounded),
            const SizedBox(height: 12),
            _FormField(controller: _accountCtrl, label: 'Account Number', hint: 'e.g. PH-BDO-001234567', icon: Icons.account_balance_rounded),
            const SizedBox(height: 12),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1A30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Text('₱', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 24),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              _StatusMsg(message: _error!, isError: true),
            ],
            if (_success != null) ...[
              const SizedBox(height: 14),
              _StatusMsg(message: '✓ $_success', isError: false),
            ],

            const SizedBox(height: 24),

            // Info about the flow
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _FlowStep(icon: Icons.psychology_rounded, label: 'eGovAI runs fraud risk analysis', color: const Color(0xFFEF4444)),
                  _FlowStep(icon: Icons.notifications_active_rounded, label: 'eMessage approval if MEDIUM risk', color: const Color(0xFFF59E0B)),
                  _FlowStep(icon: Icons.link_rounded, label: 'eGovChain logs the transaction', color: const Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _loading ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: _loading
                      ? const LinearGradient(colors: [Color(0xFF374151), Color(0xFF4B5563)])
                      : const LinearGradient(colors: [Color(0xFF003087), Color(0xFF0050C8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _loading ? [] : const [BoxShadow(color: Color(0x440050C8), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Send Money', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  const _FormField({required this.controller, required this.label, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusMsg extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusMsg({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: GoogleFonts.inter(color: color, fontSize: 13)),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FlowStep({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }
}
