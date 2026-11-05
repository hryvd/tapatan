import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/banking_provider.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  int? _selected;
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  final _billers = [
    ('Meralco', 'Electric Bill', Icons.bolt_rounded, Color(0xFFF59E0B)),
    ('MAYNILAD', 'Water Bill', Icons.water_drop_rounded, Color(0xFF06B6D4)),
    ('PLDT', 'Internet / Phone', Icons.wifi_rounded, Color(0xFF3B82F6)),
    ('Globe', 'Mobile / Broadband', Icons.cell_tower_rounded, Color(0xFF10B981)),
    ('SSS', 'Social Security', Icons.security_rounded, Color(0xFF8B5CF6)),
    ('PhilHealth', 'Health Insurance', Icons.local_hospital_rounded, Color(0xFFEF4444)),
    ('Pag-IBIG', 'Housing Fund', Icons.home_rounded, Color(0xFF6366F1)),
    ('BIR', 'Tax Payment', Icons.receipt_rounded, Color(0xFFF97316)),
  ];

  Future<void> _pay() async {
    if (_selected == null) { setState(() => _error = 'Select a biller'); return; }
    final amt = double.tryParse(_amountCtrl.text);
    if (_accountCtrl.text.trim().isEmpty) { setState(() => _error = 'Enter account number'); return; }
    if (amt == null || amt <= 0) { setState(() => _error = 'Enter valid amount'); return; }

    setState(() { _loading = true; _error = null; _success = null; });

    final result = await ref.read(bankingProvider.notifier).payBill(
      billerName: _billers[_selected!].$1,
      accountNumber: _accountCtrl.text.trim(),
      amount: amt,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success && !result.needsApproval) {
      setState(() => _error = result.errorMessage ?? 'Payment failed');
      return;
    }

    if (result.needsApproval && result.approvalId != null) {
      _showApprovalSheet(
        approvalId: result.approvalId!,
        billerName: _billers[_selected!].$1,
        accountNumber: _accountCtrl.text.trim(),
        amount: amt,
        riskLevel: result.riskLevel,
      );
      return;
    }

    setState(() {
      _success = '₱${amt.toStringAsFixed(2)} paid to ${_billers[_selected!].$1}';
      _selected = null; _accountCtrl.clear(); _amountCtrl.clear();
    });
  }

  void _showApprovalSheet({
    required String approvalId,
    required String billerName,
    required String accountNumber,
    required double amount,
    required String riskLevel,
  }) {
    final bank = ref.read(bankingProvider);
    final approval = bank.approvals.firstWhere((a) => a.id == approvalId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1A30),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      isDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.notifications_active_rounded, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text('eMessage · Approval Required', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Text('Approve Bill Payment?', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
              child: Column(children: [
                _Row('Biller', billerName),
                _Row('Account', accountNumber),
                _Row('Amount', '₱${amount.toStringAsFixed(2)}'),
                _Row('Risk', riskLevel),
                _Row('Code', approval.approvalCode),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { ref.read(bankingProvider.notifier).rejectApproval(approvalId); Navigator.pop(ctx); setState(() => _error = 'Payment rejected'); },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3))),
                  child: Center(child: Text('Reject', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)))),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  // Execute the bill payment with eGovChain logging
                  final chainRes = await ref.read(bankingProvider.notifier).payBill(
                    billerName: billerName,
                    accountNumber: accountNumber,
                    amount: amount,
                  );
                  if (!mounted) return;
                  setState(() {
                    _loading = false;
                    if (chainRes.success) {
                      _success = '₱${amount.toStringAsFixed(2)} paid to $billerName';
                      _selected = null; _accountCtrl.clear(); _amountCtrl.clear();
                    }
                  });
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('Approve & Pay', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)))),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false,
        title: Text('Bills Payment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Biller', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _billers.length,
              itemBuilder: (_, i) {
                final b = _billers[i];
                final isSelected = _selected == i;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? b.$4.withValues(alpha: 0.15) : const Color(0xFF0D1A30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? b.$4 : Colors.white.withValues(alpha: 0.06), width: isSelected ? 1.5 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(b.$3, color: isSelected ? b.$4 : Colors.white.withValues(alpha: 0.4), size: 24),
                      const SizedBox(height: 5),
                      Text(b.$1, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500), textAlign: TextAlign.center),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            if (_selected != null) ...[
              Text('Payment Details', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _FormField(controller: _accountCtrl, label: 'Account / Reference Number', hint: 'e.g. 1234-5678-90', icon: Icons.tag_rounded),
              const SizedBox(height: 12),
              _AmountField(controller: _amountCtrl),
            ],

            if (_error != null) ...[const SizedBox(height: 14), _StatusMsg(_error!, isError: true)],
            if (_success != null) ...[const SizedBox(height: 14), _StatusMsg('✓ $_success', isError: false)],

            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loading ? null : _pay,
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
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Pay Bill', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String l; final String v;
  const _Row(this.l, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
      Text(v, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller; final String label, hint; final IconData icon;
  const _FormField({required this.controller, required this.label, required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    Container(decoration: BoxDecoration(color: const Color(0xFF0D1A30), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 18), const SizedBox(width: 10),
        Expanded(child: TextField(controller: controller, style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 14), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14))))])),
  ]);
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Amount', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    Container(decoration: BoxDecoration(color: const Color(0xFF0D1A30), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [Text('₱', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(width: 8),
        Expanded(child: TextField(controller: controller, keyboardType: TextInputType.number, style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          decoration: InputDecoration(border: InputBorder.none, hintText: '0.00', hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 24), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14))))])),
  ]);
}

class _StatusMsg extends StatelessWidget {
  final String message; final bool isError;
  const _StatusMsg(this.message, {required this.isError});
  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(message, style: GoogleFonts.inter(color: color, fontSize: 13)));
  }
}
