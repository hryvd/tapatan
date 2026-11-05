import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/banking_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(bankingProvider);
    final pending = bank.approvals.where((a) => a.status == ApprovalStatus.pending).toList();
    final history = bank.approvals.where((a) => a.status != ApprovalStatus.pending).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Approval Inbox', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          if (pending.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Text('${pending.length} PENDING', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: bank.approvals.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // eMessage banner
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('eMessage Approval Service', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('All high-risk transactions require your explicit approval here before processing.',
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (pending.isNotEmpty) ...[
                  Text('Pending Approvals', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...pending.map((a) => _PendingCard(approval: a, ref: ref)),
                  const SizedBox(height: 24),
                ],

                if (history.isNotEmpty) ...[
                  Text('History', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...history.map((a) => _HistoryCard(approval: a)),
                ],
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFFF59E0B), size: 36),
          ),
          const SizedBox(height: 16),
          Text('No Approvals', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('eMessage approvals will appear here\nwhen transactions require verification.',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final ApprovalRequest approval;
  final WidgetRef ref;
  const _PendingCard({required this.approval, required this.ref});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(approval.action, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(fmt.format(approval.createdAt), style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('PENDING', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              _DetailRow('Description', approval.description),
              _DetailRow('Amount', '₱${approval.amount.toStringAsFixed(2)}'),
              _DetailRow('Approval Code', approval.approvalCode),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => ref.read(bankingProvider.notifier).rejectApproval(approval.id),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25))),
                child: Center(child: Text('Reject', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)))),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: GestureDetector(
              onTap: () {
                ref.read(bankingProvider.notifier).rejectApproval(approval.id);
                // Mark as approved
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Approved: ${approval.action}', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Approve', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
            )),
          ]),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ApprovalRequest approval;
  const _HistoryCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    final approved = approval.status == ApprovalStatus.approved;
    final color = approved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final fmt = DateFormat('MMM d, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(approved ? Icons.check_rounded : Icons.close_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(approval.action, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${approval.description} · ${fmt.format(approval.createdAt)}',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(approved ? 'APPROVED' : 'REJECTED', style: GoogleFonts.inter(color: color, fontSize: 8, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String l; final String v;
  const _DetailRow(this.l, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      Text(v, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}
