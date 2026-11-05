import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

enum EverifyStep { notify, review, liveness, verifying, success }

class EverifyTransferScreen extends StatefulWidget {
  final double amount;
  final String recipientName;
  final String approvalId;

  const EverifyTransferScreen({
    super.key,
    required this.amount,
    required this.recipientName,
    required this.approvalId,
  });

  @override
  State<EverifyTransferScreen> createState() => _EverifyTransferScreenState();
}

class _EverifyTransferScreenState extends State<EverifyTransferScreen> {
  EverifyStep _step = EverifyStep.notify;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    // 1. Notify
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _step = EverifyStep.review);
  }

  Future<void> _runLiveness() async {
    setState(() => _step = EverifyStep.liveness);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    setState(() => _step = EverifyStep.verifying);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    setState(() => _step = EverifyStep.success);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    _returnToBank();
  }

  Future<void> _returnToBank() async {
    final url = Uri.parse('tapatan://transfer_success?approvalId=${widget.approvalId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildNotify() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 24),
        Text('Securing Transaction...',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Connecting to eGovPH Identity',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _buildReview() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, color: Color(0xFF10B981), size: 40),
                const SizedBox(height: 16),
                Text('Transaction Review',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _detailRow('Recipient', widget.recipientName),
                const SizedBox(height: 12),
                _detailRow('Amount', '₱${widget.amount.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                _detailRow('Approval ID', widget.approvalId.split('-').first),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _runLiveness,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Verify with Biometrics',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
        Text(val, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLiveness() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 4),
            ),
            child: const Center(
              child: Icon(Icons.face_retouching_natural, color: Colors.white54, size: 80),
            ),
          ),
          const SizedBox(height: 32),
          Text('Position your face in the circle',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Scanning...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVerifying() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Color(0xFF10B981)),
        const SizedBox(height: 24),
        Text('Verifying Identity...',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 80),
        const SizedBox(height: 24),
        Text('Identity Verified',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Returning to bank...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_step) {
      case EverifyStep.notify: content = _buildNotify(); break;
      case EverifyStep.review: content = _buildReview(); break;
      case EverifyStep.liveness: content = _buildLiveness(); break;
      case EverifyStep.verifying: content = _buildVerifying(); break;
      case EverifyStep.success: content = _buildSuccess(); break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111827), // eGov dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text('eGovPH · eVerify', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: content,
        ),
      ),
    );
  }
}
